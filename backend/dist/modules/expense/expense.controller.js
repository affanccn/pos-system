import { prisma } from '../../config/prisma.js';
import { createAuditLog } from '../../utils/auditLog.js';
export async function getExpenses(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false });
            return;
        }
        const { startDate, endDate, category } = req.query;
        const where = { businessId };
        if (startDate && endDate) {
            where.expenseDate = { gte: new Date(startDate), lte: new Date(endDate) };
        }
        if (category)
            where.category = category;
        const expenses = await prisma.expense.findMany({
            where,
            orderBy: { expenseDate: 'desc' },
            include: { user: { select: { fullName: true } } }
        });
        const totalCents = expenses.reduce((sum, e) => sum + e.amountCents, 0);
        res.json({ success: true, data: expenses, totalCents });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Giderler yuklenemedi.' });
    }
}
export async function createExpense(req, res) {
    try {
        const businessId = req.user?.businessId;
        const userId = req.user?.userId;
        const role = req.user?.role;
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
            return;
        }
        const { category, amountCents, description, expenseDate } = req.body;
        const expense = await prisma.expense.create({
            data: {
                businessId: businessId,
                userId: userId,
                category: category || 'OTHER',
                amountCents: Math.round(Number(amountCents)),
                description: description || null,
                expenseDate: expenseDate ? new Date(expenseDate) : new Date(),
            },
            include: { user: { select: { fullName: true } } }
        });
        await createAuditLog({
            businessId: businessId,
            userId: userId,
            action: 'EXPENSE_CREATE',
            entity: 'Expense',
            entityId: expense.id,
            newValue: { category, amountCents, description },
            description: `${expense.user.fullName} ${amountCents / 100} TL gider kaydetti (${category})`
        });
        res.status(201).json({ success: true, data: expense });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ success: false, error: 'Gider olusturulamadi.' });
    }
}
export async function deleteExpense(req, res) {
    try {
        const businessId = req.user?.businessId;
        const userId = req.user?.userId;
        const role = req.user?.role;
        const id = String(req.params.id);
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
            return;
        }
        const expense = await prisma.expense.findFirst({ where: { id, businessId } });
        if (!expense) {
            res.status(404).json({ success: false });
            return;
        }
        await prisma.expense.delete({ where: { id } });
        await createAuditLog({
            businessId: businessId,
            userId: userId,
            action: 'EXPENSE_DELETE',
            entity: 'Expense',
            entityId: id,
            oldValue: { category: expense.category, amountCents: expense.amountCents, description: expense.description },
            description: `Gider silindi: ${expense.amountCents / 100} TL`
        });
        res.json({ success: true });
    }
    catch (error) {
        res.status(500).json({ success: false, error: 'Silinemedi.' });
    }
}
