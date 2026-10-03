import { Router } from 'express';
import { getDailyReport } from './reports.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';
export const reportsRouter = Router();
reportsRouter.use(authMiddleware);
// Gün sonu kasa raporu endpoint'i - Yalnızca rapor görüntüleme yetkisi olanlar (Müdür / Patron)
reportsRouter.get('/daily', requirePermission(PERMISSIONS.REPORT_VIEW), getDailyReport);
