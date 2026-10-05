import { prisma } from '../../config/prisma.js';
function getLogicalDayBounds(dateParam) {
    const targetDate = dateParam ? new Date(dateParam) : new Date();
    if (targetDate.getHours() < 5) {
        targetDate.setDate(targetDate.getDate() - 1);
    }
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(5, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setDate(endOfDay.getDate() + 1);
    endOfDay.setHours(4, 59, 59, 999);
    const reportDate = new Date(targetDate);
    reportDate.setHours(0, 0, 0, 0);
    return { startOfDay, endOfDay, reportDate };
}
export async function previewEndOfDay(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { date } = req.query;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
            return;
        }
        const { startOfDay, endOfDay, reportDate } = getLogicalDayBounds(date);
        const existingReport = await prisma.endOfDayReport.findFirst({
            where: {
                businessId,
                reportDate,
            }
        });
        if (existingReport) {
            res.json({
                success: true,
                data: { ...existingReport, isAlreadyClosed: true }
            });
            return;
        }
        const payments = await prisma.payment.findMany({
            where: { businessId, createdAt: { gte: startOfDay, lte: endOfDay } }
        });
        const orders = await prisma.order.findMany({
            where: {
                businessId,
                OR: [
                    { createdAt: { gte: startOfDay, lte: endOfDay } },
                    { updatedAt: { gte: startOfDay, lte: endOfDay } }
                ]
            },
            include: { items: true }
        });
        let totalSalesCents = 0;
        let cashCents = 0;
        let cardCents = 0;
        for (const p of payments) {
            totalSalesCents += p.amountCents;
            if (p.method === 'CASH')
                cashCents += p.amountCents;
            else if (p.method === 'CARD')
                cardCents += p.amountCents;
            else if (p.method === 'MIXED') {
                cashCents += p.cashAmountCents;
                cardCents += p.cardAmountCents;
            }
        }
        let discountCents = 0;
        let complimentaryCents = 0;
        let returnedCents = 0;
        for (const o of orders) {
            if (o.updatedAt >= startOfDay && o.updatedAt <= endOfDay) {
                discountCents += o.discountAmountCents;
            }
            for (const item of o.items) {
                if (item.updatedAt >= startOfDay && item.updatedAt <= endOfDay) {
                    if (item.status === 'COMPLIMENTARY') {
                        complimentaryCents += item.unitPriceCents * item.quantity;
                    }
                    else if (item.status === 'RETURNED') {
                        returnedCents += item.totalPriceCents;
                    }
                    else if (item.status !== 'CANCELLED' && item.status !== 'VOID') {
                        discountCents += item.discountAmountCents;
                    }
                }
            }
        }
        const expenses = await prisma.expense.findMany({
            where: { businessId, expenseDate: { gte: startOfDay, lte: endOfDay } }
        });
        const expensesCents = expenses.reduce((sum, e) => sum + e.amountCents, 0);
        const cashMovements = await prisma.cashRegisterMovement.findMany({
            where: { businessId, createdAt: { gte: startOfDay, lte: endOfDay } }
        });
        let openingCashCents = 0;
        let cashInCents = 0;
        let cashOutCents = 0;
        for (const cm of cashMovements) {
            if (cm.type === 'OPENING')
                openingCashCents += cm.amountCents;
            else if (cm.type === 'CASH_IN')
                cashInCents += cm.amountCents;
            else if (cm.type === 'CASH_OUT')
                cashOutCents += cm.amountCents;
        }
        const expectedCashCents = openingCashCents + cashCents + cashInCents - (expensesCents + cashOutCents);
        res.json({
            success: true,
            data: {
                isAlreadyClosed: false,
                reportDate,
                totalSalesCents,
                cashCents,
                cardCents,
                discountCents,
                complimentaryCents,
                returnedCents,
                expensesCents,
                openingCashCents,
                expectedCashCents,
                actualCashCents: expectedCashCents,
                differenceCents: 0,
            }
        });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Gun sonu onizlemesi olusturulamadi.' });
    }
}
export async function closeDay(req, res) {
    try {
        const businessId = req.user?.businessId;
        const userId = req.user?.userId;
        if (!businessId || !userId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
            return;
        }
        const reqReportDate = req.body.reportDate;
        const actualCashCents = req.body.actualCashCents;
        const data = req.body.data;
        const { startOfDay, reportDate } = getLogicalDayBounds(reqReportDate);
        const existing = await prisma.endOfDayReport.findFirst({
            where: { businessId, reportDate }
        });
        if (existing) {
            res.status(400).json({ success: false, error: 'Bu gun zaten kapatilmis.' });
            return;
        }
        const differenceCents = actualCashCents - data.expectedCashCents;
        const report = await prisma.$transaction(async (tx) => {
            const newReport = await tx.endOfDayReport.create({
                data: {
                    businessId,
                    closedById: userId,
                    reportDate: reportDate,
                    totalSalesCents: data.totalSalesCents,
                    cashCents: data.cashCents,
                    cardCents: data.cardCents,
                    discountCents: data.discountCents,
                    complimentaryCents: data.complimentaryCents,
                    returnedCents: data.returnedCents,
                    expensesCents: data.expensesCents,
                    openingCashCents: data.openingCashCents,
                    expectedCashCents: data.expectedCashCents,
                    actualCashCents,
                    differenceCents,
                }
            });
            await tx.cashRegisterMovement.create({
                data: {
                    businessId,
                    userId,
                    type: 'CLOSING',
                    amountCents: actualCashCents,
                    description: `Gun sonu kapanisi. Beklenen: ${data.expectedCashCents / 100}, Gerceklesen: ${actualCashCents / 100}, Fark: ${differenceCents / 100}`,
                }
            });
            await tx.auditLog.create({
                data: {
                    businessId,
                    userId,
                    action: 'END_OF_DAY_CLOSE',
                    entity: 'EndOfDayReport',
                    entityId: newReport.id,
                    newValue: { ...newReport },
                    description: 'Kasa kapatildi ve gun sonu (Z Raporu) alindi.'
                }
            });
            return newReport;
        });
        res.json({ success: true, data: report });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Gun sonu kapatilamadi.' });
    }
}
