import { Router } from 'express';
import { getCashMovements, createCashMovement, getDailyCashSummary } from './cash.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const cashRouter = Router();

cashRouter.use(authMiddleware);

cashRouter.get('/', requirePermission(PERMISSIONS.REPORT_FINANCIAL), getCashMovements);
cashRouter.post('/', requirePermission(PERMISSIONS.PAYMENT_CREATE), createCashMovement);
cashRouter.get('/summary', requirePermission(PERMISSIONS.REPORT_FINANCIAL), getDailyCashSummary);
