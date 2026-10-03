import { Router } from 'express';
import { 
  getTables, 
  createTable, 
  updateTable, 
  deleteTable, 
  updateTableStatus,
  transferTable,
  mergeTables,
  reorderTables,
  callWaiter
} from './tables.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const tablesRouter = Router();

// Tum masa rotalari icin Token zorunlu
tablesRouter.use(authMiddleware);

// Masalari listele
tablesRouter.get('/', getTables);

// Masaları yeniden sırala
tablesRouter.post('/reorder', requirePermission(PERMISSIONS.TABLE_EDIT), reorderTables);

// Yeni masa ekle
tablesRouter.post('/', requirePermission(PERMISSIONS.TABLE_CREATE), createTable);

// Masa bilgilerini guncelle
tablesRouter.put('/:id', requirePermission(PERMISSIONS.TABLE_EDIT), updateTable);

// Masayi sil / pasife al
tablesRouter.delete('/:id', requirePermission(PERMISSIONS.TABLE_DELETE), deleteTable);

// Masa durumunu guncelle
tablesRouter.patch('/:id/status', requirePermission(PERMISSIONS.TABLE_EDIT), updateTableStatus);

// Masa Transferi (Masadan Masaya Tasıma)
tablesRouter.post('/transfer', requirePermission(PERMISSIONS.TABLE_EDIT), transferTable);

// Masaları Birleştirme
tablesRouter.post('/merge', requirePermission(PERMISSIONS.TABLE_EDIT), mergeTables);

// Garson Çağır
tablesRouter.post('/:id/call-waiter', callWaiter); // public/customer endpoint can remain without permissions or handled via token.
