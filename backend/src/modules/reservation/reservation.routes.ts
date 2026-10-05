import { Router } from 'express';
import { createReservation, getReservations, updateReservationStatus, deleteReservation } from './reservation.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const reservationRouter = Router();

reservationRouter.use(authMiddleware);

reservationRouter.get('/', getReservations);
reservationRouter.post('/', requirePermission(PERMISSIONS.TABLE_EDIT), createReservation);
reservationRouter.patch('/:id', requirePermission(PERMISSIONS.TABLE_EDIT), updateReservationStatus);
reservationRouter.delete('/:id', requirePermission(PERMISSIONS.TABLE_EDIT), deleteReservation);
