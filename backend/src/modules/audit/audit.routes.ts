import { Router } from 'express';
import { getAuditLogs } from './audit.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const auditRouter = Router();

auditRouter.use(authMiddleware);

auditRouter.get('/', requirePermission(PERMISSIONS.REPORT_VIEW), getAuditLogs);
