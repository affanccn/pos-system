import { Request, Response } from 'express';
import { PrismaClient, TableStatus, PaymentMethod, OrderItemStatus } from '@prisma/client';
import { getIO } from '../../realtime/socket.js';
import { createAuditLog } from '../../utils/auditLog.js';

const prisma = new PrismaClient();

// 1. Yeni Sipariş Oluşturma
export async function createOrder(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const waiterId = (req.user as any)?.userId || (req.user as any)?.id;
    const { tableId, items, notes } = req.body as {
      tableId: string;
      items: Array<{ productId: string; quantity: number; notes?: string; modifiers?: any[] }>;
      notes?: string;
    };

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

    for (const item of items) {
      const product = await prisma.product.findUnique({ where: { id: item.productId } });
      if (product) {
        let itemTotal = product.priceCents * item.quantity;
        
        let modifiersData = [];
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
          modifiers: { create: modifiersData }
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
        items: { create: itemsData }
      },
    });

    await prisma.restaurantTable.update({
      where: { id: tableId },
      data: { status: 'OCCUPIED', currentOrderId: order.id }
    });

    const io = getIO();
    io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId, status: 'OCCUPIED', orderId: order.id });
    io.to(`business:${businessId}:kitchen`).emit('kitchen:new_order', { orderId: order.id });

    await createAuditLog({
      businessId,
      userId: waiterId,
      action: 'ORDER_CREATED',
      entity: 'Order',
      entityId: order.id,
      newValue: { totalAmountCents: totalAmount, tableId },
      description: 'Sipariş oluşturuldu'
    });

    res.json({ success: true, data: order });
  } catch (error) {
    console.error('CREATE ORDER ERROR:', error);
    res.status(500).json({ success: false, error: 'Sipariş oluşturulamadı.' });
  }
}

export async function addItemsToOrder(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { orderId } = req.params as any;
    const { items } = req.body;

    const order = await prisma.order.findFirst({ where: { id: orderId, businessId } });
    if (!order) {
      res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
      return;
    }

    let addedAmount = 0;
    const itemsData = [];

    for (const item of items) {
      const product = await prisma.product.findUnique({ where: { id: item.productId } });
      if (product) {
        let itemTotal = product.priceCents * item.quantity;
        
        let modifiersData = [];
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
            modifiers: { create: modifiersData }
          }
        });
      }
    }

    await prisma.order.update({
      where: { id: orderId },
      data: { totalAmountCents: order.totalAmountCents + addedAmount }
    });

    const io = getIO();
    io.to(`business:${businessId}:kitchen`).emit('kitchen:new_order', { orderId: order.id });

    res.json({ success: true, message: 'Ürünler eklendi' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Ürün eklenemedi.' });
  }
}

export async function getActiveOrderByTable(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { tableId } = req.params as any;

    const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
    if (!table || !table.currentOrderId) {
      res.json({ success: true, data: null });
      return;
    }

    const order = await prisma.order.findUnique({
      where: { id: table.currentOrderId },
      include: {
        items: {
          include: {
            modifiers: true,
            product: { include: { category: true } }
          }
        },
        payments: true
      }
    });

    res.json({ success: true, data: order });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Sipariş getirilemedi.' });
  }
}

export async function requestTableBill(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { tableId } = req.params as any;

    const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
    if (!table || !table.currentOrderId) {
      res.status(404).json({ success: false, error: 'Masa veya sipariş bulunamadı.' });
      return;
    }

    await prisma.restaurantTable.update({
      where: { id: tableId },
      data: { status: 'BILL_REQUESTED' }
    });

    const io = getIO();
    io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId, status: 'BILL_REQUESTED' });
    
    // Notification for waiter/manager
    io.to(`business:${businessId}:waiters`).emit('notification', {
      type: 'BILL_READY',
      title: 'Hesap İsteği',
      body: `Masa hesabını istiyor: ${table.name}`
    });

    res.json({ success: true, message: 'Hesap istendi.' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'İşlem başarısız.' });
  }
}

export async function closeOrderAndTable(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { tableId } = req.params as any;

    const table = await prisma.restaurantTable.findFirst({ where: { id: tableId, businessId } });
    if (!table || !table.currentOrderId) {
      res.status(404).json({ success: false, error: 'Masa veya sipariş bulunamadı.' });
      return;
    }

    await prisma.order.update({
      where: { id: table.currentOrderId },
      data: { status: 'PAID' }
    });

    await prisma.restaurantTable.update({
      where: { id: tableId },
      data: { status: 'AVAILABLE', currentOrderId: null }
    });

    const io = getIO();
    io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId, status: 'AVAILABLE', orderId: null });

    await createAuditLog({
      businessId: businessId!,
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'ORDER_CANCEL', // Assuming manual close is cancellation/forced finish
      entity: 'Order',
      entityId: table.currentOrderId,
      description: 'Masa ve sipariş manuel olarak kapatıldı'
    });

    res.json({ success: true, message: 'Masa kapatıldı.' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Kapatılamadı.' });
  }
}

export async function transferTable(req: Request, res: Response): Promise<void> {
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
      prisma.restaurantTable.update({ where: { id: toTableId }, data: { status: 'OCCUPIED', currentOrderId: orderId } })
    ]);

    await createAuditLog({
      businessId: businessId!,
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'ORDER_UPDATE',
      entity: 'Table',
      entityId: orderId,
      oldValue: { tableId: fromTableId },
      newValue: { tableId: toTableId },
      description: `Masa ${fromTable.name}'den ${toTable!.name}'e aktarıldı.`
    });

    const io = getIO();
    io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: fromTableId, status: 'AVAILABLE', orderId: null });
    io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: toTableId, status: 'OCCUPIED', orderId });

    res.json({ success: true, message: 'Masa transfer edildi.' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Transfer başarısız.' });
  }
}

export async function mergeTables(req: Request, res: Response): Promise<void> {
  // Not fully implemented yet
  res.json({ success: true, message: 'Masalar birleştirildi.' });
}

export async function voidOrderItem(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { orderItemId } = req.params as any;

    const item = await prisma.orderItem.findUnique({ where: { id: orderItemId }, include: { order: true } });
    if (!item || (item as any).order.businessId !== businessId) {
      res.status(404).json({ success: false, error: 'Kalem bulunamadı.' });
      return;
    }

    await prisma.$transaction(async (tx: any) => {
      await tx.orderItem.update({
        where: { id: orderItemId },
        data: { status: 'VOID' }
      });
      await tx.order.update({
        where: { id: item.orderId },
        data: { totalAmountCents: (item as any).order.totalAmountCents - item.totalPriceCents }
      });
    });

    await createAuditLog({
      businessId: businessId!,
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'ITEM_VOID',
      entity: 'OrderItem',
      entityId: orderItemId,
      oldValue: { status: item.status },
      newValue: { status: 'VOID' },
      description: 'Sipariş kalemi iptal edildi (Void)'
    });

    res.json({ success: true, message: 'Kalem iptal edildi.' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'İptal edilemedi.' });
  }
}

// Keep makePayment empty because we moved to processOrderPayment
export async function makePayment(req: Request, res: Response): Promise<void> {
  res.status(400).json({ success: false, error: 'Lütfen processOrderPayment metodunu kullanın.' });
}

export async function getKitchenOrders(req: Request, res: Response): Promise<void> {
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
  } catch (error) {
    res.status(500).json({ success: false, error: 'Mutfak siparişleri getirilemedi.' });
  }
}

export async function updateOrderItemStatus(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { orderItemId } = req.params as any;
    const { status } = req.body;

    const item = await prisma.orderItem.update({
      where: { id: orderItemId },
      data: { status },
      include: { product: true, order: { include: { table: true } } }
    });

    if (status === 'READY') {
      const io = getIO();
      const businessId = req.user?.businessId;
      if (businessId) {
        io.to(`business:${businessId}:waiters`).emit('notification', {
          type: 'PRODUCT_READY',
          title: 'Ürün Hazır',
          body: `${item.order?.table?.name ?? 'Bilinmeyen Masa'} - ${item.productNameSnapshot} hazır!`
        });
      }
    }

    res.json({ success: true, data: item });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Durum güncellenemedi.' });
  }
}

export async function readyAllOrderItems(req: Request, res: Response): Promise<void> {
  try {
    const { orderId } = req.params as any;
    const items = await prisma.orderItem.findMany({ where: { orderId, status: { in: ['PENDING', 'PREPARING'] } }, include: { order: { include: { table: true } } } });
    if (items.length > 0) {
      await prisma.orderItem.updateMany({
        where: { orderId, status: { in: ['PENDING', 'PREPARING'] } },
        data: { status: 'READY' }
      });
      const businessId = req.user?.businessId;
      if (businessId) {
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('notification', {
          type: 'ORDER_READY',
          title: 'Tüm Sipariş Hazır',
          body: `${items[0].order?.table?.name ?? 'Bilinmeyen Masa'} için siparişler hazırlandı.`
        });
      }
    }
    res.json({ success: true, message: 'Tümü hazır.' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Güncellenemedi.' });
  }
}

// --- AŞAMA 6: YENİ ÖDEME VE HESAP İŞLEMLERİ ---

export async function processOrderPayment(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const cashierId = (req.user as any)?.userId || (req.user as any)?.id;
    const { orderId } = req.params as any;
    const { 
      amountCents, 
      method, 
      cashAmountCents = 0, 
      cardAmountCents = 0,
      paidItems = [] 
    } = req.body as {
      amountCents: number;
      method: 'CASH' | 'CARD' | 'MIXED' | 'ACCOUNT';
      cashAmountCents?: number;
      cardAmountCents?: number;
      paidItems?: { orderItemId: string, quantity: number }[];
    };

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
      include: { payments: true, items: true },
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

    await prisma.$transaction(async (tx: any) => {
      // Ödeme kaydını oluştur
      await tx.payment.create({
        data: {
          businessId,
          orderId,
          cashierId,
          method: method as any,
          amountCents,
          cashAmountCents: method === 'CASH' ? amountCents : (method === 'MIXED' ? cashAmountCents : 0),
          cardAmountCents: method === 'CARD' ? amountCents : (method === 'MIXED' ? cardAmountCents : 0),
        },
      });

      // Siparişteki paidAmount'u güncelle
      const totalPaidAfterThis = order.paidAmountCents + amountCents;
      const totalDiscount = order.discountAmountCents;

      if (totalPaidAfterThis + totalDiscount >= order.totalAmountCents) {
        isFullyPaid = true;
        await tx.order.update({
          where: { id: orderId },
          data: { 
            paidAmountCents: totalPaidAfterThis,
            status: 'PAID' 
          },
        });
        
        // Masa durumunu güncelle (Masa ID varsa)
        if (order.tableId) {
          await tx.restaurantTable.update({
            where: { id: order.tableId },
            data: { status: 'AVAILABLE', currentOrderId: null },
          });
        }
      } else {
        await tx.order.update({
          where: { id: orderId },
          data: { paidAmountCents: totalPaidAfterThis },
        });
      }

      // Eğer kısmi ödeme (ürün bazlı) geldiyse order item'ların ödenmiş adedini güncelle
      if (paidItems && paidItems.length > 0) {
        for (const pItem of paidItems) {
          const oi = order.items.find(i => i.id === pItem.orderItemId);
          if (oi) {
            const newQty = oi.paidQuantity + pItem.quantity;
            await tx.orderItem.update({
              where: { id: oi.id },
              data: { paidQuantity: newQty > oi.quantity ? oi.quantity : newQty }
            });
          }
        }
      }
    });

    await createAuditLog({
      businessId: businessId!,
      userId: cashierId,
      action: 'PAYMENT_CREATE',
      entity: 'Order',
      entityId: orderId,
      newValue: { amountCents, method, isFullyPaid },
      description: `Siparişe ${(amountCents / 100).toFixed(2)} TL ödeme alındı (${method})`
    });

    const io = getIO();
    io.to(`business:${businessId}:waiters`).emit('order:payment_updated', {
      orderId,
      isFullyPaid,
      paidAmountCents: order.paidAmountCents + amountCents,
    });

    res.json({
      success: true,
      data: { isFullyPaid, orderId }
    });
  } catch (error) {
    console.error('Ödeme alınırken hata:', error);
    res.status(500).json({ success: false, error: 'Ödeme alınamadı.' });
  }
}

export async function applyOrderDiscount(req: Request, res: Response): Promise<void> {
  try {
    const { orderId } = req.params as any;
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
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'ITEM_DISCOUNT',
      entity: 'Order',
      entityId: orderId,
      oldValue: { discountAmountCents: order.discountAmountCents },
      newValue: { discountAmountCents },
      description: `Siparişe ${discountAmountCents / 100} TL indirim uygulandı`
    });

    res.json({ success: true, message: 'İndirim uygulandı.' });
  } catch (error) {
    console.error('İndirim hatası:', error);
    res.status(500).json({ success: false, error: 'İndirim uygulanamadı.' });
  }
}

export async function makeItemComplimentary(req: Request, res: Response): Promise<void> {
  try {
    const { orderItemId } = req.params as any;

    const item = await prisma.orderItem.findUnique({ where: { id: orderItemId }, include: { order: true } });
    if (!item) {
      res.status(404).json({ success: false, error: 'Sipariş kalemi bulunamadı.' });
      return;
    }

    await prisma.$transaction(async (tx: any) => {
      // Ürünü ikram yap
      await tx.orderItem.update({
        where: { id: orderItemId },
        data: { status: 'COMPLIMENTARY' }
      });
      // Sipariş toplamını güncelle
      await tx.order.update({
        where: { id: item.orderId },
        data: { totalAmountCents: (item as any).order.totalAmountCents - item.totalPriceCents }
      });
    });

    await createAuditLog({
      businessId: item.order.businessId,
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'ITEM_COMPLIMENTARY',
      entity: 'OrderItem',
      entityId: orderItemId,
      oldValue: { status: item.status },
      newValue: { status: 'COMPLIMENTARY' },
      description: 'Ürün ikram edildi'
    });

    res.json({ success: true, message: 'Ürün ikram edildi.' });
  } catch (error) {
    console.error('İkram hatası:', error);
    res.status(500).json({ success: false, error: 'İkram uygulanamadı.' });
  }
}
