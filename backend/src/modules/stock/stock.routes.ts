import { Router } from 'express';
import { getStockItems, createStockItem, updateStockItem, deleteStockItem } from './stock.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const stockRouter = Router();

stockRouter.use(authMiddleware);

stockRouter.get('/', requirePermission(PERMISSIONS.STOCK_VIEW), getStockItems);
stockRouter.post('/', requirePermission(PERMISSIONS.STOCK_CREATE), createStockItem);
stockRouter.put('/:id', requirePermission(PERMISSIONS.STOCK_ADJUST), updateStockItem);
stockRouter.delete('/:id', requirePermission(PERMISSIONS.STOCK_ADJUST), deleteStockItem);
