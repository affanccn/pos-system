import { Router } from 'express';
import { processPayment } from './payments.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const paymentsRouter = Router();

// Tüm ödeme rotaları JWT korumalıdır
paymentsRouter.use(authMiddleware);

// Hesabı kapat / ödeme al
paymentsRouter.post('/', requirePermission(PERMISSIONS.PAYMENT_CREATE), processPayment);
