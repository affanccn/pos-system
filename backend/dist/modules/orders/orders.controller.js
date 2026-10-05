import { prisma } from '../../config/prisma.js';
import { getIO, emitToWindowsKasa } from '../../realtime/socket.js';
import { createAuditLog } from '../../utils/auditLog.js';
// YARDIMCI FONKSİYON: Siparişteki ürünleri Bar / Mutfak / Nargile yazıcılarına göre bölüp Windows'a gönderir
async function dispatchSplitOrderToWindowsPrinters(params) {
    try {
        const { businessId, tableName, waiterName, orderNumber, orderNotes, printedItems } = params;
        const productIds = printedItems.map((i) => i.productId);
        const products = await prisma.product.findMany({
            where: { id: { in: productIds }, businessId },
            include: {
                category: {
                    include: { printer: true },
                },
            },
        });
        const activePrinters = await prisma.printer.findMany({
            where: { businessId, isActive: true },
        });
        const template = await prisma.receiptTemplate.upsert({
            where: { businessId },
            update: {},
            create: { businessId },
        });
        // Yazıcı ID'sine göre grupla (Bar, Mutfak, Nargile)
        const printerJobsMap = {};
        for (const item of printedItems) {
            const product = products.find((p) => p.id === item.productId);
            if (!product)
                continue;
            // 1. Öncelik: Kategorinin doğrudan bağlı olduğu yazıcı (printerId)
            let targetPrinter = product.category?.printer;
            // 2. Öncelik: Eğer kategoriye özel yazıcı seçilmemişse stationType (BAR, KITCHEN, SHISHA) eşleşmesine bak
            if (!targetPrinter || !targetPrinter.isActive) {
                const station = product.stationType || product.category?.stationType;
                targetPrinter = activePrinters.find((pr) => pr.stationType === station) || null;
            }
            if (targetPrinter && targetPrinter.isActive) {
                if (!printerJobsMap[targetPrinter.id]) {
                    printerJobsMap[targetPrinter.id] = {
                        printer: targetPrinter,
                        tableName,
                        waiterName,
                        orderNumber,
                        orderNotes,
                        createdAt: new Date().toISOString(),
                        items: [],
                    };
                }
                printerJobsMap[targetPrinter.id].items.push({
                    productName: item.productName,
                    quantity: item.quantity,
                    notes: item.notes,
                    modifiers: item.modifiers,
                });
            }
        }
        const jobs = Object.values(printerJobsMap);
        if (jobs.length > 0) {
            emitToWindowsKasa(businessId, 'print:split_order', {
                template,
                jobs,
            });
        }
    }
    catch (err) {
        console.error('Fiş parçalama ve yazdırma yönlendirme hatası:', err);
    }
}
// YARDIMCI FONKSİYON: Hesap (Adisyon) Fişini Bar/Kasa (isCashier = true) yazıcısına gönderir
async function dispatchCustomerBillToCashierPrinter(businessId, orderId, tableName) {
    try {
        const cashierPrinter = await prisma.printer.findFirst({
            where: { businessId, isActive: true, isCashier: true },
        });
        if (!cashierPrinter)
            return;
        const order = await prisma.order.findUnique({
            where: { id: orderId },
            include: {
                waiter: { select: { fullName: true } },
                items: {
                    where: { status: { notIn: ['VOID', 'CANCELLED'] } },
                    include: { modifiers: true },
                },
            },
        });
        if (!order)
            return;
        const template = await prisma.receiptTemplate.upsert({
            where: { businessId },
            update: {},
            create: { businessId },
        });
        emitToWindowsKasa(businessId, 'print:customer_bill', {
            printer: cashierPrinter,
            template,
            bill: {
                orderNumber: order.orderNumber,
                tableName,
                waiterName: order.waiter?.fullName || 'Kasa',
                totalAmountCents: order.totalAmountCents,
                discountAmountCents: order.discountAmountCents,
                paidAmountCents: order.paidAmountCents,
                payableAmountCents: Math.max(0, order.totalAmountCents - order.discountAmountCents - order.paidAmountCents),
                createdAt: new Date().toISOString(),
                items: order.items.map((i) => ({
                    name: i.productNameSnapshot,
                    quantity: i.quantity,
                    unitPriceCents: i.unitPriceCents,
                    totalPriceCents: i.totalPriceCents,
                    status: i.status,
                    modifiers: i.modifiers.map((m) => ({
                        name: m.modifierNameSnapshot,
                        quantity: m.quantity,
                        priceCents: m.priceCentsSnapshot,
                    })),
                })),
            },
        });
    }
    catch (err) {
        console.error('Hesap fişi yazdırma hatası:', err);
    }
}
export async function createOrder(req, res) {
    try {
        const businessId = req.user?.businessId;
        const waiterId = req.user?.userId || req.user?.id;
        const waiterName = req.user?.fullName || 'Garson';
        const { tableId, items, notes } = req.body;
        if (!businessId || !waiterId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
        if (!table) {
            res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
            return;
        }
        if (table.currentOrderId) {
            res.status(400).json({ success: false, error: 'Masada zaten açık bir sipariş var.' });
            return;
        }
        let totalAmount = 0;
        const itemsData = [];
        const printedItemsPayload = [];
        for (const item of items) {
            const product = await prisma.product.findUnique({ where: { id: item.productId } });
            if (product) {
                let itemTotal = product.priceCents * item.quantity;
                const modifiersData = [];
                const printedModifiers = [];
                if (item.modifiers && item.modifiers.length > 0) {
                    for (const mod of item.modifiers) {
                        const modItem = await prisma.productModifierItem.findUnique({ where: { id: mod.modifierItemId } });
                        if (modItem) {
                            const modPrice = modItem.priceCents * mod.quantity;
                            itemTotal += modPrice;
                            modifiersData.push({
                                modifierItemId: mod.modifierItemId,
                                modifierNameSnapshot: modItem.name,
                                priceCentsSnapshot: modItem.priceCents,
                                quantity: mod.quantity,
                                totalPriceCents: modPrice,
                            });
                            printedModifiers.push({ name: modItem.name, quantity: mod.quantity });
                        }
                    }
                }
                totalAmount += itemTotal;
                itemsData.push({
                    productId: product.id,
                    productNameSnapshot: product.name,
                    unitPriceCents: product.priceCents,
                    quantity: item.quantity,
                    totalPriceCents: itemTotal,
                    notes: item.notes,
                    modifiers: { create: modifiersData },
                });
                printedItemsPayload.push({
                    productId: product.id,
                    productName: product.name,
                    quantity: item.quantity,
                    notes: item.notes,
                    modifiers: printedModifiers,
                });
            }
        }
        const order = await prisma.order.create({
            data: {
                businessId,
                tableId,
                waiterId,
                orderNumber: Math.floor(Math.random() * 100000),
                status: 'CONFIRMED',
                totalAmountCents: totalAmount,
                notes,
                items: { create: itemsData },
            },
        });
        await prisma.restaurantTable.update({
            where: { id: tableId },
            data: { status: 'OCCUPIED', currentOrderId: order.id },
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId, status: 'OCCUPIED', orderId: order.id });
        io.to(`business:${businessId}:kitchen`).emit('kitchen:new_order', { orderId: order.id });
        // SİPARİŞİ BAR / MUTFAK / NARGİLE YAZICILARINA BÖL VE WINDOWS KASADAN YAZDIR!
        await dispatchSplitOrderToWindowsPrinters({
            businessId,
            tableName: table.name,
            waiterName,
            orderNumber: order.orderNumber,
            orderNotes: notes,
            printedItems: printedItemsPayload,
        });
        await createAuditLog({
            businessId,
            userId: waiterId,
            action: 'ORDER_CREATED',
            entity: 'Order',
            entityId: order.id,
            newValue: { totalAmountCents: totalAmount, tableId },
            description: 'Sipariş oluşturuldu',
        });
        res.json({ success: true, data: order });
    }
    catch (error) {
        console.error('CREATE ORDER ERROR:', error);
        res.status(500).json({ success: false, error: 'Sipariş oluşturulamadı.' });
    }
}
export async function addItemsToOrder(req, res) {
    try {
        const businessId = req.user?.businessId;
        const waiterName = req.user?.fullName || 'Garson';
        const { orderId } = req.params;
        const { items } = req.body;
        const order = await prisma.order.findFirst({
            where: { id: orderId, businessId },
            include: { table: true },
        });
        if (!order || !businessId) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        let addedAmount = 0;
        const printedItemsPayload = [];
        for (const item of items) {
            const product = await prisma.product.findUnique({ where: { id: item.productId } });
            if (product) {
                let itemTotal = product.priceCents * item.quantity;
                const modifiersData = [];
                const printedModifiers = [];
                if (item.modifiers && item.modifiers.length > 0) {
                    for (const mod of item.modifiers) {
                        const modItem = await prisma.productModifierItem.findUnique({ where: { id: mod.modifierItemId } });
                        if (modItem) {
                            const modPrice = modItem.priceCents * mod.quantity;
                            itemTotal += modPrice;
                            modifiersData.push({
                                modifierItemId: mod.modifierItemId,
                                modifierNameSnapshot: modItem.name,
                                priceCentsSnapshot: modItem.priceCents,
                                quantity: mod.quantity,
                                totalPriceCents: modPrice,
                            });
                            printedModifiers.push({ name: modItem.name, quantity: mod.quantity });
                        }
                    }
                }
                addedAmount += itemTotal;
                await prisma.orderItem.create({
                    data: {
                        orderId: order.id,
                        productId: product.id,
                        productNameSnapshot: product.name,
                        unitPriceCents: product.priceCents,
                        quantity: item.quantity,
                        totalPriceCents: itemTotal,
                        notes: item.notes,
                        modifiers: { create: modifiersData },
                    },
                });
                printedItemsPayload.push({
                    productId: product.id,
                    productName: product.name,
                    quantity: item.quantity,
                    notes: item.notes,
                    modifiers: printedModifiers,
                });
            }
        }
        await prisma.order.update({
            where: { id: orderId },
            data: { totalAmountCents: order.totalAmountCents + addedAmount },
        });
        const io = getIO();
        io.to(`business:${businessId}:kitchen`).emit('kitchen:new_order', { orderId: order.id });
        // EKLENEN YENİ ÜRÜNLERİ BAR / MUTFAK / NARGİLE YAZICILARINA BÖL VE YAZDIR!
        await dispatchSplitOrderToWindowsPrinters({
            businessId,
            tableName: order.table?.name || 'Masa',
            waiterName,
            orderNumber: order.orderNumber,
            orderNotes: 'EK SİPARİŞ',
            printedItems: printedItemsPayload,
        });
        res.json({ success: true, message: 'Ürünler eklendi' });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Ürün eklenemedi.' });
    }
}
export async function getActiveOrderByTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { tableId } = req.params;
        const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
        if (!table || !table.currentOrderId) {
            res.json({ success: true, data: null });
            return;
        }
        const order = await prisma.order.findUnique({
            where: { id: table.currentOrderId },
            include: {
                items: {
                    where: {
                        status: { notIn: ['VOID', 'CANCELLED'] },
                    },
                    include: {
                        modifiers: true,
                        product: { include: { category: true } },
                    },
                },
                payments: true,
            },
        });
        res.json({ success: true, data: order });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Sipariş getirilemedi.' });
    }
}
export async function requestTableBill(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { tableId } = req.params;
        const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
        if (!table || !table.currentOrderId || !businessId) {
            res.status(404).json({ success: false, error: 'Masa veya sipariş bulunamadı.' });
            return;
        }
        await prisma.restaurantTable.update({
            where: { id: tableId },
            data: { status: 'BILL_REQUESTED' },
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId, status: 'BILL_REQUESTED' });
        io.to(`business:${businessId}:waiters`).emit('notification', {
            type: 'BILL_READY',
            title: 'Hesap İsteği',
            body: `Masa hesabını istiyor: ${table.name}`,
        });
        // HESAP İSTENDİĞİNDE OTOMATİK OLARAK BAR/KASA YAZICISINDAN ADİSYON FİŞİ ÇIKART!
        await dispatchCustomerBillToCashierPrinter(businessId, table.currentOrderId, table.name);
        res.json({ success: true, message: 'Hesap istendi ve kasa yazıcısına gönderildi.' });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'İşlem başarısız.' });
    }
}
export async function closeOrderAndTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { tableId } = req.params;
        const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
        if (!table || !table.currentOrderId) {
            res.status(404).json({ success: false, error: 'Masa veya sipariş bulunamadı.' });
            return;
        }
        await prisma.order.update({
            where: { id: table.currentOrderId },
            data: { status: 'PAID' },
        });
        await prisma.restaurantTable.update({
            where: { id: tableId },
            data: { status: 'AVAILABLE', currentOrderId: null },
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId, status: 'AVAILABLE', orderId: null });
        await createAuditLog({
            businessId: businessId,
            userId: req.user?.userId || req.user?.id,
            action: 'ORDER_CANCEL',
            entity: 'Order',
            entityId: table.currentOrderId,
            description: 'Masa ve sipariş manuel olarak kapatıldı',
        });
        res.json({ success: true, message: 'Masa kapatıldı.' });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Kapatılamadı.' });
    }
}
export async function transferTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { fromTableId, toTableId } = req.body;
        const fromTable = await prisma.restaurantTable.findUnique({ where: { id: fromTableId } });
        const toTable = await prisma.restaurantTable.findUnique({ where: { id: toTableId } });
        if (!fromTable?.currentOrderId || toTable?.currentOrderId) {
            res.status(400).json({ success: false, error: 'Geçersiz masa transferi.' });
            return;
        }
        const orderId = fromTable.currentOrderId;
        await prisma.$transaction([
            prisma.order.update({ where: { id: orderId }, data: { tableId: toTableId } }),
            prisma.restaurantTable.update({ where: { id: fromTableId }, data: { status: 'AVAILABLE', currentOrderId: null } }),
            prisma.restaurantTable.update({ where: { id: toTableId }, data: { status: 'OCCUPIED', currentOrderId: orderId } }),
        ]);
        await createAuditLog({
            businessId: businessId,
            userId: req.user?.userId || req.user?.id,
            action: 'ORDER_UPDATE',
            entity: 'Table',
            entityId: orderId,
            oldValue: { tableId: fromTableId },
            newValue: { tableId: toTableId },
            description: `Masa ${fromTable.name}'den ${toTable.name}'e aktarıldı.`,
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: fromTableId, status: 'AVAILABLE', orderId: null });
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: toTableId, status: 'OCCUPIED', orderId });
        res.json({ success: true, message: 'Masa transfer edildi.' });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Transfer başarısız.' });
    }
}
export async function mergeTables(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { fromTableId, toTableId } = req.body;
        if (!businessId || !fromTableId || !toTableId || fromTableId === toTableId) {
            res.status(400).json({ success: false, error: 'Geçersiz masa bilgileri.' });
            return;
        }
        const fromTable = await prisma.restaurantTable.findUnique({ where: { id: fromTableId } });
        const toTable = await prisma.restaurantTable.findUnique({ where: { id: toTableId } });
        if (!fromTable?.currentOrderId || !toTable?.currentOrderId) {
            res.status(400).json({ success: false, error: 'Her iki masada da aktif sipariş olmalıdır.' });
            return;
        }
        const fromOrder = await prisma.order.findUnique({ where: { id: fromTable.currentOrderId } });
        const toOrder = await prisma.order.findUnique({ where: { id: toTable.currentOrderId } });
        if (!fromOrder || !toOrder) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        await prisma.$transaction(async (tx) => {
            await tx.orderItem.updateMany({
                where: { orderId: fromOrder.id },
                data: { orderId: toOrder.id },
            });
            await tx.payment.updateMany({
                where: { orderId: fromOrder.id },
                data: { orderId: toOrder.id },
            });
            await tx.order.update({
                where: { id: toOrder.id },
                data: {
                    totalAmountCents: toOrder.totalAmountCents + fromOrder.totalAmountCents,
                    paidAmountCents: toOrder.paidAmountCents + fromOrder.paidAmountCents,
                    discountAmountCents: toOrder.discountAmountCents + fromOrder.discountAmountCents,
                },
            });
            await tx.order.update({
                where: { id: fromOrder.id },
                data: {
                    status: 'CANCELLED',
                    totalAmountCents: 0,
                    paidAmountCents: 0,
                    notes: 'Başka masaya birleştirildi',
                },
            });
            await tx.restaurantTable.update({
                where: { id: fromTableId },
                data: { status: 'AVAILABLE', currentOrderId: null },
            });
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: fromTableId, status: 'AVAILABLE' });
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: toTableId, status: 'OCCUPIED' });
        res.json({ success: true, message: 'Masalar başarıyla birleştirildi.' });
    }
    catch (error) {
        console.error('Masa birleştirme hatası:', error);
        res.status(500).json({ success: false, error: 'Masa birleştirilemedi.' });
    }
}
export async function voidOrderItem(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { orderItemId } = req.params;
        const quantityToCancel = req.body.quantityToCancel || req.query.quantityToCancel;
        const item = await prisma.orderItem.findUnique({ where: { id: orderItemId }, include: { order: true, modifiers: true } });
        if (!item || item.order.businessId !== businessId) {
            res.status(404).json({ success: false, error: 'Kalem bulunamadı.' });
            return;
        }
        const cancelQty = quantityToCancel ? Math.min(Number(quantityToCancel), item.quantity) : item.quantity;
        if (cancelQty <= 0) {
            res.status(400).json({ success: false, error: 'Geçersiz miktar.' });
            return;
        }
        await prisma.$transaction(async (tx) => {
            const unitModifierPrice = item.quantity > 0 ? (item.totalPriceCents - item.unitPriceCents * item.quantity) / item.quantity : 0;
            const voidTotalPrice = (item.unitPriceCents + unitModifierPrice) * cancelQty;
            if (cancelQty === item.quantity) {
                await tx.orderItem.update({
                    where: { id: orderItemId },
                    data: { status: 'VOID' },
                });
            }
            else {
                const remainingQty = item.quantity - cancelQty;
                const remainingTotalPrice = (item.unitPriceCents + unitModifierPrice) * remainingQty;
                await tx.orderItem.update({
                    where: { id: orderItemId },
                    data: {
                        quantity: remainingQty,
                        totalPriceCents: remainingTotalPrice,
                    },
                });
                if (item.modifiers && item.modifiers.length > 0) {
                    for (const mod of item.modifiers) {
                        await tx.orderItemModifier.update({
                            where: { id: mod.id },
                            data: {
                                quantity: Math.max(1, Math.ceil((mod.quantity / item.quantity) * remainingQty)),
                                totalPriceCents: Math.ceil((mod.totalPriceCents / item.quantity) * remainingQty),
                            },
                        });
                    }
                }
            }
            await tx.order.update({
                where: { id: item.orderId },
                data: { totalAmountCents: Math.max(0, item.order.totalAmountCents - voidTotalPrice) },
            });
            const remainingItemsCount = await tx.orderItem.count({
                where: { orderId: item.orderId, status: { notIn: ['VOID', 'CANCELLED'] } },
            });
            if (remainingItemsCount === 0) {
                await tx.order.update({
                    where: { id: item.orderId },
                    data: { status: 'CANCELLED' },
                });
                if (item.order.tableId) {
                    await tx.restaurantTable.update({
                        where: { id: item.order.tableId },
                        data: { status: 'AVAILABLE', currentOrderId: null },
                    });
                }
            }
        });
        await createAuditLog({
            businessId: businessId,
            userId: req.user?.userId || req.user?.id,
            action: 'ITEM_VOID',
            entity: 'OrderItem',
            entityId: orderItemId,
            oldValue: { status: item.status, quantity: item.quantity },
            newValue: cancelQty === item.quantity
                ? { status: 'VOID', quantity: 0 }
                : { status: item.status, quantity: item.quantity - cancelQty },
            description: `Sipariş kalemi iptal edildi (${cancelQty} adet)`,
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { reload: true });
        res.json({ success: true, message: `${cancelQty} adet ürün iptal edildi.` });
    }
    catch (error) {
        console.error('İptal hatası:', error);
        res.status(500).json({ success: false, error: 'İptal edilemedi.' });
    }
}
export async function makePayment(req, res) {
    res.status(400).json({ success: false, error: 'Lütfen processOrderPayment metodunu kullanın.' });
}
export async function getKitchenOrders(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const orders = await prisma.order.findMany({
            where: {
                businessId,
                status: { in: ['CONFIRMED', 'PREPARING'] },
                items: {
                    some: {
                        status: { in: ['PENDING', 'PREPARING'] },
                    },
                },
            },
            include: {
                table: { select: { id: true, name: true } },
                waiter: { select: { id: true, fullName: true } },
                items: {
                    where: {
                        status: { in: ['PENDING', 'PREPARING', 'READY'] },
                    },
                    include: {
                        modifiers: true,
                        product: {
                            select: {
                                id: true,
                                categoryId: true,
                                category: { select: { id: true, name: true, stationType: true } },
                            },
                        },
                    },
                    orderBy: { createdAt: 'asc' },
                },
            },
            orderBy: { createdAt: 'asc' },
        });
        res.json({ success: true, data: orders });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Mutfak siparişleri getirilemedi.' });
    }
}
export async function updateOrderItemStatus(req, res) {
    try {
        const { orderItemId } = req.params;
        const { status } = req.body;
        const item = await prisma.orderItem.update({
            where: { id: orderItemId },
            data: { status },
            include: { product: true, order: { include: { table: true } } },
        });
        if (status === 'READY') {
            const io = getIO();
            const businessId = req.user?.businessId;
            if (businessId) {
                io.to(`business:${businessId}:waiters`).emit('notification', {
                    type: 'PRODUCT_READY',
                    title: 'Ürün Hazır',
                    body: `${item.order?.table?.name ?? 'Bilinmeyen Masa'} - ${item.productNameSnapshot} hazır!`,
                });
            }
        }
        res.json({ success: true, data: item });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Durum güncellenemedi.' });
    }
}
export async function readyAllOrderItems(req, res) {
    try {
        const { orderId } = req.params;
        const items = await prisma.orderItem.findMany({
            where: { orderId, status: { in: ['PENDING', 'PREPARING'] } },
            include: { order: { include: { table: true } } },
        });
        if (items.length > 0) {
            await prisma.orderItem.updateMany({
                where: { orderId, status: { in: ['PENDING', 'PREPARING'] } },
                data: { status: 'READY' },
            });
            const businessId = req.user?.businessId;
            if (businessId) {
                const io = getIO();
                io.to(`business:${businessId}:waiters`).emit('notification', {
                    type: 'ORDER_READY',
                    title: 'Tüm Sipariş Hazır',
                    body: `${items[0].order?.table?.name ?? 'Bilinmeyen Masa'} için siparişler hazırlandı.`,
                });
            }
        }
        res.json({ success: true, message: 'Tümü hazır.' });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Güncellenemedi.' });
    }
}
export async function processOrderPayment(req, res) {
    try {
        const businessId = req.user?.businessId;
        const cashierId = req.user?.userId || req.user?.id;
        const { orderId } = req.params;
        const { amountCents, method, cashAmountCents = 0, cardAmountCents = 0, paidItems = [], printReceipt = true, } = req.body;
        if (!businessId || !cashierId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!amountCents || amountCents <= 0) {
            res.status(400).json({ success: false, error: 'Geçersiz ödeme tutarı.' });
            return;
        }
        const order = await prisma.order.findUnique({
            where: { id: orderId },
            include: { payments: true, items: true, table: true },
        });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        const remainingCents = order.totalAmountCents - order.paidAmountCents - order.discountAmountCents;
        if (amountCents > remainingCents && method !== 'ACCOUNT') {
            res.status(400).json({
                success: false,
                error: `Girilen tutar kalan bakiyeden (${(remainingCents / 100).toFixed(2)} ₺) fazla olamaz.`,
            });
            return;
        }
        let isFullyPaid = false;
        await prisma.$transaction(async (tx) => {
            await tx.payment.create({
                data: {
                    businessId,
                    orderId,
                    cashierId,
                    method: method,
                    amountCents,
                    cashAmountCents: method === 'CASH' ? amountCents : method === 'MIXED' ? cashAmountCents : 0,
                    cardAmountCents: method === 'CARD' ? amountCents : method === 'MIXED' ? cardAmountCents : 0,
                },
            });
            const totalPaidAfterThis = order.paidAmountCents + amountCents;
            const totalDiscount = order.discountAmountCents;
            if (totalPaidAfterThis + totalDiscount >= order.totalAmountCents) {
                isFullyPaid = true;
                await tx.order.update({
                    where: { id: orderId },
                    data: {
                        paidAmountCents: totalPaidAfterThis,
                        status: 'PAID',
                    },
                });
                if (order.tableId) {
                    await tx.restaurantTable.update({
                        where: { id: order.tableId },
                        data: { status: 'AVAILABLE', currentOrderId: null },
                    });
                }
            }
            else {
                await tx.order.update({
                    where: { id: orderId },
                    data: { paidAmountCents: totalPaidAfterThis },
                });
            }
            if (paidItems && paidItems.length > 0) {
                for (const pItem of paidItems) {
                    const oi = order.items.find((i) => i.id === pItem.orderItemId);
                    if (oi) {
                        const newQty = oi.paidQuantity + pItem.quantity;
                        await tx.orderItem.update({
                            where: { id: oi.id },
                            data: { paidQuantity: newQty > oi.quantity ? oi.quantity : newQty },
                        });
                    }
                }
            }
        });
        // Ödeme alındığında eğer isteniyorsa Bar/Kasa yazıcısından Hesap Fişi çıkart
        if (printReceipt && isFullyPaid) {
            await dispatchCustomerBillToCashierPrinter(businessId, orderId, order.table?.name || 'Masa');
        }
        await createAuditLog({
            businessId: businessId,
            userId: cashierId,
            action: 'PAYMENT_CREATE',
            entity: 'Order',
            entityId: orderId,
            newValue: { amountCents, method, isFullyPaid },
            description: `Siparişe ${(amountCents / 100).toFixed(2)} TL ödeme alındı (${method})`,
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('order:payment_updated', {
            orderId,
            isFullyPaid,
            paidAmountCents: order.paidAmountCents + amountCents,
        });
        res.json({
            success: true,
            data: { isFullyPaid, orderId },
        });
    }
    catch (error) {
        console.error('Ödeme alınırken hata:', error);
        res.status(500).json({ success: false, error: 'Ödeme alınamadı.' });
    }
}
export async function applyOrderDiscount(req, res) {
    try {
        const { orderId } = req.params;
        const { discountAmountCents } = req.body;
        const order = await prisma.order.findUnique({ where: { id: orderId } });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        await prisma.order.update({
            where: { id: orderId },
            data: { discountAmountCents },
        });
        await createAuditLog({
            businessId: order.businessId,
            userId: req.user?.userId || req.user?.id,
            action: 'ITEM_DISCOUNT',
            entity: 'Order',
            entityId: orderId,
            oldValue: { discountAmountCents: order.discountAmountCents },
            newValue: { discountAmountCents },
            description: `Siparişe ${discountAmountCents / 100} TL indirim uygulandı`,
        });
        res.json({ success: true, message: 'İndirim uygulandı.' });
    }
    catch (error) {
        console.error('İndirim hatası:', error);
        res.status(500).json({ success: false, error: 'İndirim uygulanamadı.' });
    }
}
export async function makeItemComplimentary(req, res) {
    try {
        const { orderItemId } = req.params;
        const item = await prisma.orderItem.findUnique({ where: { id: orderItemId }, include: { order: true } });
        if (!item) {
            res.status(404).json({ success: false, error: 'Sipariş kalemi bulunamadı.' });
            return;
        }
        await prisma.$transaction(async (tx) => {
            await tx.orderItem.update({
                where: { id: orderItemId },
                data: { status: 'COMPLIMENTARY' },
            });
            await tx.order.update({
                where: { id: item.orderId },
                data: { totalAmountCents: item.order.totalAmountCents - item.totalPriceCents },
            });
        });
        await createAuditLog({
            businessId: item.order.businessId,
            userId: req.user?.userId || req.user?.id,
            action: 'ITEM_COMPLIMENTARY',
            entity: 'OrderItem',
            entityId: orderItemId,
            oldValue: { status: item.status },
            newValue: { status: 'COMPLIMENTARY' },
            description: 'Ürün ikram edildi',
        });
        res.json({ success: true, message: 'Ürün ikram edildi.' });
    }
    catch (error) {
        console.error('İkram hatası:', error);
        res.status(500).json({ success: false, error: 'İkram uygulanamadı.' });
    }
}
export async function transferOrderItems(req, res) {
    try {
        const businessId = req.user?.businessId;
        const waiterId = req.user?.userId || req.user?.id;
        const { fromTableId, toTableId, items } = req.body;
        if (!businessId || !fromTableId || !toTableId || !items || items.length === 0) {
            res.status(400).json({ success: false, error: 'Eksik bilgi.' });
            return;
        }
        const fromTable = await prisma.restaurantTable.findUnique({ where: { id: fromTableId } });
        const toTable = await prisma.restaurantTable.findUnique({ where: { id: toTableId } });
        if (!fromTable?.currentOrderId) {
            res.status(400).json({ success: false, error: 'Kaynak masada sipariş yok.' });
            return;
        }
        if (fromTableId === toTableId) {
            res.status(400).json({ success: false, error: 'Aynı masaya transfer yapılamaz.' });
            return;
        }
        const fromOrder = await prisma.order.findUnique({
            where: { id: fromTable.currentOrderId },
            include: { items: { include: { modifiers: true } } },
        });
        if (!fromOrder) {
            res.status(404).json({ success: false, error: 'Kaynak sipariş bulunamadı.' });
            return;
        }
        let toOrderId = toTable?.currentOrderId;
        await prisma.$transaction(async (tx) => {
            let toOrderAmountCents = 0;
            if (!toOrderId) {
                const toOrder = await tx.order.create({
                    data: {
                        businessId,
                        tableId: toTableId,
                        waiterId,
                        orderNumber: Math.floor(Math.random() * 100000),
                        status: 'CONFIRMED',
                        totalAmountCents: 0,
                    },
                });
                toOrderId = toOrder.id;
                await tx.restaurantTable.update({
                    where: { id: toTableId },
                    data: { status: 'OCCUPIED', currentOrderId: toOrderId },
                });
            }
            else {
                const toOrder = await tx.order.findUnique({ where: { id: toOrderId } });
                if (toOrder)
                    toOrderAmountCents = toOrder.totalAmountCents;
            }
            let totalTransferredAmount = 0;
            for (const reqItem of items) {
                const originalItem = fromOrder.items.find((i) => i.id === reqItem.orderItemId);
                if (!originalItem)
                    continue;
                if (reqItem.quantity <= 0)
                    continue;
                const transferQty = Math.min(reqItem.quantity, originalItem.quantity);
                const unitModifierPrice = originalItem.quantity > 0
                    ? (originalItem.totalPriceCents - originalItem.unitPriceCents * originalItem.quantity) /
                        originalItem.quantity
                    : 0;
                const transferredTotalPrice = (originalItem.unitPriceCents + unitModifierPrice) * transferQty;
                totalTransferredAmount += transferredTotalPrice;
                if (transferQty === originalItem.quantity) {
                    await tx.orderItem.update({
                        where: { id: originalItem.id },
                        data: { orderId: toOrderId },
                    });
                }
                else {
                    const remainingQty = originalItem.quantity - transferQty;
                    const remainingTotalPrice = (originalItem.unitPriceCents + unitModifierPrice) * remainingQty;
                    await tx.orderItem.update({
                        where: { id: originalItem.id },
                        data: {
                            quantity: remainingQty,
                            totalPriceCents: remainingTotalPrice,
                        },
                    });
                    const newItemData = {
                        orderId: toOrderId,
                        productId: originalItem.productId,
                        productNameSnapshot: originalItem.productNameSnapshot,
                        unitPriceCents: originalItem.unitPriceCents,
                        quantity: transferQty,
                        totalPriceCents: transferredTotalPrice,
                        notes: originalItem.notes,
                        status: originalItem.status,
                        paidQuantity: 0,
                    };
                    const newItem = await tx.orderItem.create({ data: newItemData });
                    if (originalItem.modifiers && originalItem.modifiers.length > 0) {
                        const modsToCreate = originalItem.modifiers.map((mod) => ({
                            orderItemId: newItem.id,
                            modifierItemId: mod.modifierItemId,
                            modifierNameSnapshot: mod.modifierNameSnapshot,
                            priceCentsSnapshot: mod.priceCentsSnapshot,
                            quantity: Math.ceil((mod.quantity / originalItem.quantity) * transferQty),
                            totalPriceCents: Math.ceil((mod.totalPriceCents / originalItem.quantity) * transferQty),
                        }));
                        await tx.orderItemModifier.createMany({ data: modsToCreate });
                    }
                }
            }
            await tx.order.update({
                where: { id: fromOrder.id },
                data: { totalAmountCents: fromOrder.totalAmountCents - totalTransferredAmount },
            });
            await tx.order.update({
                where: { id: toOrderId },
                data: { totalAmountCents: toOrderAmountCents + totalTransferredAmount },
            });
            const remainingItems = await tx.orderItem.count({
                where: { orderId: fromOrder.id, status: { notIn: ['VOID', 'CANCELLED'] } },
            });
            if (remainingItems === 0) {
                await tx.restaurantTable.update({
                    where: { id: fromTableId },
                    data: { status: 'AVAILABLE', currentOrderId: null },
                });
                await tx.order.update({
                    where: { id: fromOrder.id },
                    data: { status: 'CANCELLED' },
                });
            }
        });
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: fromTableId });
        io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: toTableId });
        res.json({ success: true, message: 'Ürünler başarıyla transfer edildi.' });
    }
    catch (error) {
        console.error('TRANSFER ITEMS ERROR:', error);
        res.status(500).json({ success: false, error: 'Ürün transferi başarısız.' });
    }
}
