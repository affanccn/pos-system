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

export async function getProfitabilityReport(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { startDate, endDate } = req.query as { startDate?: string; endDate?: string };

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const start = startDate ? getLogicalDayBounds(startDate).startOfDay : getLogicalDayBounds().startOfDay;
    const end = endDate ? getLogicalDayBounds(endDate).endOfDay : getLogicalDayBounds().endOfDay;

    // Tüm ürünleri reçete ve kategori bilgisiyle getir
    const products = await prisma.product.findMany({
      where: { businessId },
      include: {
        category: true,
        recipeItems: {
          include: { stockItem: true },
        },
      },
    });

    // Satışları getir (sadece geçerli durumlar)
    const orderItems = await prisma.orderItem.findMany({
      where: {
        order: {
          businessId,
          createdAt: { gte: start, lte: end },
        },
        status: { notIn: ['CANCELLED', 'VOID'] },
      },
      select: {
        productId: true,
        productNameSnapshot: true,
        unitPriceCents: true,
        quantity: true,
        totalPriceCents: true,
        status: true,
      },
    });

    // Ürün bazlı satış toplam
    const salesMap = new Map<string, { qty: number; revenueCents: number; complimentaryQty: number; returnedQty: number }>();
    for (const item of orderItems) {
      const existing = salesMap.get(item.productId) || { qty: 0, revenueCents: 0, complimentaryQty: 0, returnedQty: 0 };
      if (item.status === 'COMPLIMENTARY') {
        existing.complimentaryQty += item.quantity;
        existing.qty += item.quantity; // ikram da malzeme tüketir
      } else if (item.status === 'RETURNED') {
        existing.returnedQty += item.quantity;
      } else {
        existing.qty += item.quantity;
        existing.revenueCents += item.totalPriceCents;
      }
      salesMap.set(item.productId, existing);
    }

    // Ürün bazlı kârlılık hesapla
    interface ProductProfit {
      productId: string;
      productName: string;
      categoryName: string;
      priceCents: number;
      recipeCostCents: number;
      totalSoldQty: number;
      totalRevenueCents: number;
      totalCostCents: number;
      grossProfitCents: number;
      grossMarginPercent: number;
      complimentaryQty: number;
      returnedQty: number;
    }

    const productProfits: ProductProfit[] = [];

    for (const product of products) {
      // Reçeteden birim maliyet hesapla
      let recipeCostCents = product.costCents; // Varsayılan: product.costCents

      if (product.recipeItems.length > 0) {
        recipeCostCents = 0;
        for (const ri of product.recipeItems) {
          const rawCost = ri.stockItem.unitCostCents * ri.quantity;
          const wasteFactor = 1 + ri.wastePercentage / 100;
          recipeCostCents += Math.round(rawCost * wasteFactor);
        }
      }

      const sales = salesMap.get(product.id);
      const soldQty = sales?.qty ?? 0;
      const revenueCents = sales?.revenueCents ?? 0;
      const totalCostCents = recipeCostCents * soldQty;
      const grossProfitCents = revenueCents - totalCostCents;
      const grossMarginPercent = revenueCents > 0 ? (grossProfitCents / revenueCents) * 100 : 0;

      productProfits.push({
        productId: product.id,
        productName: product.name,
        categoryName: product.category?.name ?? 'Diğer',
        priceCents: product.priceCents,
        recipeCostCents,
        totalSoldQty: soldQty,
        totalRevenueCents: revenueCents,
        totalCostCents,
        grossProfitCents,
        grossMarginPercent: Math.round(grossMarginPercent * 10) / 10,
        complimentaryQty: sales?.complimentaryQty ?? 0,
        returnedQty: sales?.returnedQty ?? 0,
      });
    }

    // En kârlı ürünler (brüt kâra göre sıralı)
    const byProfit = [...productProfits].sort((a, b) => b.grossProfitCents - a.grossProfitCents);

    // En düşük marjlı ürünler
    const byLowMargin = [...productProfits]
      .filter((p) => p.totalSoldQty > 0)
      .sort((a, b) => a.grossMarginPercent - b.grossMarginPercent);

    // Kategori bazlı kârlılık
    const categoryMap = new Map<string, { revenueCents: number; costCents: number; qty: number }>();
    for (const p of productProfits) {
      const existing = categoryMap.get(p.categoryName) || { revenueCents: 0, costCents: 0, qty: 0 };
      existing.revenueCents += p.totalRevenueCents;
      existing.costCents += p.totalCostCents;
      existing.qty += p.totalSoldQty;
      categoryMap.set(p.categoryName, existing);
    }

    const categoryProfits = Array.from(categoryMap.entries())
      .map(([name, data]) => {
        const profit = data.revenueCents - data.costCents;
        const margin = data.revenueCents > 0 ? (profit / data.revenueCents) * 100 : 0;
        return {
          categoryName: name,
          totalRevenueCents: data.revenueCents,
          totalCostCents: data.costCents,
          grossProfitCents: profit,
          grossMarginPercent: Math.round(margin * 10) / 10,
          totalQty: data.qty,
        };
      })
      .sort((a, b) => b.grossProfitCents - a.grossProfitCents);

    // Genel toplamlar
    const totalRevenue = productProfits.reduce((s, p) => s + p.totalRevenueCents, 0);
    const totalCost = productProfits.reduce((s, p) => s + p.totalCostCents, 0);
    const totalProfit = totalRevenue - totalCost;
    const overallMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;

    res.json({
      success: true,
      data: {
        summary: {
          totalRevenueCents: totalRevenue,
          totalCostCents: totalCost,
          totalProfitCents: totalProfit,
          overallMarginPercent: Math.round(overallMargin * 10) / 10,
          productCount: products.length,
          soldProductCount: productProfits.filter((p) => p.totalSoldQty > 0).length,
        },
        products: byProfit,
        lowMarginProducts: byLowMargin.slice(0, 10),
        categoryProfits,
      },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Karlilik raporu olusturulamadi.' });
  }
}
