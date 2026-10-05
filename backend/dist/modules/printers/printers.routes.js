import { Router } from 'express';
import { getPrinters, createPrinter, updatePrinter, deletePrinter, assignCategoriesToPrinter, getReceiptTemplate, updateReceiptTemplate, triggerTestPrint, } from './printers.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';
const router = Router();
router.use(authMiddleware);
// Fiş Tasarım Stüdyosu (Hesap & Sipariş Fişi Şablonu) Rotaları
router.get('/template', requirePermission(PERMISSIONS.SETTINGS_VIEW), getReceiptTemplate);
router.put('/template', requirePermission(PERMISSIONS.SETTINGS_EDIT), updateReceiptTemplate);
// Kategori -> Yazıcı (Bar / Mutfak / Nargile) Toplu Eşleştirme Rotası
router.post('/assign-categories', requirePermission(PERMISSIONS.SETTINGS_EDIT), assignCategoriesToPrinter);
// Windows'tan Test Fişi Yazdırma Rotası
router.post('/:id/test-print', requirePermission(PERMISSIONS.SETTINGS_EDIT), triggerTestPrint);
// Mevcut Yazıcı CRUD Rotaları
router.get('/', requirePermission(PERMISSIONS.SETTINGS_VIEW), getPrinters);
router.post('/', requirePermission(PERMISSIONS.SETTINGS_EDIT), createPrinter);
router.put('/:id', requirePermission(PERMISSIONS.SETTINGS_EDIT), updatePrinter);
router.delete('/:id', requirePermission(PERMISSIONS.SETTINGS_EDIT), deletePrinter);
export { router as printersRouter };
