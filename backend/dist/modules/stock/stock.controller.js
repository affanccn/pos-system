import { prisma } from '../../config/prisma.js';
import { getIO } from '../../realtime/socket.js';
export async function getStockItems(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'İşletme oturumu bulunamadı.' });
            return;
        }
        const items = await prisma.stockItem.findMany({
            where: { businessId, isActive: true },
            orderBy: { name: 'asc' },
        });
        res.json({ success: true, data: items });
    }
    catch (error) {
        console.error('Stok getirilirken hata:', error);
        res.status(500).json({ success: false, error: 'Stoklar yüklenemedi.' });
    }
}
export async function createStockItem(req, res) {
    try {
        const businessId = req.user?.businessId;
        const role = req.user?.role;
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
            return;
        }
        const { name, unit, minAmount, unitCostCents, supplier } = req.body;
        if (!name || !unit) {
            res.status(400).json({ success: false, error: 'Ad ve birim zorunludur.' });
            return;
        }
        const item = await prisma.stockItem.create({
            data: {
                businessId: businessId,
                name: name.trim(),
                unit: unit.trim(),
                minAmount: minAmount ? Number(minAmount) : 0,
                unitCostCents: unitCostCents ? Number(unitCostCents) : 0,
                supplier: supplier ? String(supplier).trim() : null,
            },
        });
        res.status(201).json({ success: true, data: item });
    }
    catch (error) {
        console.error('Stok eklenirken hata:', error);
        res.status(500).json({ success: false, error: 'Stok oluşturulamadı.' });
    }
}
export async function updateStockItem(req, res) {
    try {
        const businessId = req.user?.businessId;
        const role = req.user?.role;
        const id = String(req.params.id);
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
            return;
        }
        const { name, unit, currentAmount, minAmount, unitCostCents, supplier, isCritical } = req.body;
        const item = await prisma.stockItem.update({
            where: { id },
            data: {
                ...(name && { name: name.trim() }),
                ...(unit && { unit: unit.trim() }),
                ...(currentAmount !== undefined && { currentAmount: Number(currentAmount) }),
                ...(minAmount !== undefined && { minAmount: Number(minAmount) }),
                ...(unitCostCents !== undefined && { unitCostCents: Number(unitCostCents) }),
                ...(supplier !== undefined && { supplier: supplier ? String(supplier).trim() : null }),
                ...(isCritical !== undefined && { isCritical: Boolean(isCritical) }),
            },
        });
        if (item.currentAmount <= item.minAmount) {
            try {
                const io = getIO();
                io.to(`business:${businessId}:kitchen`).to(`business:${businessId}:managers`).emit('notification', {
                    type: 'CRITICAL_STOCK',
                    title: 'Kritik Stok Uyarısı',
                    body: `${item.name} stok seviyesi kritik düzeyde (${item.currentAmount} ${item.unit}).`
                });
            }
            catch (e) {
                console.error('Bildirim gönderilemedi:', e);
            }
        }
        res.json({ success: true, message: 'Güncellendi', data: item });
    }
    catch (error) {
        console.error('Stok güncellenirken hata:', error);
        res.status(500).json({ success: false, error: 'Stok güncellenemedi.' });
    }
}
export async function deleteStockItem(req, res) {
    try {
        const businessId = req.user?.businessId;
        const role = req.user?.role;
        const id = String(req.params.id);
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
            return;
        }
        await prisma.stockItem.updateMany({
            where: { id, businessId },
            data: { isActive: false },
        });
        res.json({ success: true, message: 'Silindi' });
    }
    catch (error) {
        console.error('Stok silinirken hata:', error);
        res.status(500).json({ success: false, error: 'Stok silinemedi.' });
    }
}
