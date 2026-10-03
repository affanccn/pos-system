import { Router, Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';
import { authMiddleware, requireRole } from '../../middleware/auth.js';

export const branchRouter = Router();

branchRouter.use(authMiddleware);

// Sadece OWNER yetkisindeki kullanıcılar kendi mail adresine bağlı şubeleri görebilir.
branchRouter.get('/', requireRole(['OWNER']), async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Kullanici bilgisi eksik.' });
      return;
    }

    const dbUser = await prisma.user.findUnique({
      where: { id: user.userId },
      select: { email: true }
    });

    if (!dbUser || !dbUser.email) {
      const currentBusiness = await prisma.business.findUnique({
        where: { id: user.businessId }
      });
      res.json({ success: true, data: currentBusiness ? [currentBusiness] : [] });
      return;
    }

    const branches = await prisma.user.findMany({
      where: {
        email: dbUser.email,
        role: 'OWNER'
      },
      include: {
        business: true
      }
    });

    const businessList = branches.map(b => b.business);
    res.json({ success: true, data: businessList });

  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Şubeler getirilemedi.' });
  }
});
