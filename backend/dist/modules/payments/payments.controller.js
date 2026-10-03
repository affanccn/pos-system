import { prisma } from '../../config/prisma.js';
import { OrderStatus, TableStatus, PaymentMethod } from '@prisma/client';
import { getIO } from '../../realtime/socket.js';
// 1. Ödeme Al ve Masayı Kapat (Transaction)
export async function processPayment(req, res) {
    try {
        const businessId = req.user?.businessId;
        const cashierId = req.user?.userId;
        const { orderId, method, cashAmountCents = 0, cardAmountCents = 0 } = req.body;
        if (!businessId || !cashierId) {
            res.status(401).json({ success: false, error: 'Oturum bilgisi doğrulanamadı.' });
            return;
        }
        if (!orderId || !method) {
            res.status(400).json({ success: false, error: 'Sipariş ID ve ödeme yöntemi zorunludur.' });
            return;
        }
        // Siparişi ve işletme aidiyetini doğrula
        const order = await prisma.order.findFirst({
            where: { id: orderId, businessId },
            include: { table: true },
        });
        if (!order) {
            res.status(404).json({ success: false, error: 'Sipariş bulunamadı.' });
            return;
        }
        if (order.status === OrderStatus.PAID) {
            res.status(400).json({ success: false, error: 'Bu siparişin hesabı zaten kapatılmış.' });
            return;
        }
        const totalBillCents = order.totalAmountCents;
        let finalCash = 0;
        let finalCard = 0;
        // Ödeme yöntemi doğrulaması
        if (method === PaymentMethod.CASH) {
            finalCash = totalBillCents;
        }
        else if (method === PaymentMethod.CARD) {
            finalCard = totalBillCents;
        }
        else if (method === PaymentMethod.MIXED) {
            finalCash = Math.round(Number(cashAmountCents) || 0);
            finalCard = Math.round(Number(cardAmountCents) || 0);
            if (finalCash + finalCard !== totalBillCents) {
                res.status(400).json({
                    success: false,
                    error: `Karma ödeme tutarı sipariş tutarına eşit olmalıdır. Beklenen: ${totalBillCents} kuruş, Girilen: ${finalCash + finalCard} kuruş.`,
                });
                return;
            }
        }
        // Prisma Transaction: Payment oluştur -> Order'ı PAID yap -> Masayı AVAILABLE yap
        const transactionResult = await prisma.$transaction(async (tx) => {
            // 1. Ödeme kaydı
            const payment = await tx.payment.create({
                data: {
                    businessId,
                    orderId,
                    cashierId,
                    method,
                    amountCents: totalBillCents,
                    cashAmountCents: finalCash,
                    cardAmountCents: finalCard,
                },
            });
            // 2. Siparişi PAID durumuna al
            await tx.order.update({
                where: { id: orderId },
                data: { status: OrderStatus.PAID },
            });
            // 3. Masayı serbest bırak (AVAILABLE)
            await tx.restaurantTable.update({
                where: { id: order.tableId },
                data: {
                    status: TableStatus.AVAILABLE,
                    currentOrderId: null,
                },
            });
            return payment;
        });
        // Realtime: Masanın boşaldığını tüm garsonlara ve yöneticilere bildir
        try {
            const io = getIO();
            io.to(`business:${businessId}`).emit('table:status_changed', {
                tableId: order.tableId,
                status: TableStatus.AVAILABLE,
                closedOrderId: orderId,
            });
        }
        catch (socketErr) {
            console.warn('Socket bildirimi iletilemedi:', socketErr);
        }
        res.status(201).json({
            success: true,
            message: `Hesap başarıyla kapatıldı (${totalBillCents / 100} TL). Masa servise hazır.`,
            data: transactionResult,
        });
    }
    catch (error) {
        console.error('Ödeme işlemi sırasında hata:', error);
        res.status(500).json({ success: false, error: 'Ödeme alınamadı.' });
    }
}
