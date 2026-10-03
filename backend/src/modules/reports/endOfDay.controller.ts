import { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';

export async function previewEndOfDay(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { date } = req.query as { date?: string };

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const targetDate = date ? new Date(date) : new Date();
    const startOfDay = new Date(targetDate.setHours(0, 0, 0, 0));
    const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));

    // Zaten gün kapanmış mı kontrol et
    const existingReport = await prisma.endOfDayReport.findFirst({
      where: {
        businessId,
        reportDate: startOfDay,
      }
    });

    if (existingReport) {
      res.json({
        success: true,
        data: { ...existingReport, isAlreadyClosed: true }
      });
      return;
    }

    // --- Satış ve Ödemeler ---
    const orders = await prisma.order.findMany({
      where: { businessId, createdAt: { gte: startOfDay, lte: endOfDay } },
      include: {
        items: true,
        payments: true
      }
    });

    let totalSalesCents = 0;
    let cashCents = 0;
    let cardCents = 0;
    let discountCents = 0;
    let complimentaryCents = 0;
    let returnedCents = 0;

    for (const o of orders) {
      discountCents += o.discountAmountCents;
      
      for (const p of o.payments) {
        totalSalesCents += p.amountCents;
        if (p.method === 'CASH') cashCents += p.amountCents;
        else if (p.method === 'CARD') cardCents += p.amountCents;
        else if (p.method === 'MIXED') {
          cashCents += p.cashAmountCents;
          cardCents += p.cardAmountCents;
        }
      }

      for (const item of o.items) {
        if (item.status === 'COMPLIMENTARY') {
          complimentaryCents += item.unitPriceCents * item.quantity;
        } else if (item.status === 'RETURNED') {
          returnedCents += item.totalPriceCents;
        } else if (item.status !== 'CANCELLED' && item.status !== 'VOID') {
          discountCents += item.discountAmountCents;
        }
      }
    }

    // --- Kasa Hareketleri ve Giderler ---
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
      if (cm.type === 'OPENING') openingCashCents += cm.amountCents;
      else if (cm.type === 'CASH_IN') cashInCents += cm.amountCents;
      else if (cm.type === 'CASH_OUT') cashOutCents += cm.amountCents;
      // EXPENSE tipleri expenses içerisinde var
    }

    // Beklenen kasa = (Açılış) + (Nakit Satışlar) + (Nakit Girişleri) - (Giderler + Nakit Çıkışları)
    const expectedCashCents = openingCashCents + cashCents + cashInCents - (expensesCents + cashOutCents);

    res.json({
      success: true,
      data: {
        isAlreadyClosed: false,
        reportDate: startOfDay,
        totalSalesCents,
        cashCents,
        cardCents,
        discountCents,
        complimentaryCents,
        returnedCents,
        expensesCents,
        openingCashCents,
        expectedCashCents,
        actualCashCents: expectedCashCents, // Kullanıcı girecek
        differenceCents: 0,
      }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Gun sonu onizlemesi olusturulamadi.' });
  }
}

export async function closeDay(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const userId = req.user?.userId;
    
    if (!businessId || !userId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const { reportDate, actualCashCents, data } = req.body;
    const startOfDay = new Date(new Date(reportDate).setHours(0, 0, 0, 0));

    // Kontrol et, zaten kapanmış mı?
    const existing = await prisma.endOfDayReport.findFirst({
      where: { businessId, reportDate: startOfDay }
    });

    if (existing) {
      res.status(400).json({ success: false, error: 'Bu gun zaten kapatilmis.' });
      return;
    }

    const differenceCents = actualCashCents - data.expectedCashCents;

    // Transaction kullanarak Raporu Kaydet, Audit Log yaz ve Kasa Hareketi ekle
    const report = await prisma.$transaction(async (tx) => {
      // 1. Z Raporu oluştur
      const newReport = await tx.endOfDayReport.create({
        data: {
          businessId,
          closedById: userId,
          reportDate: startOfDay,
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

      // 2. Kasa kapanış hareketi yaz
      await tx.cashRegisterMovement.create({
        data: {
          businessId,
          userId,
          type: 'CLOSING',
          amountCents: actualCashCents,
          description: `Gun sonu kapanisi. Beklenen: ${data.expectedCashCents / 100}, Gerceklesen: ${actualCashCents / 100}, Fark: ${differenceCents / 100}`,
        }
      });

      // 3. Audit log yaz
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
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Gun sonu kapatilamadi.' });
  }
}
