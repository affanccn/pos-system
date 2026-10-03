import { Router } from 'express';
import { getTables, createTable, updateTable, deleteTable, updateTableStatus } from './tables.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';
export const tablesRouter = Router();
// Tum masa rotalari icin Token zorunlu
tablesRouter.use(authMiddleware);
// Masalari listele
tablesRouter.get('/', getTables);
// Yeni masa ekle
tablesRouter.post('/', requirePermission(PERMISSIONS.TABLE_CREATE), createTable);
// Masa bilgilerini guncelle
tablesRouter.put('/:id', requirePermission(PERMISSIONS.TABLE_EDIT), updateTable);
// Masayi sil / pasife al
tablesRouter.delete('/:id', requirePermission(PERMISSIONS.TABLE_DELETE), deleteTable);
// Masa durumunu guncelle
tablesRouter.patch('/:id/status', updateTableStatus);
