import type { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma.js';
import { signToken } from '../../utils/jwt.js';
import { getPermissionsForUser } from '../../constants/permissions.js';

export async function loginWithPin(req: Request, res: Response): Promise<void> {
  try {
    const { businessSlug, pinCode, isWindowsDevice } = req.body;

    if (!businessSlug || !pinCode) {
      res.status(400).json({
        success: false,
        error: 'İşletme kodu (slug) ve PIN kodu zorunludur.',
      });
      return;
    }

    const business = await prisma.business.findUnique({
      where: { slug: businessSlug, isActive: true },
    });

    if (!business) {
      res.status(404).json({
        success: false,
        error: 'İşletme bulunamadı veya sistemde pasif durumda.',
      });
      return;
    }

    const users = await prisma.user.findMany({
      where: { businessId: business.id, isActive: true },
    });

    let matchedUser = null;
    for (const u of users) {
      const isMatch = await bcrypt.compare(pinCode, u.pinCodeHash);
      if (isMatch) {
        matchedUser = u;
        break;
      }
    }

    if (!matchedUser) {
      res.status(401).json({
        success: false,
        error: 'Hatalı PIN kodu. Lütfen tekrar deneyin.',
      });
      return;
    }

    const isBossOrManager =
      matchedUser.role === 'OWNER' ||
      matchedUser.role === 'MANAGER' ||
      pinCode === '1111' ||
      pinCode === '2222';

    // KURAL 1: Windows Ana Kasa uygulamasına sadece Patron (1111 / OWNER) ve Müdür (2222 / MANAGER) girebilir!
    if (isWindowsDevice && !isBossOrManager) {
      res.status(403).json({
        success: false,
        error: 'Windows Ana Kasa paneline sadece Patron veya Müdür giriş yapabilir!',
      });
      return;
    }

    const permissions = getPermissionsForUser(matchedUser.role, matchedUser.customPermissions);

    const token = signToken({
      userId: matchedUser.id,
      businessId: business.id,
      role: matchedUser.role,
      fullName: matchedUser.fullName,
      permissions,
    });

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: matchedUser.id,
          fullName: matchedUser.fullName,
          role: matchedUser.role,
          email: matchedUser.email,
          permissions,
          isBossOrManager,
        },
        business: {
          id: business.id,
          name: business.name,
          slug: business.slug,
          currency: business.currency,
          isWindowsOnline: business.isWindowsOnline,
          isDayOpen: business.isDayOpen,
          canWaiterWork: business.isWindowsOnline && business.isDayOpen,
        },
      },
    });
  } catch (error) {
    console.error('Login Hatası:', error);
    res.status(500).json({
      success: false,
      error: 'Sunucu hatası: Giriş işlemi gerçekleştirilemedi.',
    });
  }
}

export async function getProfile(req: Request, res: Response): Promise<void> {
  if (!req.user) {
    res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
    return;
  }

  res.json({
    success: true,
    data: req.user,
  });
}