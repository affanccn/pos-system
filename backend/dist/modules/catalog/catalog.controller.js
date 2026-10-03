import { prisma } from '../../config/prisma.js';
// 1. Tüm Kategorileri ve Altlarındaki Ürünleri Getir (Garson & Yönetici)
export async function getCatalog(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'İşletme oturumu bulunamadı.' });
            return;
        }
        const categories = await prisma.category.findMany({
            where: {
                businessId,
                isActive: true,
            },
            orderBy: {
                sortOrder: 'asc',
            },
            include: {
                products: {
                    where: {
                        isActive: true,
                    },
                    orderBy: {
                        createdAt: 'asc',
                    },
                    select: {
                        id: true,
                        name: true,
                        priceCents: true,
                        imageUrl: true,
                        isActive: true,
                    },
                },
            },
        });
        res.json({
            success: true,
            data: categories,
        });
    }
    catch (error) {
        console.error('Katalog getirilirken hata:', error);
        res.status(500).json({ success: false, error: 'Menü kataloğu yüklenemedi.' });
    }
}
// 2. Yeni Kategori Ekle (Sadece OWNER ve MANAGER)
export async function createCategory(req, res) {
    try {
        const businessId = req.user?.businessId;
        const role = req.user?.role;
        const { name, sortOrder } = req.body;
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Kategori ekleme yetkiniz yok.' });
            return;
        }
        if (!name || typeof name !== 'string') {
            res.status(400).json({ success: false, error: 'Geçerli bir kategori adı giriniz.' });
            return;
        }
        const category = await prisma.category.create({
            data: {
                businessId: businessId,
                name: name.trim(),
                sortOrder: sortOrder ? Number(sortOrder) : 0,
            },
        });
        res.status(201).json({
            success: true,
            message: 'Kategori başarıyla oluşturuldu.',
            data: category,
        });
    }
    catch (error) {
        console.error('Kategori eklenirken hata:', error);
        res.status(500).json({ success: false, error: 'Kategori oluşturulamadı.' });
    }
}
// 3. Yeni Ürün Ekle (Sadece OWNER ve MANAGER)
export async function createProduct(req, res) {
    try {
        const businessId = req.user?.businessId;
        const role = req.user?.role;
        const { categoryId, name, priceCents, imageUrl } = req.body;
        if (role !== 'OWNER' && role !== 'MANAGER') {
            res.status(403).json({ success: false, error: 'Ürün ekleme yetkiniz yok.' });
            return;
        }
        if (!categoryId || !name || priceCents === undefined) {
            res.status(400).json({
                success: false,
                error: 'Kategori ID, ürün adı ve kuruş bazlı fiyat zorunludur.',
            });
            return;
        }
        // Kategorinin işletmeye ait olduğunu doğrula (Tenant Guard)
        const category = await prisma.category.findFirst({
            where: { id: categoryId, businessId },
        });
        if (!category) {
            res.status(404).json({ success: false, error: 'Belirtilen kategori bulunamadı.' });
            return;
        }
        const product = await prisma.product.create({
            data: {
                businessId: businessId,
                categoryId,
                name: name.trim(),
                priceCents: Math.round(Number(priceCents)),
                imageUrl: imageUrl ? String(imageUrl).trim() : null,
            },
        });
        res.status(201).json({
            success: true,
            message: 'Ürün başarıyla oluşturuldu.',
            data: product,
        });
    }
    catch (error) {
        console.error('Ürün eklenirken hata:', error);
        res.status(500).json({ success: false, error: 'Ürün oluşturulamadı.' });
    }
}
