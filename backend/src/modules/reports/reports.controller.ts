import { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';

function getLogicalDayBounds(dateParam?: string) {
  const targetDate = dateParam ? new Date(dateParam) : new Date();
  
  if (targetDate.getHours() < 5) {
    targetDate.setDate(targetDate.getDate() - 1);
  }

  const startOfDay = new Date(targetDate);
  startOfDay.setHours(5, 0, 0, 0);

  const endOfDay = new Date(targetDate);
  endOfDay.setDate(endOfDay.getDate() + 1);
  endOfDay.setHours(4, 59, 59, 999);

  return { startOfDay, endOfDay };
}

export async function getDailyReport(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { date } = req.query as { date?: string };

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const { startOfDay, endOfDay } = getLogicalDayBounds(date);

    const payments = await prisma.payment.findMany({
      where: {
        businessId,
        createdAt: { gte: startOfDay, lte: endOfDay },
      },
      include: { cashier: { select: { fullName: true } } },
    });

    let totalRevenueCents = 0;
    let cashTotalCents = 0;
    let cardTotalCents = 0;

    for (const p of payments) {
      totalRevenueCents += p.amountCents;
      if (p.method === 'CASH') cashTotalCents += p.amountCents;
      else if (p.method === 'CARD') cardTotalCents += p.amountCents;
      else if (p.method === 'MIXED') {
        cashTotalCents += p.cashAmountCents;
        cardTotalCents += p.cardAmountCents;
      }
    }

    const completedOrdersCount = await prisma.order.count({
      where: { businessId, status: 'PAID', updatedAt: { gte: startOfDay, lte: endOfDay } },
    });

    const orderItems = await prisma.orderItem.findMany({
      where: {
        order: { businessId, createdAt: { gte: startOfDay, lte: endOfDay } },
        status: { not: 'CANCELLED' },
      },
      select: { productNameSnapshot: true, quantity: true, totalPriceCents: true },
    });

    const productSalesMap = new Map<string, { quantity: number; revenueCents: number }>();
    for (const item of orderItems) {
      const existing = productSalesMap.get(item.productNameSnapshot) || { quantity: 0, revenueCents: 0 };
      productSalesMap.set(item.productNameSnapshot, {
        quantity: existing.quantity + item.quantity,
        revenueCents: existing.revenueCents + item.totalPriceCents,
      });
    }

    const topSellingProducts = Array.from(productSalesMap.entries())
      .map(([name, data]) => ({ productName: name, quantity: data.quantity, revenueCents: data.revenueCents }))
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
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Rapor olusturulamadi.' });
  }
}

export async function getAdvancedReport(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { startDate, endDate } = req.query as { startDate?: string; endDate?: string };

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    // Yalnizca belirtilen araliktaki PAID orderlar ve tum orderlar
    const start = startDate ? getLogicalDayBounds(startDate).startOfDay : getLogicalDayBounds().startOfDay;
    const end = endDate ? getLogicalDayBounds(endDate).endOfDay : getLogicalDayBounds().endOfDay;
    
    // Yalnizca belirtilen araliktaki PAID orderlar ve tum orderlar
    const orders = await prisma.order.findMany({
      where: {
        businessId,
        createdAt: { gte: start, lte: end },
      },
      include: {
        table: { select: { name: true } },
        waiter: { select: { fullName: true } },
        items: {
          include: {
            product: { include: { category: true } }
          }
        },
        payments: true
      }
    });

    let totalRevenue = 0; // Toplam SATIŞ (Ödenenler)
    let netSales = 0;
    let cash = 0;
    let card = 0;
    let discount = 0;
    let complimentary = 0;
    let refund = 0;

    let completedOrders = 0;
    let totalOrderTimeMs = 0;
    const peakHoursMap = new Map<number, number>();

    const productMap = new Map<string, { qty: number, rev: number }>();
    const categoryMap = new Map<string, { qty: number, rev: number }>();
    const waiterMap = new Map<string, { orders: number, rev: number }>();
    const tableMap = new Map<string, { orders: number, rev: number }>();

    for (const o of orders) {
      // Saat bazinda yogunluk
      const hour = o.createdAt.getHours();
      peakHoursMap.set(hour, (peakHoursMap.get(hour) || 0) + 1);

      if (o.status === 'PAID') {
        completedOrders++;
        totalOrderTimeMs += (o.updatedAt.getTime() - o.createdAt.getTime());
      }

      discount += o.discountAmountCents;
      
      const waiterName = o.waiter.fullName;
      const waiterData = waiterMap.get(waiterName) || { orders: 0, rev: 0 };
      waiterData.orders += 1;
      waiterData.rev += o.totalAmountCents;
      waiterMap.set(waiterName, waiterData);

      const tableName = o.table?.name || 'Bilinmeyen Masa';
      const tableData = tableMap.get(tableName) || { orders: 0, rev: 0 };
      tableData.orders += 1;
      tableData.rev += o.totalAmountCents;
      tableMap.set(tableName, tableData);

      for (const p of o.payments) {
        totalRevenue += p.amountCents;
        netSales += p.amountCents; // Basitlestirilmis net satis hesaplamasi
        if (p.method === 'CASH') cash += p.amountCents;
        else if (p.method === 'CARD') card += p.amountCents;
        else if (p.method === 'MIXED') {
          cash += p.cashAmountCents;
          card += p.cardAmountCents;
        }
      }

      for (const item of o.items) {
        if (item.status === 'COMPLIMENTARY') {
          complimentary += item.unitPriceCents * item.quantity;
        } else if (item.status === 'RETURNED') {
          refund += item.totalPriceCents;
        } else if (item.status !== 'CANCELLED' && item.status !== 'VOID') {
          const pName = item.productNameSnapshot;
          const cName = item.product?.category?.name || 'Diger';

          const pData = productMap.get(pName) || { qty: 0, rev: 0 };
          pData.qty += item.quantity;
          pData.rev += item.totalPriceCents;
          productMap.set(pName, pData);

          const cData = categoryMap.get(cName) || { qty: 0, rev: 0 };
          cData.qty += item.quantity;
          cData.rev += item.totalPriceCents;
          categoryMap.set(cName, cData);
          
          discount += item.discountAmountCents;
        }
      }
    }

    const productArr = Array.from(productMap.entries()).map(([name, d]) => ({ name, qty: d.qty, rev: d.rev })).sort((a,b) => b.qty - a.qty);
    const bestSellers = productArr.slice(0, 5);
    
    const categorySales = Array.from(categoryMap.entries()).map(([name, d]) => ({ name, qty: d.qty, rev: d.rev })).sort((a,b) => b.rev - a.rev);
    const waiterSales = Array.from(waiterMap.entries()).map(([name, d]) => ({ name, orders: d.orders, rev: d.rev })).sort((a,b) => b.rev - a.rev);
    const topTables = Array.from(tableMap.entries()).map(([name, d]) => ({ name, orders: d.orders, rev: d.rev })).sort((a,b) => b.orders - a.orders).slice(0, 5);
    
    const peakHours = Array.from(peakHoursMap.entries()).map(([hour, count]) => ({ hour, count })).sort((a,b) => a.hour - b.hour);
    
    const avgOrderTimeMin = completedOrders > 0 ? (totalOrderTimeMs / completedOrders) / 60000 : 0;
    const avgTicketCents = completedOrders > 0 ? (totalRevenue / completedOrders) : 0;

    res.json({
      success: true,
      data: {
        financials: {
          totalRevenueCents: totalRevenue,
          netSalesCents: netSales,
          cashTotalCents: cash,
          cardTotalCents: card,
          discountCents: discount,
          complimentaryCents: complimentary,
          refundCents: refund,
        },
        products: {
          bestSellers,
          categorySales
        },
        tables: {
          topTables
        },
        staff: {
          waiterSales,
          orderCount: orders.length,
          avgTicketCents
        },
        operations: {
          avgOrderTimeMin,
          avgTableTimeMin: avgOrderTimeMin, // Su anlik ayni
          kitchenPrepTimeMin: avgOrderTimeMin * 0.8, // Yaklasik
          peakHours
        }
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Rapor olusturulamadi.' });
  }
}
