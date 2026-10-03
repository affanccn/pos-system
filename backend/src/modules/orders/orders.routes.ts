import { Router } from 'express';
import { 
  createOrder, 
  getActiveOrderByTable, 
  addItemsToOrder,
  requestTableBill,
  closeOrderAndTable,
  transferTable,
  mergeTables,
  voidOrderItem,
  makePayment, processOrderPayment, applyOrderDiscount, makeItemComplimentary,
  getKitchenOrders,
  updateOrderItemStatus,
  readyAllOrderItems,
} from './orders.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const ordersRouter = Router();

ordersRouter.use(authMiddleware);

// 1. Statik ve Genel Rotalar
ordersRouter.post('/transfer', requirePermission(PERMISSIONS.TABLE_TRANSFER), transferTable);
ordersRouter.post('/merge', requirePermission(PERMISSIONS.TABLE_MERGE), mergeTables);
ordersRouter.get('/kitchen', requirePermission(PERMISSIONS.KITCHEN_VIEW), getKitchenOrders);

// 2. Masa Bazlı İşlemler
ordersRouter.get('/table/:tableId', requirePermission(PERMISSIONS.TABLE_VIEW), getActiveOrderByTable);
ordersRouter.post('/table/:tableId/bill-request', requirePermission(PERMISSIONS.ORDER_EDIT), requestTableBill);
ordersRouter.post('/table/:tableId/close', requirePermission(PERMISSIONS.PAYMENT_CREATE), closeOrderAndTable);
ordersRouter.post('/table/:tableId/payment', requirePermission(PERMISSIONS.PAYMENT_CREATE), makePayment);

// 3. Sipariş ve Kalem Bazlı İşlemler
ordersRouter.post('/', requirePermission(PERMISSIONS.ORDER_CREATE), createOrder);
ordersRouter.post('/:orderId/items', requirePermission(PERMISSIONS.ORDER_EDIT), addItemsToOrder);
ordersRouter.post('/:orderId/payment', requirePermission(PERMISSIONS.PAYMENT_CREATE), processOrderPayment);
ordersRouter.post('/:orderId/discount', requirePermission(PERMISSIONS.PAYMENT_CREATE), applyOrderDiscount);
ordersRouter.post('/items/:orderItemId/complimentary', requirePermission(PERMISSIONS.PAYMENT_CREATE), makeItemComplimentary);
ordersRouter.patch('/:orderId/ready-all', requirePermission(PERMISSIONS.KITCHEN_MANAGE), readyAllOrderItems);
ordersRouter.delete('/items/:orderItemId', requirePermission(PERMISSIONS.ORDER_VOID), voidOrderItem);
ordersRouter.patch('/items/:orderItemId/status', requirePermission(PERMISSIONS.KITCHEN_MANAGE), updateOrderItemStatus);
