import type { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';
import { createAuditLog } from '../../utils/auditLog.js';

export async function getCatalog(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadi.' });
      return;
    }

    const categories = await prisma.category.findMany({
      where: { businessId, isActive: true },
      orderBy: { sortOrder: 'asc' },
      include: {
        products: {
          where: { isActive: true },
          orderBy: { createdAt: 'asc' },
          select: {
            id: true,
            name: true,
            priceCents: true,
            description: true,
            taxRate: true,
            costCents: true,
            stationType: true,
            imageUrl: true,
            isActive: true,
            recipeItems: {
              include: { stockItem: true }
            },
            modifierGroups: {
              where: { isActive: true },
              orderBy: { sortOrder: 'asc' },
              include: {
                items: {
                  where: { isActive: true },
                  orderBy: { sortOrder: 'asc' },
                },
              },
            },
          },
        },
      },
    });

    res.json({ success: true, data: categories });
  } catch (error) {
    console.error('Katalog getirilirken hata:', error);
    res.status(500).json({ success: false, error: 'Yuklenemedi.' });
  }
}

export async function createCategory(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const role = req.user?.role;
    const { name, sortOrder } = req.body;

    if (role !== 'OWNER' && role !== 'MANAGER') {
      res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
      return;
    }

    const category = await prisma.category.create({
      data: {
        businessId: businessId!,
        name: name.trim(),
        sortOrder: sortOrder ? Number(sortOrder) : 0,
      },
    });
    res.status(201).json({ success: true, data: category });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Hata.' });
  }
}

export async function createProduct(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const role = req.user?.role;
    const { categoryId, name, priceCents, imageUrl, description, taxRate, costCents, stationType, recipeItems } = req.body;

    if (role !== 'OWNER' && role !== 'MANAGER') {
      res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
      return;
    }

    const category = await prisma.category.findFirst({ where: { id: categoryId, businessId } });
    if (!category) {
      res.status(404).json({ success: false, error: 'Kategori bulunamadi.' });
      return;
    }

    const product = await prisma.product.create({
      data: {
        businessId: businessId!,
        categoryId,
        name: name.trim(),
        priceCents: Math.round(Number(priceCents)),
        description: description ? String(description).trim() : null,
        taxRate: taxRate ? Number(taxRate) : 0,
        costCents: costCents ? Number(costCents) : 0,
        stationType: stationType || null,
        imageUrl: imageUrl ? String(imageUrl).trim() : null,
        recipeItems: recipeItems && Array.isArray(recipeItems) ? {
          create: recipeItems.map((ri: any) => ({
            stockItemId: ri.stockItemId,
            quantity: Number(ri.quantity),
            wastePercentage: Number(ri.wastePercentage || 0),
            costCents: Number(ri.costCents || 0)
          }))
        } : undefined
      },
      include: { recipeItems: true }
    });
    res.status(201).json({ success: true, data: product });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Hata.' });
  }
}

export async function updateProduct(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const role = req.user?.role;
    const id = String(req.params.id);
    if (role !== 'OWNER' && role !== 'MANAGER') {
      res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
      return;
    }

    const { categoryId, name, priceCents, imageUrl, description, taxRate, costCents, stationType, isActive, recipeItems } = req.body;

    const oldProduct = await prisma.product.findUnique({ where: { id } });

    await prisma.$transaction(async (tx) => {
      await tx.product.update({
        where: { id, businessId },
        data: {
          ...(categoryId && { categoryId }),
          ...(name && { name: name.trim() }),
          ...(priceCents !== undefined && { priceCents: Math.round(Number(priceCents)) }),
          ...(description !== undefined && { description: description ? String(description).trim() : null }),
          ...(taxRate !== undefined && { taxRate: Number(taxRate) }),
          ...(costCents !== undefined && { costCents: Number(costCents) }),
          ...(stationType !== undefined && { stationType: stationType || null }),
          ...(imageUrl !== undefined && { imageUrl: imageUrl ? String(imageUrl).trim() : null }),
          ...(isActive !== undefined && { isActive: Boolean(isActive) }),
        }
      });

      if (priceCents !== undefined && oldProduct && Math.round(Number(priceCents)) !== oldProduct.priceCents) {
        await createAuditLog({
          businessId: businessId!,
          userId: (req.user as any)?.userId || (req.user as any)?.id,
          action: 'PRICE_CHANGE',
          entity: 'Product',
          entityId: id,
          oldValue: { priceCents: oldProduct.priceCents },
          newValue: { priceCents: Math.round(Number(priceCents)) },
          description: `Ürün (${oldProduct.name}) fiyatı değiştirildi`
        });
      }

      if (recipeItems && Array.isArray(recipeItems)) {
        await tx.productRecipeItem.deleteMany({ where: { productId: id } });
        if (recipeItems.length > 0) {
          await tx.productRecipeItem.createMany({
            data: recipeItems.map((ri: any) => ({
              productId: id,
              stockItemId: ri.stockItemId,
              quantity: Number(ri.quantity),
              wastePercentage: Number(ri.wastePercentage || 0),
              costCents: Number(ri.costCents || 0)
            }))
          });
        }
      }
    });

    res.json({ success: true, message: 'Guncellendi' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Guncellenemedi.' });
  }
}

export async function deleteProduct(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const role = req.user?.role;
    const id = String(req.params.id);
    if (role !== 'OWNER' && role !== 'MANAGER') {
      res.status(403).json({ success: false, error: 'Yetkiniz yok.' });
      return;
    }
    await prisma.product.updateMany({
      where: { id, businessId },
      data: { isActive: false },
    });

    await createAuditLog({
      businessId: businessId!,
      userId: (req.user as any)?.userId || (req.user as any)?.id,
      action: 'PRODUCT_DELETE',
      entity: 'Product',
      entityId: id,
      description: 'Ürün silindi (pasife çekildi)'
    });

    res.json({ success: true, message: 'Silindi' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Silinemedi.' });
  }
}

export async function createModifierGroup(req: Request, res: Response): Promise<void> {
  try {
    const { productId, name, isRequired, minSelect, maxSelect, sortOrder } = req.body;
    const group = await prisma.productModifierGroup.create({
      data: {
        productId, name: name.trim(), isRequired: isRequired ?? false, minSelect: minSelect ?? 0, maxSelect: maxSelect ?? 1, sortOrder: sortOrder ?? 0,
      },
    });
    res.status(201).json({ success: true, data: group });
  } catch (error) { res.status(500).json({ success: false, error: 'Hata.' }); }
}

export async function createModifierItem(req: Request, res: Response): Promise<void> {
  try {
    const { modifierGroupId, name, priceCents, sortOrder } = req.body;
    const item = await prisma.productModifierItem.create({
      data: { modifierGroupId, name: name.trim(), priceCents: priceCents ?? 0, sortOrder: sortOrder ?? 0 },
    });
    res.status(201).json({ success: true, data: item });
  } catch (error) { res.status(500).json({ success: false, error: 'Hata.' }); }
}

export async function deleteModifierGroup(req: Request, res: Response): Promise<void> {
  try {
    await prisma.productModifierGroup.delete({ where: { id: String(req.params.id) } });
    res.json({ success: true });
  } catch (error) { res.status(500).json({ success: false }); }
}

export async function deleteModifierItem(req: Request, res: Response): Promise<void> {
  try {
    await prisma.productModifierItem.delete({ where: { id: String(req.params.id) } });
    res.json({ success: true });
  } catch (error) { res.status(500).json({ success: false }); }
}
