import type { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';
import { TableStatus } from '@prisma/client';
import { getIO } from '../../realtime/socket.js';
import { createAuditLog } from '../../utils/auditLog.js';

// 1. İşletmeye ait tüm masaları getir (Garson & Yönetici)
export async function getTables(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum işletme bilgisi bulunamadı.' });
      return;
    }

    const tables = await prisma.restaurantTable.findMany({
      where: {
        businessId,
        isActive: true,
      },
      orderBy: {
        sortOrder: 'asc',
      },
      include: {
        currentOrder: {
          select: {
            id: true,
            orderNumber: true,
            status: true,
            totalAmountCents: true,
            createdAt: true,
            waiter: {
              select: {
                fullName: true,
              },
            },
          },
        },
      },
    });

    res.json({
      success: true,
      data: tables.map((t) => ({
        id: t.id,
        name: t.name,
        section: t.section,
        capacity: t.capacity,
        status: t.status,
        sortOrder: t.sortOrder,
        activeOrder: t.currentOrder
          ? {
              orderId: t.currentOrder.id,
              orderNumber: t.currentOrder.orderNumber,
              status: t.currentOrder.status,
              totalAmountCents: t.currentOrder.totalAmountCents,
              waiterName: t.currentOrder.waiter.fullName,
              openedAt: t.currentOrder.createdAt,
            }
          : null,
      })),
    });
  } catch (error) {
    console.error('Masalar getirilirken hata:', error);
    res.status(500).json({ success: false, error: 'Masalar listelenemedi.' });
  }
}

// 2. Yeni masa ekle (OWNER ve MANAGER)
export async function createTable(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { name, capacity, sortOrder, section } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadı.' });
      return;
    }

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      res.status(400).json({ success: false, error: 'Masa adı zorunludur.' });
      return;
    }

    const trimmedName = name.trim();

    // Aynı isimde aktif masa var mı kontrol et
    const existing = await prisma.restaurantTable.findFirst({
      where: { businessId, name: trimmedName, isActive: true },
    });

    if (existing) {
      res.status(409).json({ success: false, error: 'Bu isimde bir masa zaten mevcut.' });
      return;
    }

    const newTable = await prisma.restaurantTable.create({
      data: {
        businessId,
        name: trimmedName,
        section: section?.trim() || 'Salon',
        capacity: capacity ? Number(capacity) : 4,
        sortOrder: sortOrder ? Number(sortOrder) : 0,
        status: TableStatus.AVAILABLE,
        isActive: true,
      },
    });

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', {
        tableId: newTable.id,
        tableStatus: TableStatus.AVAILABLE,
      });
    } catch (_) {}

    res.status(201).json({
      success: true,
      message: `${newTable.name} başarıyla oluşturuldu.`,
      data: newTable,
    });
  } catch (error) {
    console.error('Masa eklenirken hata:', error);
    res.status(500).json({ success: false, error: 'Masa oluşturulamadı.' });
  }
}

// 3. Masa bilgilerini güncelle (OWNER ve MANAGER)
export async function updateTable(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = String(req.params.id);
    const { name, capacity, sortOrder, section } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadı.' });
      return;
    }

    const existing = await prisma.restaurantTable.findFirst({
      where: { id, businessId },
    });

    if (!existing) {
      res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
      return;
    }

    const updateData: any = {};
    if (name && typeof name === 'string' && name.trim().length > 0) {
      updateData.name = name.trim();
    }
    if (section && typeof section === 'string' && section.trim().length > 0) {
      updateData.section = section.trim();
    }
    if (capacity !== undefined) {
      updateData.capacity = Number(capacity);
    }
    if (sortOrder !== undefined) {
      updateData.sortOrder = Number(sortOrder);
    }

    const updated = await prisma.restaurantTable.update({
      where: { id },
      data: updateData,
    });

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', {
        tableId: updated.id,
        tableStatus: updated.status,
      });
    } catch (_) {}

    res.json({
      success: true,
      message: 'Masa bilgileri güncellendi.',
      data: updated,
    });
  } catch (error) {
    console.error('Masa güncellenirken hata:', error);
    res.status(500).json({ success: false, error: 'Masa güncellenemedi.' });
  }
}

// 4. Masa sil / pasife al (OWNER ve MANAGER)
export async function deleteTable(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = String(req.params.id);

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadı.' });
      return;
    }

    const table = await prisma.restaurantTable.findFirst({
      where: { id, businessId },
    });

    if (!table) {
      res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
      return;
    }

    if (table.status !== TableStatus.AVAILABLE || table.currentOrderId) {
      res.status(400).json({
        success: false,
        error: 'Üzerinde açık sipariş veya hesap olan masa silinemez. Önce masayı kapatın veya aktarın.',
      });
      return;
    }

    await prisma.restaurantTable.update({
      where: { id },
      data: { isActive: false },
    });

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', {
        tableId: id,
        tableStatus: TableStatus.AVAILABLE,
      });
    } catch (_) {}

    res.json({
      success: true,
      message: `${table.name} başarıyla kaldırıldı.`,
    });
  } catch (error) {
    console.error('Masa silinirken hata:', error);
    res.status(500).json({ success: false, error: 'Masa silinemedi.' });
  }
}

// 5. Masa durumunu güncelle (AVAILABLE / OCCUPIED / BILL_REQUESTED)
export async function updateTableStatus(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = String(req.params.id);
    const { status } = req.body as { status: TableStatus };

    const validStatuses: TableStatus[] = ['AVAILABLE', 'OCCUPIED', 'BILL_REQUESTED'];
    if (!validStatuses.includes(status)) {
      res.status(400).json({ success: false, error: 'Geçersiz masa durumu.' });
      return;
    }

    const table = await prisma.restaurantTable.findFirst({
      where: { id, businessId },
    });

    if (!table) {
      res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
      return;
    }

    const updated = await prisma.restaurantTable.update({
      where: { id },
      data: { status },
    });

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', {
        tableId: updated.id,
        tableStatus: updated.status,
      });
    } catch (_) {}

    res.json({
      success: true,
      message: `Masa durumu ${status} olarak güncellendi.`,
      data: updated,
    });
  } catch (error) {
    console.error('Masa durumu güncellenirken hata:', error);
    res.status(500).json({ success: false, error: 'Masa durumu güncellenemedi.' });
  }
}

// 6. Masa Transferi
export async function transferTable(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { fromTableId, toTableId } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Yetkisiz erişim.' });
      return;
    }

    const fromTable = await prisma.restaurantTable.findUnique({
      where: { id: fromTableId },
      include: { currentOrder: true },
    });
    const toTable = await prisma.restaurantTable.findUnique({
      where: { id: toTableId },
    });

    if (!fromTable || !toTable || fromTable.businessId !== businessId || toTable.businessId !== businessId) {
      res.status(404).json({ success: false, error: 'Kaynak veya hedef masa bulunamadı.' });
      return;
    }

    if (!fromTable.currentOrderId) {
      res.status(400).json({ success: false, error: 'Kaynak masada aktif bir sipariş yok.' });
      return;
    }

    if (toTable.currentOrderId) {
      res.status(400).json({ success: false, error: 'Hedef masa şu an dolu. Lütfen masaları birleştirin.' });
      return;
    }

    const orderId = fromTable.currentOrderId;

    await prisma.$transaction([
      // Siparişi yeni masaya bağla
      prisma.order.update({
        where: { id: orderId },
        data: { tableId: toTable.id },
      }),
      // Kaynak masayı boşalt
      prisma.restaurantTable.update({
        where: { id: fromTable.id },
        data: { currentOrderId: null, status: 'AVAILABLE' },
      }),
      // Hedef masayı doldur
      prisma.restaurantTable.update({
        where: { id: toTable.id },
        data: { currentOrderId: orderId, status: fromTable.status },
      }),
    ]);

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: fromTable.id, tableStatus: 'AVAILABLE' });
      io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: toTable.id, tableStatus: fromTable.status });
    } catch (_) {}

    res.json({ success: true, message: 'Masa başarıyla taşındı.' });
  } catch (error) {
    console.error('Masa taşıma hatası:', error);
    res.status(500).json({ success: false, error: 'Masa taşınırken bir hata oluştu.' });
  }
}

// 7. Masaları Birleştir
export async function mergeTables(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { fromTableId, toTableId } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Yetkisiz erişim.' });
      return;
    }

    const fromTable = await prisma.restaurantTable.findUnique({ where: { id: fromTableId } });
    const toTable = await prisma.restaurantTable.findUnique({ where: { id: toTableId } });

    if (!fromTable || !toTable || fromTable.businessId !== businessId || toTable.businessId !== businessId) {
      res.status(404).json({ success: false, error: 'Kaynak veya hedef masa bulunamadı.' });
      return;
    }

    if (!fromTable.currentOrderId) {
      res.status(400).json({ success: false, error: 'Kaynak masada aktif bir sipariş yok.' });
      return;
    }

    if (!toTable.currentOrderId) {
      const orderId = fromTable.currentOrderId;
      await prisma.$transaction([
        prisma.order.update({ where: { id: orderId }, data: { tableId: toTable.id } }),
        prisma.restaurantTable.update({ where: { id: fromTable.id }, data: { currentOrderId: null, status: 'AVAILABLE' } }),
        prisma.restaurantTable.update({ where: { id: toTable.id }, data: { currentOrderId: orderId, status: fromTable.status } }),
      ]);
      try {
        const io = getIO();
        io.to(`business:${businessId}:waiters`).emit('table:updated', { reload: true });
      } catch (_) {}
      
      await createAuditLog({
        businessId,
        userId: (req.user as any)?.userId || (req.user as any)?.id,
        action: 'ORDER_UPDATE',
        entity: 'Table',
        entityId: orderId,
        oldValue: { tableId: fromTable.id, name: fromTable.name },
        newValue: { tableId: toTable.id, name: toTable.name },
        description: `Masa ${fromTable.name}'den ${toTable.name}'e aktarıldı (hedef masa boştu).`
      });

      res.json({ success: true, message: 'Ürünler aktarıldı (Hedef masa boş olduğu için direkt taşındı).' });
      return;
    }

    const fromOrder = await prisma.order.findUnique({ where: { id: fromTable.currentOrderId } });
    const toOrder = await prisma.order.findUnique({ where: { id: toTable.currentOrderId } });

    if (!fromOrder || !toOrder) {
      res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
      return;
    }

    // fromOrder'daki tüm item'ları ve ödemeleri toOrder'a geçir
    await prisma.$transaction([
      prisma.orderItem.updateMany({
        where: { orderId: fromOrder.id },
        data: { orderId: toOrder.id },
      }),
      prisma.payment.updateMany({
        where: { orderId: fromOrder.id },
        data: { orderId: toOrder.id },
      }),
      prisma.order.update({
        where: { id: toOrder.id },
        data: { 
          totalAmountCents: toOrder.totalAmountCents + fromOrder.totalAmountCents,
          paidAmountCents: toOrder.paidAmountCents + fromOrder.paidAmountCents,
          discountAmountCents: toOrder.discountAmountCents + fromOrder.discountAmountCents
        },
      }),
      prisma.restaurantTable.update({
        where: { id: fromTable.id },
        data: { currentOrderId: null, status: 'AVAILABLE' },
      }),
      // Kaynak siparişi sil
      prisma.order.delete({
        where: { id: fromOrder.id },
      }),
    ]);

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: fromTable.id, tableStatus: 'AVAILABLE' });
      io.to(`business:${businessId}:waiters`).emit('table:updated', { tableId: toTable.id, tableStatus: toTable.status });
    } catch (_) {}

    await createAuditLog({
      businessId,
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'ORDER_UPDATE',
      entity: 'Table',
      entityId: toOrder.id,
      oldValue: { tableId: fromTable.id, name: fromTable.name },
      newValue: { tableId: toTable.id, name: toTable.name },
      description: `Masa ${fromTable.name}, ${toTable.name} ile birleştirildi.`
    });

    res.json({ success: true, message: 'Masalar başarıyla birleştirildi.' });
  } catch (error) {
    console.error('Masa birleştirme hatası:', error);
    res.status(500).json({ success: false, error: 'Masalar birleştirilirken hata oluştu.' });
  }
}

// 8. Masaları Yeniden Sırala
export async function reorderTables(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { items } = req.body as { items: { id: string, sortOrder: number }[] };

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Yetkisiz erişim.' });
      return;
    }

    if (!Array.isArray(items)) {
      res.status(400).json({ success: false, error: 'Geçersiz veri formatı.' });
      return;
    }

    await prisma.$transaction(
      items.map(item => 
        prisma.restaurantTable.updateMany({
          where: { id: item.id, businessId },
          data: { sortOrder: item.sortOrder },
        })
      )
    );

    try {
      const io = getIO();
      io.to(`business:${businessId}:waiters`).emit('table:updated', { reload: true });
    } catch (_) {}

    res.json({ success: true, message: 'Masalar yeniden sıralandı.' });
  } catch (error) {
    console.error('Masa sıralama hatası:', error);
    res.status(500).json({ success: false, error: 'Sıralama güncellenemedi.' });
  }
}

// 9. Garson Çağır (Müşteri vb.)
export async function callWaiter(req: Request, res: Response): Promise<void> {
  try {
    // Note: In a real customer app this might not have req.user, 
    // but for now we assume it has a valid token or a specific table token.
    const businessId = req.user?.businessId || req.body.businessId; 
    const { id } = req.params;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Yetkisiz erişim.' });
      return;
    }

    const table = await prisma.restaurantTable.findFirst({
      where: { id: id as string, businessId: businessId as string }
    });

    if (!table) {
      res.status(404).json({ success: false, error: 'Masa bulunamadı.' });
      return;
    }

    const io = getIO();
    io.to(`business:${businessId}:waiters`).emit('notification', {
      type: 'WAITER_CALL',
      title: 'Garson Çağrısı',
      body: `${table.name} masasından çağrılıyorsunuz.`
    });

    res.json({ success: true, message: 'Garson çağrıldı.' });
  } catch (error) {
    console.error('Garson çağırma hatası:', error);
    res.status(500).json({ success: false, error: 'Çağrı yapılamadı.' });
  }
}