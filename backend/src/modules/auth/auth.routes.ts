import { Router } from 'express';
import { loginWithPin, getProfile } from './auth.controller.js';
import { authMiddleware } from '../../middleware/auth.js';

export const authRouter = Router();

// Hızlı PIN ile giriş (Halka açık)
authRouter.post('/login-pin', loginWithPin);

// Mevcut giriş yapmış profili getir (Korumalı)
authRouter.get('/me', authMiddleware, getProfile);
