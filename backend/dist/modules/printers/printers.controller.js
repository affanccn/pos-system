import { prisma } from '../../config/prisma.js';
import { emitToWindowsKasa } from '../../realtime/socket.js';
export async function getPrinters(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        const printers = await prisma.printer.findMany({
            where: { businessId, isActive: true },
            include: {
                categories: {
                    where: { isActive: true },
                    select: { id: true, name: true, stationType: true },
                },
            },
            orderBy: { createdAt: 'asc' },
        });
        res.json({ success: true, data: printers });
    }
    catch (error) {
        console.error('Yazıcılar listelenirken hata:', error);
        res.status(500).json({ success: false, error: 'Yazıcılar getirilemedi.' });
    }
}
export async function createPrinter(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { name, connectionType, ipAddress, port, stationType, isCashier, categoryIds } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        if (!name || !ipAddress) {
            res.status(400).json({ success: false, error: 'Yazıcı adı ve IP/USB adresi zorunludur.' });
            return;
        }
        // Eğer bu yazıcı "Hesap/Kasa Yazıcısı" (Bar) olarak seçildiyse diğerlerinin isCashier özelliğini kaldır
        if (isCashier) {
            await prisma.printer.updateMany({
                where: { businessId, isCashier: true },
                data: { isCashier: false },
            });
        }
        const printer = await prisma.printer.create({
            data: {
                businessId,
                name: name.trim(),
                connectionType: connectionType || 'ETHERNET',
                ipAddress: ipAddress.trim(),
                port: port ? Number(port) : 9100,
                stationType: stationType,
                isCashier: Boolean(isCashier),
            },
        });
        // Eğer oluşturulurken kategoriler seçildiyse bu yazıcıya bağla
        if (Array.isArray(categoryIds) && categoryIds.length > 0) {
            await prisma.category.updateMany({
                where: { id: { in: categoryIds }, businessId },
                data: { printerId: printer.id },
            });
        }
        const createdWithCategories = await prisma.printer.findUnique({
            where: { id: printer.id },
            include: { categories: { select: { id: true, name: true } } },
        });
        res.status(201).json({ success: true, data: createdWithCategories });
    }
    catch (error) {
        console.error('Yazıcı oluşturulurken hata:', error);
        res.status(500).json({ success: false, error: 'Yazıcı eklenemedi.' });
    }
}
export async function updatePrinter(req, res) {
    try {
        const businessId = req.user?.businessId;
        const id = req.params.id;
        const { name, connectionType, ipAddress, port, stationType, isCashier, isActive, categoryIds } = req.body;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        if (isCashier === true) {
            await prisma.printer.updateMany({
                where: { businessId, isCashier: true, id: { not: id } },
                data: { isCashier: false },
            });
        }
        const printer = await prisma.printer.updateMany({
            where: { id, businessId },
            data: {
                ...(name && { name: name.trim() }),
                ...(connectionType && { connectionType: connectionType }),
                ...(ipAddress && { ipAddress: ipAddress.trim() }),
                ...(port && { port: Number(port) }),
                ...(stationType !== undefined && { stationType: stationType }),
                ...(isCashier !== undefined && { isCashier: Boolean(isCashier) }),
                ...(isActive !== undefined && { isActive: Boolean(isActive) }),
            },
        });
        if (printer.count === 0) {
            res.status(404).json({ success: false, error: 'Yazıcı bulunamadı.' });
            return;
        }
        // Kategori eşleştirmeleri gönderildiyse güncelle
        if (Array.isArray(categoryIds)) {
            await prisma.category.updateMany({
                where: { businessId, printerId: id },
                data: { printerId: null },
            });
            if (categoryIds.length > 0) {
                await prisma.category.updateMany({
                    where: { businessId, id: { in: categoryIds } },
                    data: { printerId: id },
                });
            }
        }
        const updated = await prisma.printer.findUnique({
            where: { id },
            include: { categories: { select: { id: true, name: true } } },
        });
        res.json({ success: true, data: updated });
    }
    catch (error) {
        console.error('Yazıcı güncellenirken hata:', error);
        res.status(500).json({ success: false, error: 'Yazıcı güncellenemedi.' });
    }
}
export async function deletePrinter(req, res) {
    try {
        const businessId = req.user?.businessId;
        const id = req.params.id;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        await prisma.category.updateMany({
            where: { businessId, printerId: id },
            data: { printerId: null },
        });
        await prisma.printer.updateMany({
            where: { id, businessId },
            data: { isActive: false },
        });
        res.json({ success: true, message: 'Yazıcı silindi.' });
    }
    catch (error) {
        console.error('Yazıcı silinirken hata:', error);
        res.status(500).json({ success: false, error: 'Yazıcı silinemedi.' });
    }
}
// KATEGORİ -> YAZICI (BAR / MUTFAK / NARGİLE) TOPLU EŞLEŞTİRME
export async function assignCategoriesToPrinter(req, res) {
    try {
        const businessId = req.user?.businessId;
        const { assignments } = req.body;
        if (!businessId || !Array.isArray(assignments)) {
            res.status(400).json({ success: false, error: 'Geçersiz eşleştirme verisi.' });
            return;
        }
        await prisma.$transaction(assignments.map((item) => prisma.category.updateMany({
            where: { id: item.categoryId, businessId },
            data: { printerId: item.printerId },
        })));
        res.json({ success: true, message: 'Kategori-Yazıcı eşleştirmeleri kaydedildi.' });
    }
    catch (error) {
        console.error('Kategori eşleştirme hatası:', error);
        res.status(500).json({ success: false, error: 'Eşleştirme kaydedilemedi.' });
    }
}
// FİŞ TASARIM STÜDYOSU ŞABLONUNU GETİR
export async function getReceiptTemplate(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        const template = await prisma.receiptTemplate.upsert({
            where: { businessId },
            update: {},
            create: { businessId },
        });
        res.json({ success: true, data: template });
    }
    catch (error) {
        console.error('Fiş şablonu getirilirken hata:', error);
        res.status(500).json({ success: false, error: 'Fiş şablonu yüklenemedi.' });
    }
}
// FİŞ TASARIM STÜDYOSU ŞABLONUNU GÜNCELLE
export async function updateReceiptTemplate(req, res) {
    try {
        const businessId = req.user?.businessId;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        const { headerTitle, headerSubtitle, address, phone, wifiInfo, footerMessage, showLogo, showWaiterName, showTaxDetails, paperWidthMm, orderTableFontSize, orderItemFontSize, highlightNotes, buzzerBeep, } = req.body;
        const template = await prisma.receiptTemplate.upsert({
            where: { businessId },
            update: {
                ...(headerTitle !== undefined && { headerTitle }),
                ...(headerSubtitle !== undefined && { headerSubtitle }),
                ...(address !== undefined && { address }),
                ...(phone !== undefined && { phone }),
                ...(wifiInfo !== undefined && { wifiInfo }),
                ...(footerMessage !== undefined && { footerMessage }),
                ...(showLogo !== undefined && { showLogo: Boolean(showLogo) }),
                ...(showWaiterName !== undefined && { showWaiterName: Boolean(showWaiterName) }),
                ...(showTaxDetails !== undefined && { showTaxDetails: Boolean(showTaxDetails) }),
                ...(paperWidthMm !== undefined && { paperWidthMm: Number(paperWidthMm) }),
                ...(orderTableFontSize !== undefined && { orderTableFontSize }),
                ...(orderItemFontSize !== undefined && { orderItemFontSize }),
                ...(highlightNotes !== undefined && { highlightNotes: Boolean(highlightNotes) }),
                ...(buzzerBeep !== undefined && { buzzerBeep: Boolean(buzzerBeep) }),
            },
            create: {
                businessId,
                headerTitle: headerTitle || 'ARTISAN POS',
                headerSubtitle,
                address,
                phone,
                wifiInfo,
                footerMessage,
            },
        });
        res.json({ success: true, data: template, message: 'Fiş tasarımı kaydedildi.' });
    }
    catch (error) {
        console.error('Fiş şablonu güncellenirken hata:', error);
        res.status(500).json({ success: false, error: 'Fiş tasarımı kaydedilemedi.' });
    }
}
// WINDOWS KASADAN TEST FİŞİ YAZDIR
export async function triggerTestPrint(req, res) {
    try {
        const businessId = req.user?.businessId;
        const id = req.params.id;
        if (!businessId) {
            res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
            return;
        }
        const printer = await prisma.printer.findFirst({ where: { id, businessId } });
        if (!printer) {
            res.status(404).json({ success: false, error: 'Yazıcı bulunamadı.' });
            return;
        }
        const template = await prisma.receiptTemplate.upsert({
            where: { businessId },
            update: {},
            create: { businessId },
        });
        emitToWindowsKasa(businessId, 'print:test_receipt', {
            printer,
            template,
            timestamp: new Date().toISOString(),
        });
        res.json({ success: true, message: `${printer.name} yazıcısına test fişi gönderildi.` });
    }
    catch (error) {
        console.error('Test fişi hatası:', error);
        res.status(500).json({ success: false, error: 'Test fişi gönderilemedi.' });
    }
}
