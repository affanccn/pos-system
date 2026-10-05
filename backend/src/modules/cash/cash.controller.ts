import { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';
import { createAuditLog } from '../../utils/auditLog.js';

export async function getCashMovements(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    if (!businessId) { res.status(401).json({ success: false }); return; }

    const { startDate, endDate } = req.query as any;

    const where: any = { businessId };
    if (startDate && endDate) {
      where.createdAt = { gte: new Date(startDate), lte: new Date(endDate) };
    }

    const movements = await prisma.cashRegisterMovement.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { fullName: true } } }
    });

    let balance = 0;
    for (const m of movements) {
      if (m.type === 'OPENING' || m.type === 'CASH_IN') balance += m.amountCents;
      else if (m.type === 'CASH_OUT' || m.type === 'EXPENSE' || m.type === 'CLOSING') balance -= m.amountCents;
    }

    res.json({ success: true, data: movements, balanceCents: balance });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Kasa hareketleri yuklenemedi.' });
  }
}

export async function createCashMovement(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const userId = req.user?.userId;
    const role = req.user?.role;
    if (role !== 'OWNER' && role !== 'MANAGER') {
      res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
      return;
    }

    const { type, amountCents, description } = req.body;

    if (!type || !amountCents) {
      res.status(400).json({ success: false, error: 'Tip ve tutar zorunludur.' });
      return;
    }

    const movement = await prisma.cashRegisterMovement.create({
      data: {
        businessId: businessId!,
        userId: userId!,
        type,
        amountCents: Math.round(Number(amountCents)),
        description: description || null,
      },
      include: { user: { select: { fullName: true } } }
    });

    await createAuditLog({
      businessId: businessId!,
      userId: userId!,
      action: 'CASH_MOVEMENT',
      entity: 'CashRegister',
      entityId: movement.id,
      newValue: { type, amountCents, description },
      description: `Kasa hareketi: ${type} - ${amountCents / 100} TL`
    });

    res.status(201).json({ success: true, data: movement });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Kasa hareketi olusturulamadi.' });
  }
}

export async function getDailyCashSummary(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    if (!businessId) { res.status(401).json({ success: false }); return; }

    const { date } = req.query as { date?: string };
    const targetDate = date ? new Date(date) : new Date();
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    const movements = await prisma.cashRegisterMovement.findMany({
      where: { businessId, createdAt: { gte: startOfDay, lte: endOfDay } },
      orderBy: { createdAt: 'asc' },
      include: { user: { select: { fullName: true } } }
    });

    const cashPayments = await prisma.payment.findMany({
      where: {
        businessId,
        createdAt: { gte: startOfDay, lte: endOfDay },
        method: { in: ['CASH', 'MIXED'] }
      }
    });

    let cashFromSales = 0;
    for (const p of cashPayments) {
      if (p.method === 'CASH') cashFromSales += p.amountCents;
      else if (p.method === 'MIXED') cashFromSales += p.cashAmountCents;
    }

    const expenses = await prisma.expense.findMany({
      where: { businessId, expenseDate: { gte: startOfDay, lte: endOfDay } }
    });
    const totalExpenses = expenses.reduce((s, e) => s + e.amountCents, 0);

    let openingAmount = 0;
    let cashIn = 0;
    let cashOut = 0;
    let closingAmount = 0;

    for (const m of movements) {
      if (m.type === 'OPENING') openingAmount += m.amountCents;
      else if (m.type === 'CASH_IN') cashIn += m.amountCents;
      else if (m.type === 'CASH_OUT') cashOut += m.amountCents;
      else if (m.type === 'CLOSING') closingAmount = m.amountCents;
    }

    const expectedCash = openingAmount + cashIn + cashFromSales - cashOut - totalExpenses;
    const difference = closingAmount > 0 ? closingAmount - expectedCash : 0;

    res.json({
      success: true,
      data: {
        date: startOfDay.toISOString().split('T')[0],
        openingAmountCents: openingAmount,
        cashInCents: cashIn,
        cashOutCents: cashOut,
        cashFromSalesCents: cashFromSales,
        totalExpensesCents: totalExpenses,
        expectedCashCents: expectedCash,
        closingAmountCents: closingAmount,
        differenceCents: difference,
        movements,
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Kasa ozeti yuklenemedi.' });
  }
}
