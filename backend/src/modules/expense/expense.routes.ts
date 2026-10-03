import { Router } from 'express';
import { getExpenses, createExpense, deleteExpense } from './expense.controller.js';
import { authMiddleware, requirePermission } from '../../middleware/auth.js';
import { PERMISSIONS } from '../../constants/permissions.js';

export const expenseRouter = Router();

expenseRouter.use(authMiddleware);

expenseRouter.get('/', requirePermission(PERMISSIONS.REPORT_FINANCIAL), getExpenses);
expenseRouter.post('/', requirePermission(PERMISSIONS.PAYMENT_CREATE), createExpense);
expenseRouter.delete('/:id', requirePermission(PERMISSIONS.REPORT_FINANCIAL), deleteExpense);
