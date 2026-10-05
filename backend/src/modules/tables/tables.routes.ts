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

tablesRouter.use(authMiddleware);

tablesRouter.get('/', getTables);

tablesRouter.post('/reorder', requirePermission(PERMISSIONS.TABLE_EDIT), reorderTables);

tablesRouter.post('/', requirePermission(PERMISSIONS.TABLE_CREATE), createTable);

tablesRouter.put('/:id', requirePermission(PERMISSIONS.TABLE_EDIT), updateTable);

tablesRouter.delete('/:id', requirePermission(PERMISSIONS.TABLE_DELETE), deleteTable);

tablesRouter.patch('/:id/status', requirePermission(PERMISSIONS.TABLE_EDIT), updateTableStatus);

tablesRouter.post('/transfer', requirePermission(PERMISSIONS.TABLE_EDIT), transferTable);

tablesRouter.post('/merge', requirePermission(PERMISSIONS.TABLE_EDIT), mergeTables);

tablesRouter.post('/:id/call-waiter', callWaiter);
