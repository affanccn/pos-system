import { PrismaClient, TableStatus } from '@prisma/client';
import { getIO } from '../../realtime/socket.js';
import { OrderItemStatus } from '@prisma/client';
const prisma = new PrismaClient();
// 1. Yeni Sipariş Oluşturma
export async function createOrder(req, res) {
    try {
        const businessId = req.user?.businessId;
        const waiterId = req.user?.userId || req.user?.id;
        const { tableId, items, notes } = req.body;
        if (!businessId || !waiterId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!tableId || !items || !Array.isArray(items) || items.length === 0) {
            res.status(400).json({ success: false, error: 'Masa ve en az bir ürün seçilmelidir.' });
            return;
        }
        const table = await prisma.restaurantTable.findFirst({
            where: { id: tableId, businessId },
        });
        if (!table) {
            res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
            return;
        }
        const productIds = items.map((i) => i.productId);
        const products = await prisma.product.findMany({
            where: { id: { in: productIds }, businessId, isActive: true },
        });
        if (products.length !== productIds.length) {
            res.status(400).json({ success: false, error: 'Seçilen ürünlerden bazıları geçersiz veya pasif.' });
            return;
        }
        const productMap = new Map(products.map((p) => [p.id, p]));
        let totalAmountCents = 0;
        const orderItemsData = items.map((item) => {
            const product = productMap.get(item.productId);
            const itemTotal = product.priceCents * item.quantity;
            totalAmountCents += itemTotal;
            return {
                productId: product.id,
                productNameSnapshot: product.name,
                unitPriceCents: product.priceCents,
                quantity: item.quantity,
                totalPriceCents: itemTotal,
                notes: item.notes || null,
            };
        });
        const lastOrder = await prisma.order.findFirst({
            where: { businessId },
            orderBy: { orderNumber: 'desc' },
            select: { orderNumber: true },
        });
        const orderNumber = (lastOrder?.orderNumber ?? 1000) + 1;
        const result = await prisma.$transaction(async (tx) => {
            const order = await tx.order.create({
                data: {
                    businessId,
                    tableId,
                    waiterId,
                    orderNumber,
                    totalAmountCents,
                    notes,
                    items: {
                        create: orderItemsData,
                    },
                },
                include: {
                    items: true,
                    table: true,
                    waiter: { select: { id: true, fullName: true } },
                },
            });
            await tx.restaurantTable.update({
                where: { id: tableId },
                data: {
                    status: TableStatus.OCCUPIED,
                    currentOrderId: order.id,
                },
            });
            return order;
        });
        try {
            const io = getIO();
            const kitchenRoom = `business:${businessId}:kitchen`;
            const waitersRoom = `business:${businessId}:waiters`;
            io.to(kitchenRoom).emit('order:created', {
                orderId: result.id,
                orderNumber: result.orderNumber,
                tableName: result.table.name,
                items: result.items,
                notes: result.notes,
                createdAt: result.createdAt,
            });
            io.to(waitersRoom).emit('table:updated', {
                tableId: result.tableId,
                tableStatus: TableStatus.OCCUPIED,
                orderId: result.id,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.status(201).json({
            success: true,
            message: 'Sipariş başarıyla oluşturuldu.',
            data: result,
        });
    }
    catch (error) {
        console.error('Sipariş oluşturma hatası:', error);
        res.status(500).json({ success: false, error: 'Sipariş oluşturulamadı.' });
    }
}
// 2. Masadaki Aktif Siparişi Getirme
export async function getActiveOrderByTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { tableId } = req.params;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const table = await prisma.restaurantTable.findFirst({
            where: { id: tableId, businessId },
        });
        if (!table) {
            res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
            return;
        }
        if (!table.currentOrderId) {
            res.status(404).json({ success: false, error: 'Bu masada açık bir sipariş bulunmuyor.' });
            return;
        }
        const order = await prisma.order.findFirst({
            where: {
                id: table.currentOrderId,
                businessId,
            },
            include: {
                items: true,
                payments: true,
                waiter: {
                    select: { id: true, fullName: true },
                },
            },
        });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        res.json({
            success: true,
            data: order,
        });
    }
    catch (error) {
        console.error('Aktif sipariş getirme hatası:', error);
        res.status(500).json({ success: false, error: 'Sipariş bilgisi alınamadı.' });
    }
}
// 3. Mevcut Adisyona Ek Ürün Ekleme
export async function addItemsToOrder(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { orderId } = req.params;
        const { items } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!items || !Array.isArray(items) || items.length === 0) {
            res.status(400).json({ success: false, error: 'Eklenecek ürün bulunamadı.' });
            return;
        }
        const order = await prisma.order.findFirst({
            where: { id: orderId, businessId },
            include: { table: true },
        });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        const productIds = items.map((i) => i.productId);
        const products = await prisma.product.findMany({
            where: { id: { in: productIds }, businessId, isActive: true },
        });
        if (products.length !== productIds.length) {
            res.status(400).json({ success: false, error: 'Seçilen ürünlerden bazıları geçersiz.' });
            return;
        }
        const productMap = new Map(products.map((p) => [p.id, p]));
        let addedAmountCents = 0;
        const newItemsData = items.map((item) => {
            const product = productMap.get(item.productId);
            const itemTotal = product.priceCents * item.quantity;
            addedAmountCents += itemTotal;
            return {
                orderId,
                productId: product.id,
                productNameSnapshot: product.name,
                unitPriceCents: product.priceCents,
                quantity: item.quantity,
                totalPriceCents: itemTotal,
                notes: item.notes || null,
            };
        });
        const updatedOrder = await prisma.$transaction(async (tx) => {
            await tx.orderItem.createMany({
                data: newItemsData,
            });
            return tx.order.update({
                where: { id: orderId },
                data: {
                    totalAmountCents: { increment: addedAmountCents },
                },
                include: {
                    items: true,
                    table: true,
                    waiter: { select: { id: true, fullName: true } },
                },
            });
        });
        try {
            const io = getIO();
            const kitchenRoom = `business:${businessId}:kitchen`;
            const waitersRoom = `business:${businessId}:waiters`;
            io.to(kitchenRoom).emit('order:items_added', {
                orderId: order.id,
                orderNumber: order.orderNumber,
                tableName: order.table.name,
                newItems: newItemsData,
            });
            io.to(waitersRoom).emit('table:updated', {
                tableId: order.tableId,
                orderId: order.id,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({
            success: true,
            message: 'Ürünler adisyona başarıyla eklendi.',
            data: updatedOrder,
        });
    }
    catch (error) {
        console.error('Ek ürün eklenirken hata:', error);
        res.status(500).json({ success: false, error: 'Ürünler eklenemedi.' });
    }
}
// 4. Masanın Hesabını İste (Garson -> BILL_REQUESTED)
export async function requestTableBill(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { tableId } = req.params;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const table = await prisma.restaurantTable.findFirst({
            where: { id: tableId, businessId },
        });
        if (!table) {
            res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
            return;
        }
        const updatedTable = await prisma.restaurantTable.update({
            where: { id: tableId },
            data: { status: TableStatus.BILL_REQUESTED },
        });
        try {
            const io = getIO();
            io.to(`business:${businessId}:waiters`).emit('table:updated', {
                tableId: updatedTable.id,
                tableStatus: updatedTable.status,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({
            success: true,
            message: 'Hesap isteme talebi iletildi.',
            data: updatedTable,
        });
    }
    catch (error) {
        console.error('Hesap istenirken hata:', error);
        res.status(500).json({ success: false, error: 'Hesap isteği işlenemedi.' });
    }
}
// 5. Hesabı Kapat / Masayı Boşalt
export async function closeOrderAndTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { tableId } = req.params;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const table = await prisma.restaurantTable.findFirst({
            where: { id: tableId, businessId },
        });
        if (!table || !table.currentOrderId) {
            res.status(400).json({ success: false, error: 'Masada kapatılacak aktif bir sipariş yok.' });
            return;
        }
        await prisma.$transaction(async (tx) => {
            await tx.order.update({
                where: { id: table.currentOrderId },
                data: { status: 'PAID' },
            });
            await tx.restaurantTable.update({
                where: { id: tableId },
                data: {
                    status: TableStatus.AVAILABLE,
                    currentOrderId: null,
                },
            });
        });
        try {
            const io = getIO();
            io.to(`business:${businessId}:waiters`).emit('table:updated', {
                tableId: table.id,
                tableStatus: TableStatus.AVAILABLE,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({
            success: true,
            message: 'Hesap başarıyla kapatıldı, masa boşa çıkarıldı.',
        });
    }
    catch (error) {
        console.error('Hesap kapatılırken hata:', error);
        res.status(500).json({ success: false, error: 'Hesap kapatılamadı.' });
    }
}
// 6. Masa Taşıma / Aktarma
export async function transferTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { sourceTableId, targetTableId } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!sourceTableId || !targetTableId || sourceTableId === targetTableId) {
            res.status(400).json({ success: false, error: 'Geçersiz kaynak veya hedef masa seçimi.' });
            return;
        }
        const [sourceTable, targetTable] = await Promise.all([
            prisma.restaurantTable.findFirst({ where: { id: sourceTableId, businessId } }),
            prisma.restaurantTable.findFirst({ where: { id: targetTableId, businessId } }),
        ]);
        if (!sourceTable || !targetTable) {
            res.status(404).json({ success: false, error: 'Masalardan biri veya ikisi bulunamadı.' });
            return;
        }
        if (!sourceTable.currentOrderId) {
            res.status(400).json({ success: false, error: 'Kaynak masada taşınacak açık bir sipariş yok.' });
            return;
        }
        if (targetTable.status !== TableStatus.AVAILABLE) {
            res.status(400).json({ success: false, error: 'Hedef masa boş değil! Lütfen boş bir masa seçin.' });
            return;
        }
        const orderId = sourceTable.currentOrderId;
        await prisma.$transaction(async (tx) => {
            await tx.order.update({
                where: { id: orderId },
                data: { tableId: targetTableId },
            });
            await tx.restaurantTable.update({
                where: { id: sourceTableId },
                data: {
                    status: TableStatus.AVAILABLE,
                    currentOrderId: null,
                },
            });
            await tx.restaurantTable.update({
                where: { id: targetTableId },
                data: {
                    status: TableStatus.OCCUPIED,
                    currentOrderId: orderId,
                },
            });
        });
        try {
            const io = getIO();
            const waitersRoom = `business:${businessId}:waiters`;
            io.to(waitersRoom).emit('table:updated', {
                tableId: sourceTableId,
                tableStatus: TableStatus.AVAILABLE,
            });
            io.to(waitersRoom).emit('table:updated', {
                tableId: targetTableId,
                tableStatus: TableStatus.OCCUPIED,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({
            success: true,
            message: `${sourceTable.name} masası başarıyla ${targetTable.name} masasına taşındı.`,
        });
    }
    catch (error) {
        console.error('Masa taşınırken hata:', error);
        res.status(500).json({ success: false, error: 'Masa taşıma işlemi başarısız oldu.' });
    }
}
// Masa Birleştir (Source masa siparişini Target masaya aktar/birleştir)
export async function mergeTables(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { sourceTableId, targetTableId } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!sourceTableId || !targetTableId || sourceTableId === targetTableId) {
            res.status(400).json({ success: false, error: 'Geçersiz kaynak veya hedef masa seçimi.' });
            return;
        }
        const [sourceTable, targetTable] = await Promise.all([
            prisma.restaurantTable.findFirst({ where: { id: sourceTableId, businessId } }),
            prisma.restaurantTable.findFirst({ where: { id: targetTableId, businessId } }),
        ]);
        if (!sourceTable || !targetTable) {
            res.status(404).json({ success: false, error: 'Masalardan biri veya ikisi bulunamadı.' });
            return;
        }
        if (!sourceTable.currentOrderId) {
            res.status(400).json({ success: false, error: 'Kaynak masada birleştirilecek açık bir sipariş yok.' });
            return;
        }
        const sourceOrderId = sourceTable.currentOrderId;
        const targetOrderId = targetTable.currentOrderId;
        await prisma.$transaction(async (tx) => {
            if (targetOrderId) {
                // Hedef masada da açık sipariş var: Kalemleri hedef siparişe taşı
                await tx.orderItem.updateMany({
                    where: { orderId: sourceOrderId },
                    data: { orderId: targetOrderId },
                });
                // Hedef sipariş toplam tutarını yeniden hesapla
                const allItems = await tx.orderItem.findMany({
                    where: { orderId: targetOrderId, status: { not: 'CANCELLED' } },
                });
                const newTotal = allItems.reduce((acc, item) => acc + (item.totalPriceCents || 0), 0);
                await tx.order.update({
                    where: { id: targetOrderId },
                    data: { totalAmountCents: newTotal },
                });
                // Kaynak siparişi iptal/birleştirildi olarak işaretle
                await tx.order.update({
                    where: { id: sourceOrderId },
                    data: {
                        status: 'CANCELLED',
                        notes: `Masa birleştirildi -> Hedef Masa: ${targetTable.name}`,
                    },
                });
                // Kaynak masayı boşa çıkar
                await tx.restaurantTable.update({
                    where: { id: sourceTableId },
                    data: {
                        status: TableStatus.AVAILABLE,
                        currentOrderId: null,
                    },
                });
            }
            else {
                // Hedef masa boş: Kaynak siparişi hedef masaya bağla
                await tx.order.update({
                    where: { id: sourceOrderId },
                    data: { tableId: targetTableId },
                });
                await tx.restaurantTable.update({
                    where: { id: sourceTableId },
                    data: {
                        status: TableStatus.AVAILABLE,
                        currentOrderId: null,
                    },
                });
                await tx.restaurantTable.update({
                    where: { id: targetTableId },
                    data: {
                        status: TableStatus.OCCUPIED,
                        currentOrderId: sourceOrderId,
                    },
                });
            }
        });
        try {
            const io = getIO();
            const waitersRoom = `business:${businessId}:waiters`;
            io.to(waitersRoom).emit('table:updated', {
                tableId: sourceTableId,
                tableStatus: TableStatus.AVAILABLE,
            });
            io.to(waitersRoom).emit('table:updated', {
                tableId: targetTableId,
                tableStatus: TableStatus.OCCUPIED,
            });
            if (targetOrderId) {
                io.to(waitersRoom).emit('order:updated', {
                    orderId: targetOrderId,
                    tableId: targetTableId,
                });
            }
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({
            success: true,
            message: `${sourceTable.name} masasındaki sipariş ${targetTable.name} ile başarıyla birleştirildi.`,
        });
    }
    catch (error) {
        console.error('Masa birleştirilirken hata:', error);
        res.status(500).json({ success: false, error: 'Masa birleştirme işlemi başarısız oldu.' });
    }
}
// 7. Adisyondan Kalem Sil veya Adet Düşür (Void Item)
export async function voidOrderItem(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { orderItemId } = req.params;
        const { quantityToCancel } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const item = await prisma.orderItem.findUnique({
            where: { id: orderItemId },
            include: {
                order: {
                    include: { items: true, table: true },
                },
            },
        });
        if (!item || item.order.businessId !== businessId) {
            res.status(404).json({ success: false, error: 'Sipariş kalemi bulunamadı.' });
            return;
        }
        const cancelQty = quantityToCancel && quantityToCancel > 0 ? quantityToCancel : 1;
        const unitPrice = item.unitPriceCents;
        const orderId = item.orderId;
        const tableId = item.order.tableId;
        await prisma.$transaction(async (tx) => {
            if (item.quantity <= cancelQty) {
                await tx.orderItem.delete({
                    where: { id: orderItemId },
                });
                const deductAmount = item.unitPriceCents * item.quantity;
                await tx.order.update({
                    where: { id: orderId },
                    data: {
                        totalAmountCents: { decrement: deductAmount },
                    },
                });
            }
            else {
                const deductAmount = unitPrice * cancelQty;
                await tx.orderItem.update({
                    where: { id: orderItemId },
                    data: {
                        quantity: { decrement: cancelQty },
                        totalPriceCents: { decrement: deductAmount },
                    },
                });
                await tx.order.update({
                    where: { id: orderId },
                    data: {
                        totalAmountCents: { decrement: deductAmount },
                    },
                });
            }
            const remainingItems = await tx.orderItem.count({
                where: { orderId },
            });
            if (remainingItems === 0) {
                await tx.order.update({
                    where: { id: orderId },
                    data: { status: 'CANCELLED' },
                });
                await tx.restaurantTable.update({
                    where: { id: tableId },
                    data: {
                        status: TableStatus.AVAILABLE,
                        currentOrderId: null,
                    },
                });
            }
        });
        try {
            const io = getIO();
            const waitersRoom = `business:${businessId}:waiters`;
            io.to(waitersRoom).emit('table:updated', {
                tableId,
                orderId,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({
            success: true,
            message: 'Kalem adisyondan başarıyla düşürüldü/silindi.',
        });
    }
    catch (error) {
        console.error('Kalem iptal edilirken hata:', error);
        res.status(500).json({ success: false, error: 'Kalem iptal işlemi başarısız oldu.' });
    }
}
// 8. Parçalı veya Tam Ödeme Al (Nakit / Kart / Karışık)
export async function makePayment(req, res) {
    try {
        const businessId = req.user?.businessId;
        const cashierId = req.user?.userId || req.user?.id;
        const { tableId } = req.params;
        const { amountCents, method, cashAmountCents = 0, cardAmountCents = 0 } = req.body;
        if (!businessId || !cashierId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!amountCents || amountCents <= 0) {
            res.status(400).json({ success: false, error: 'Geçersiz ödeme tutarı.' });
            return;
        }
        const table = await prisma.restaurantTable.findFirst({
            where: { id: tableId, businessId },
        });
        if (!table || !table.currentOrderId) {
            res.status(400).json({ success: false, error: 'Masada aktif bir sipariş bulunmuyor.' });
            return;
        }
        const orderId = table.currentOrderId;
        const order = await prisma.order.findUnique({
            where: { id: orderId },
            include: { payments: true },
        });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        const alreadyPaidCents = order.payments.reduce((sum, p) => sum + p.amountCents, 0);
        const remainingCents = order.totalAmountCents - alreadyPaidCents;
        if (amountCents > remainingCents) {
            res.status(400).json({
                success: false,
                error: `Girilen tutar kalan bakiyeden (${(remainingCents / 100).toFixed(2)} ₺) fazla olamaz.`,
            });
            return;
        }
        let isFullyPaid = false;
        let paymentRecord;
        await prisma.$transaction(async (tx) => {
            paymentRecord = await tx.payment.create({
                data: {
                    businessId,
                    orderId,
                    cashierId,
                    method: method,
                    amountCents,
                    cashAmountCents: method === 'CASH' ? amountCents : (method === 'MIXED' ? cashAmountCents : 0),
                    cardAmountCents: method === 'CARD' ? amountCents : (method === 'MIXED' ? cardAmountCents : 0),
                },
            });
            const totalPaidAfterThis = alreadyPaidCents + amountCents;
            if (totalPaidAfterThis >= order.totalAmountCents) {
                isFullyPaid = true;
                await tx.order.update({
                    where: { id: orderId },
                    data: { status: 'PAID' },
                });
                await tx.restaurantTable.update({
                    where: { id: tableId },
                    data: {
                        status: TableStatus.AVAILABLE,
                        currentOrderId: null,
                    },
                });
            }
        });
        try {
            const io = getIO();
            const waitersRoom = `business:${businessId}:waiters`;
            if (isFullyPaid) {
                io.to(waitersRoom).emit('table:updated', {
                    tableId,
                    tableStatus: TableStatus.AVAILABLE,
                });
            }
            else {
                io.to(waitersRoom).emit('table:updated', {
                    tableId,
                    orderId,
                });
            }
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        const nextRemainingCents = remainingCents - amountCents;
        res.json({
            success: true,
            isFullyPaid,
            remainingAmountCents: nextRemainingCents,
            message: isFullyPaid
                ? 'Hesabın tamamı tahsil edildi. Masa kapatıldı.'
                : `Ödeme alındı. Kalan tutar: ${(nextRemainingCents / 100).toFixed(2)} ₺`,
            data: paymentRecord,
        });
    }
    catch (error) {
        console.error('Ödeme alınırken hata:', error);
        res.status(500).json({ success: false, error: 'Ödeme işlemi gerçekleştirilemedi.' });
    }
}
// 9. Mutfak Ekranı İçin Aktif Siparişleri Getirme (Kategori & İstasyon Destekli)
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
                        status: { in: [OrderItemStatus.PENDING, OrderItemStatus.PREPARING] },
                    },
                },
            },
            include: {
                table: { select: { id: true, name: true } },
                waiter: { select: { id: true, fullName: true } },
                items: {
                    where: {
                        status: { in: [OrderItemStatus.PENDING, OrderItemStatus.PREPARING, OrderItemStatus.READY] },
                    },
                    include: {
                        product: {
                            select: {
                                id: true,
                                categoryId: true,
                                category: { select: { id: true, name: true } },
                            },
                        },
                    },
                    orderBy: { createdAt: 'asc' },
                },
            },
            orderBy: { createdAt: 'asc' },
        });
        res.json({
            success: true,
            data: orders,
        });
    }
    catch (error) {
        console.error('Mutfak siparişleri alınırken hata:', error);
        res.status(500).json({ success: false, error: 'Mutfak siparişleri getirilemedi.' });
    }
}
// 10. Mutfak Kalem Durumu Güncelleme
export async function updateOrderItemStatus(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { orderItemId } = req.params;
        const { status } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const item = await prisma.orderItem.findUnique({
            where: { id: orderItemId },
            include: { order: { include: { table: true } } },
        });
        if (!item || item.order.businessId !== businessId) {
            res.status(404).json({ success: false, error: 'Sipariş kalemi bulunamadı.' });
            return;
        }
        const updatedItem = await prisma.orderItem.update({
            where: { id: orderItemId },
            data: { status },
        });
        try {
            const io = getIO();
            const waitersRoom = `business:${businessId}:waiters`;
            const kitchenRoom = `business:${businessId}:kitchen`;
            io.to(kitchenRoom).emit('kitchen:item_updated', {
                orderId: item.orderId,
                orderItemId: item.id,
                newStatus: status,
            });
            if (status === 'READY') {
                io.to(waitersRoom).emit('order:item_ready', {
                    orderId: item.orderId,
                    tableName: item.order.table.name,
                    productName: item.productNameSnapshot,
                    quantity: item.quantity,
                });
            }
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({ success: true, data: updatedItem });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Kalem durumu güncellenemedi.' });
    }
}
// 11. Siparişteki Tüm Kalemleri Tek Tıkla Hazırla ve Gönder
export async function readyAllOrderItems(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { orderId } = req.params;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        const order = await prisma.order.findFirst({
            where: { id: orderId, businessId },
            include: { table: true },
        });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        await prisma.$transaction(async (tx) => {
            await tx.orderItem.updateMany({
                where: {
                    orderId,
                    status: { in: ['PENDING', 'PREPARING'] },
                },
                data: { status: 'READY' },
            });
            await tx.order.update({
                where: { id: orderId },
                data: { status: 'READY' },
            });
        });
        try {
            const io = getIO();
            const waitersRoom = `business:${businessId}:waiters`;
            const kitchenRoom = `business:${businessId}:kitchen`;
            io.to(kitchenRoom).emit('kitchen:order_completed', { orderId });
            io.to(waitersRoom).emit('order:all_ready', {
                orderId,
                tableName: order.table.name,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.json({ success: true, message: 'Tüm sipariş hazırlandı.' });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'İşlem tamamlanamadı.' });
    }
}
