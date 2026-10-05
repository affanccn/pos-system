import { Router } from 'express';
import { loginWithPin, getProfile } from './auth.controller.js';
import { authMiddleware } from '../../middleware/auth.js';
export const authRouter = Router();
authRouter.post('/login-pin', loginWithPin);
authRouter.get('/me', authMiddleware, getProfile);
