import { Router } from 'express';
import { getPrinters, createPrinter, updatePrinter, deletePrinter } from './printers.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

const router = Router();

// Tüm işlemler için ayarlar yetkisi (settings.edit veya view) gerekebilir.
// Patron ve Müdür için genel settings yetkisini kontrol edeceğiz.
router.use(authMiddleware);

router.get('/', requirePermission(PERMISSIONS.SETTINGS_VIEW), getPrinters);
router.post('/', requirePermission(PERMISSIONS.SETTINGS_EDIT), createPrinter);
router.put('/:id', requirePermission(PERMISSIONS.SETTINGS_EDIT), updatePrinter);
router.delete('/:id', requirePermission(PERMISSIONS.SETTINGS_EDIT), deletePrinter);

export { router as printersRouter };
