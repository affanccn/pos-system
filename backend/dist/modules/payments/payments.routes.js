import { Router } from 'express';
import { processPayment } from './payments.controller.js';
import { authMiddleware } from '../../middleware/auth.js';
export const paymentsRouter = Router();
// Tüm ödeme rotaları JWT korumalıdır
paymentsRouter.use(authMiddleware);
// Hesabı kapat / ödeme al
paymentsRouter.post('/', processPayment);
