import { Router } from 'express';
import { 
  getStaffList, 
  createStaff, 
  updateStaff, 
  updateStaffPin, 
  deleteStaff 
} from './staff.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const staffRouter = Router();

staffRouter.use(authMiddleware);

staffRouter.get('/', requirePermission(PERMISSIONS.STAFF_VIEW), getStaffList);

staffRouter.post('/', requirePermission(PERMISSIONS.STAFF_CREATE), createStaff);

staffRouter.put('/:id', requirePermission(PERMISSIONS.STAFF_EDIT), updateStaff);

staffRouter.patch('/:id/pin', requirePermission(PERMISSIONS.STAFF_EDIT), updateStaffPin);

staffRouter.delete('/:id', requirePermission(PERMISSIONS.STAFF_DELETE), deleteStaff);