import { Router } from 'express';
import { getStaffList, createStaff, updateStaff, updateStaffPin, deleteStaff } from './staff.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';
export const staffRouter = Router();
staffRouter.use(authMiddleware);
// Personel listeleme
staffRouter.get('/', requirePermission(PERMISSIONS.STAFF_VIEW), getStaffList);
// Yeni personel oluşturma
staffRouter.post('/', requirePermission(PERMISSIONS.STAFF_CREATE), createStaff);
// Personel bilgilerini güncelleme
staffRouter.put('/:id', requirePermission(PERMISSIONS.STAFF_EDIT), updateStaff);
// Personel PIN kodunu değiştirme
staffRouter.patch('/:id/pin', requirePermission(PERMISSIONS.STAFF_EDIT), updateStaffPin);
// Personel silme veya pasifleştirme
staffRouter.delete('/:id', requirePermission(PERMISSIONS.STAFF_DELETE), deleteStaff);
