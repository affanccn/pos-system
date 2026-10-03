import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
// Gün Sonu / Kasa Özeti Raporu
export async function getDailyReport(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { date } = req.query;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        // Tarih aralığı: Verilen tarih (varsayılan bugün 00:00 - 23:59:59)
        const targetDate = date ? new Date(date) : new Date();
        const startOfDay = new Date(targetDate.setHours(0, 0, 0, 0));
        const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));
        // 1. O gün yapılan tüm tahsilatlar
        const payments = await prisma.payment.findMany({
            where: {
                businessId,
                createdAt: {
                    gte: startOfDay,
                    lte: endOfDay,
                },
            },
            include: {
                cashier: { select: { fullName: true } },
            },
        });
        let totalRevenueCents = 0;
        let cashTotalCents = 0;
        let cardTotalCents = 0;
        for (const p of payments) {
            totalRevenueCents += p.amountCents;
            if (p.method === 'CASH') {
                cashTotalCents += p.amountCents;
            }
            else if (p.method === 'CARD') {
                cardTotalCents += p.amountCents;
            }
            else if (p.method === 'MIXED') {
                cashTotalCents += p.cashAmountCents;
                cardTotalCents += p.cardAmountCents;
            }
        }
        // 2. O gün tamamlanan (ödenen) sipariş sayısı
        const completedOrdersCount = await prisma.order.count({
            where: {
                businessId,
                status: 'PAID',
                updatedAt: {
                    gte: startOfDay,
                    lte: endOfDay,
                },
            },
        });
        // 3. Günün en çok satan ürünleri
        const orderItems = await prisma.orderItem.findMany({
            where: {
                order: {
                    businessId,
                    createdAt: {
                        gte: startOfDay,
                        lte: endOfDay,
                    },
                },
                status: { not: 'CANCELLED' },
            },
            select: {
                productNameSnapshot: true,
                quantity: true,
                totalPriceCents: true,
            },
        });
        const productSalesMap = new Map();
        for (const item of orderItems) {
            const existing = productSalesMap.get(item.productNameSnapshot) || { quantity: 0, revenueCents: 0 };
            productSalesMap.set(item.productNameSnapshot, {
                quantity: existing.quantity + item.quantity,
                revenueCents: existing.revenueCents + item.totalPriceCents,
            });
        }
        const topSellingProducts = Array.from(productSalesMap.entries())
            .map(([name, data]) => ({
            productName: name,
            quantity: data.quantity,
            revenueCents: data.revenueCents,
        }))
            .sort((a, b) => b.quantity - a.quantity)
            .slice(0, 5);
        res.json({
            success: true,
            data: {
                date: startOfDay.toISOString().split('T')[0],
                totalRevenueCents,
                cashTotalCents,
                cardTotalCents,
                paymentCount: payments.length,
                completedOrdersCount,
                topSellingProducts,
            },
        });
    }
    catch (error) {
        console.error('Gün sonu raporu alınırken hata:', error);
        res.status(500).json({ success: false, error: 'Rapor oluşturulamadı.' });
    }
}
