import { prisma } from '../../config/prisma.js';
import { TableStatus } from '@prisma/client';
import { getIO } from '../../realtime/socket.js';
// 1. İşletmeye ait tüm masaları getir (Garson & Yönetici)
export async function getTables(req, res) {
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
    }
    catch (error) {
        console.error('Masalar getirilirken hata:', error);
        res.status(500).json({ success: false, error: 'Masalar listelenemedi.' });
    }
}
// 2. Yeni masa ekle (OWNER ve MANAGER)
export async function createTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { name, capacity, sortOrder } = req.body;
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
        }
        catch (_) { }
        res.status(201).json({
            success: true,
            message: `${newTable.name} başarıyla oluşturuldu.`,
            data: newTable,
        });
    }
    catch (error) {
        console.error('Masa eklenirken hata:', error);
        res.status(500).json({ success: false, error: 'Masa oluşturulamadı.' });
    }
}
// 3. Masa bilgilerini güncelle (OWNER ve MANAGER)
export async function updateTable(req, res) {
    try {
        const businessId = req.user?.businessId;
        const id = String(req.params.id);
        const { name, capacity, sortOrder } = req.body;
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
        const updateData = {};
        if (name && typeof name === 'string' && name.trim().length > 0) {
            updateData.name = name.trim();
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
        }
        catch (_) { }
        res.json({
            success: true,
            message: 'Masa bilgileri güncellendi.',
            data: updated,
        });
    }
    catch (error) {
        console.error('Masa güncellenirken hata:', error);
        res.status(500).json({ success: false, error: 'Masa güncellenemedi.' });
    }
}
// 4. Masa sil / pasife al (OWNER ve MANAGER)
export async function deleteTable(req, res) {
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
        }
        catch (_) { }
        res.json({
            success: true,
            message: `${table.name} başarıyla kaldırıldı.`,
        });
    }
    catch (error) {
        console.error('Masa silinirken hata:', error);
        res.status(500).json({ success: false, error: 'Masa silinemedi.' });
    }
}
// 5. Masa durumunu güncelle (AVAILABLE / OCCUPIED / BILL_REQUESTED)
export async function updateTableStatus(req, res) {
    try {
        const businessId = req.user?.businessId;
        const id = String(req.params.id);
        const { status } = req.body;
        const validStatuses = ['AVAILABLE', 'OCCUPIED', 'BILL_REQUESTED'];
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
        }
        catch (_) { }
        res.json({
            success: true,
            message: `Masa durumu ${status} olarak güncellendi.`,
            data: updated,
        });
    }
    catch (error) {
        console.error('Masa durumu güncellenirken hata:', error);
        res.status(500).json({ success: false, error: 'Masa durumu güncellenemedi.' });
    }
}
