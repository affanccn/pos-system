import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { createOrder, getActiveOrderByTable, addItemsToOrder, requestTableBill, closeOrderAndTable, transferTable, mergeTables, voidOrderItem, makePayment, processOrderPayment, applyOrderDiscount, makeItemComplimentary, getKitchenOrders, updateOrderItemStatus, readyAllOrderItems, transferOrderItems, } from './orders.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';
const prisma = new PrismaClient();
export const ordersRouter = Router();
ordersRouter.use(authMiddleware);
// KASA KİLİDİ GUARD: Windows PC açık değilse veya Gün başlatılmadıysa sipariş/operasyon işlemlerini reddet!
async function requireActiveWindowsKasa(req, res, next) {
    try {
        const user = req.user;
        if (!user?.businessId) {
            return res.status(401).json({ message: 'Yetkisiz işlem.' });
        }
        const business = await prisma.business.findUnique({
            where: { id: user.businessId },
            select: { isWindowsOnline: true, isDayOpen: true },
        });
        if (!business?.isWindowsOnline) {
            return res.status(423).json({
                code: 'WINDOWS_OFFLINE',
                message: 'Ana Kasa (Windows) bilgisayarı şu anda açık değil! Sipariş işlemi yapılamaz.',
            });
        }
        if (!business?.isDayOpen) {
            return res.status(423).json({
                code: 'DAY_NOT_OPEN',
                message: 'Kasadan "Gün Başlatma" işlemi yapılmamış! Lütfen Windows Kasadan günü başlatın.',
            });
        }
        next();
    }
    catch (error) {
        next(error);
    }
}
// Görüntüleme rotaları (Patron ve Müdür Windows kapalıyken de bakabilsin diye kilit yok)
ordersRouter.get('/kitchen', requirePermission(PERMISSIONS.KITCHEN_VIEW), getKitchenOrders);
ordersRouter.get('/table/:tableId', requirePermission(PERMISSIONS.TABLE_VIEW), getActiveOrderByTable);
// Operasyon ve Sipariş Rotaları (Windows Kasa AÇIK ve GÜN BAŞLATILMIŞ olmak zorunda!)
ordersRouter.post('/transfer', requireActiveWindowsKasa, requirePermission(PERMISSIONS.TABLE_TRANSFER), transferTable);
ordersRouter.post('/transfer-items', requireActiveWindowsKasa, requirePermission(PERMISSIONS.TABLE_TRANSFER), transferOrderItems);
ordersRouter.post('/merge', requireActiveWindowsKasa, requirePermission(PERMISSIONS.TABLE_MERGE), mergeTables);
ordersRouter.post('/table/:tableId/bill-request', requireActiveWindowsKasa, requirePermission(PERMISSIONS.ORDER_EDIT), requestTableBill);
ordersRouter.post('/table/:tableId/close', requireActiveWindowsKasa, requirePermission(PERMISSIONS.PAYMENT_CREATE), closeOrderAndTable);
ordersRouter.post('/table/:tableId/payment', requireActiveWindowsKasa, requirePermission(PERMISSIONS.PAYMENT_CREATE), makePayment);
ordersRouter.post('/', requireActiveWindowsKasa, requirePermission(PERMISSIONS.ORDER_CREATE), createOrder);
ordersRouter.post('/:orderId/items', requireActiveWindowsKasa, requirePermission(PERMISSIONS.ORDER_EDIT), addItemsToOrder);
ordersRouter.post('/:orderId/payment', requireActiveWindowsKasa, requirePermission(PERMISSIONS.PAYMENT_CREATE), processOrderPayment);
ordersRouter.post('/:orderId/discount', requireActiveWindowsKasa, requirePermission(PERMISSIONS.PAYMENT_CREATE), applyOrderDiscount);
ordersRouter.post('/items/:orderItemId/complimentary', requireActiveWindowsKasa, requirePermission(PERMISSIONS.PAYMENT_CREATE), makeItemComplimentary);
ordersRouter.patch('/:orderId/ready-all', requireActiveWindowsKasa, requirePermission(PERMISSIONS.KITCHEN_MANAGE), readyAllOrderItems);
ordersRouter.delete('/items/:orderItemId', requireActiveWindowsKasa, requirePermission(PERMISSIONS.ORDER_VOID), voidOrderItem);
ordersRouter.patch('/items/:orderItemId/status', requireActiveWindowsKasa, requirePermission(PERMISSIONS.KITCHEN_MANAGE), updateOrderItemStatus);
