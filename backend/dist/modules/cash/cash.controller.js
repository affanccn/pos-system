import { prisma } from '../../config/prisma.js';
import { createAuditLog } from '../../utils/auditLog.js';
import { getIO, emitToWindowsKasa } from '../../realtime/socket.js';
export async function getCashMovements(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false });
            return;
        }
        const { startDate, endDate } = req.query;
        const where = { businessId };
        if (startDate && endDate) {
            where.createdAt = { gte: new Date(startDate), lte: new Date(endDate) };
        }
        const movements = await prisma.cashRegisterMovement.findMany({
            where,
            orderBy: { createdAt: 'desc' },
            include: { user: { select: { fullName: true } } },
        });
        let balance = 0;
        for (const m of movements) {
            if (m.type === 'OPENING' || m.type === 'CASH_IN')
                balance += m.amountCents;
            else if (m.type === 'CASH_OUT' || m.type === 'EXPENSE' || m.type === 'CLOSING')
                balance -= m.amountCents;
        }
        const business = await prisma.business.findUnique({
            where: { id: businessId },
            select: { isDayOpen: true, isWindowsOnline: true, dayOpenedAt: true },
        });
        res.json({
            success: true,
            data: movements,
            balanceCents: balance,
            kasaStatus: business,
        });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Kasa hareketleri yuklenemedi.' });
    }
}
export async function createCashMovement(req, res) {
    try {
        const businessId = req.user?.businessId;
        const userId = req.user?.userId;
        const role = req.user?.role;
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
            return;
        }
        const { type, amountCents, description } = req.body;
        if (!type || amountCents === undefined) {
            res.status(400).json({ success: false, error: 'Tip ve tutar zorunludur.' });
            return;
        }
        // EĞER GÜN SONU (CLOSING) ALINIYORSA AÇIK MASA VAR MI KONTROL ET!
        if (type === 'CLOSING') {
            const occupiedTablesCount = await prisma.restaurantTable.count({
                where: { businessId: businessId, status: { not: 'AVAILABLE' }, isActive: true },
            });
            if (occupiedTablesCount > 0) {
                res.status(400).json({
                    success: false,
                    error: `Şu anda açık olan ${occupiedTablesCount} masa var! Gün sonu almadan önce tüm masaların hesabını kapatmalısınız.`,
                });
                return;
            }
        }
        const movement = await prisma.cashRegisterMovement.create({
            data: {
                businessId: businessId,
                userId: userId,
                type,
                amountCents: Math.round(Number(amountCents)),
                description: description || null,
            },
            include: { user: { select: { fullName: true } } },
        });
        const io = getIO();
        // 1. KASA AÇILIŞI (OPENING) -> GÜNÜ BAŞLAT VE GARSON TELEFONLARINI AÇ!
        if (type === 'OPENING') {
            const updatedBiz = await prisma.business.update({
                where: { id: businessId },
                data: { isDayOpen: true, dayOpenedAt: new Date() },
            });
            io.to(`business:${businessId}`).emit('kasa_status_changed', {
                isWindowsOnline: updatedBiz.isWindowsOnline,
                isDayOpen: true,
                canWaiterWork: updatedBiz.isWindowsOnline && true,
            });
        }
        // 2. KASA KAPANIŞI / GÜN SONU (CLOSING) -> GÜNÜ KAPAT, TELEFONLARI KİLİTLE VE Z RAPORU YAZDIR!
        if (type === 'CLOSING') {
            const updatedBiz = await prisma.business.update({
                where: { id: businessId },
                data: { isDayOpen: false, dayOpenedAt: null },
            });
            io.to(`business:${businessId}`).emit('kasa_status_changed', {
                isWindowsOnline: updatedBiz.isWindowsOnline,
                isDayOpen: false,
                canWaiterWork: false,
            });
            // Bar/Kasa yazıcısına Z Raporu Fişi gönder
            const cashierPrinter = await prisma.printer.findFirst({
                where: { businessId: businessId, isActive: true, isCashier: true },
            });
            if (cashierPrinter) {
                emitToWindowsKasa(businessId, 'print:end_of_day_report', {
                    printer: cashierPrinter,
                    closedBy: req.user?.fullName || 'Yönetici',
                    closingCashCents: movement.amountCents,
                    closedAt: new Date().toISOString(),
                });
            }
        }
        await createAuditLog({
            businessId: businessId,
            userId: userId,
            action: 'CASH_MOVEMENT',
            entity: 'CashRegister',
            entityId: movement.id,
            newValue: { type, amountCents, description },
            description: `Kasa hareketi: ${type} - ${amountCents / 100} TL`,
        });
        res.status(201).json({ success: true, data: movement });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Kasa hareketi olusturulamadi.' });
    }
}
export async function getDailyCashSummary(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false });
            return;
        }
        const { date } = req.query;
        const targetDate = date ? new Date(date) : new Date();
        const startOfDay = new Date(targetDate);
        startOfDay.setHours(0, 0, 0, 0);
        const endOfDay = new Date(targetDate);
        endOfDay.setHours(23, 59, 59, 999);
        const movements = await prisma.cashRegisterMovement.findMany({
            where: { businessId, createdAt: { gte: startOfDay, lte: endOfDay } },
            orderBy: { createdAt: 'asc' },
            include: { user: { select: { fullName: true } } },
        });
        const cashPayments = await prisma.payment.findMany({
            where: {
                businessId,
                createdAt: { gte: startOfDay, lte: endOfDay },
                method: { in: ['CASH', 'MIXED'] },
            },
        });
        const cardPayments = await prisma.payment.findMany({
            where: {
                businessId,
                createdAt: { gte: startOfDay, lte: endOfDay },
                method: { in: ['CARD', 'MIXED'] },
            },
        });
        let cashFromSales = 0;
        for (const p of cashPayments) {
            if (p.method === 'CASH')
                cashFromSales += p.amountCents;
            else if (p.method === 'MIXED')
                cashFromSales += p.cashAmountCents;
        }
        let cardFromSales = 0;
        for (const p of cardPayments) {
            if (p.method === 'CARD')
                cardFromSales += p.amountCents;
            else if (p.method === 'MIXED')
                cardFromSales += p.cardAmountCents;
        }
        const expenses = await prisma.expense.findMany({
            where: { businessId, expenseDate: { gte: startOfDay, lte: endOfDay } },
        });
        const totalExpenses = expenses.reduce((s, e) => s + e.amountCents, 0);
        let openingAmount = 0;
        let cashIn = 0;
        let cashOut = 0;
        let closingAmount = 0;
        for (const m of movements) {
            if (m.type === 'OPENING')
                openingAmount += m.amountCents;
            else if (m.type === 'CASH_IN')
                cashIn += m.amountCents;
            else if (m.type === 'CASH_OUT')
                cashOut += m.amountCents;
            else if (m.type === 'CLOSING')
                closingAmount = m.amountCents;
        }
        const expectedCash = openingAmount + cashIn + cashFromSales - cashOut - totalExpenses;
        const difference = closingAmount > 0 ? closingAmount - expectedCash : 0;
        const business = await prisma.business.findUnique({
            where: { id: businessId },
            select: { isDayOpen: true, isWindowsOnline: true, dayOpenedAt: true },
        });
        res.json({
            success: true,
            data: {
                date: startOfDay.toISOString().split('T')[0],
                isDayOpen: business?.isDayOpen ?? false,
                isWindowsOnline: business?.isWindowsOnline ?? false,
                dayOpenedAt: business?.dayOpenedAt,
                openingAmountCents: openingAmount,
                cashInCents: cashIn,
                cashOutCents: cashOut,
                cashFromSalesCents: cashFromSales,
                cardFromSalesCents: cardFromSales,
                totalSalesCents: cashFromSales + cardFromSales,
                totalExpensesCents: totalExpenses,
                expectedCashCents: expectedCash,
                closingAmountCents: closingAmount,
                differenceCents: difference,
                movements,
            },
        });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Kasa ozeti yuklenemedi.' });
    }
}
