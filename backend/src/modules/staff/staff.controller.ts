import type { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma.js';
import { Role } from '@prisma/client';

export async function getStaffList(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    const staff = await prisma.user.findMany({
      where: { businessId },
      select: {
        id: true,
        fullName: true,
        email: true,
        role: true,
        customPermissions: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: [{ isActive: 'desc' }, { createdAt: 'asc' }],
    });

    res.json({
      success: true,
      data: staff,
    });
  } catch (error) {
    console.error('Personel listesi alma hatası:', error);
    res.status(500).json({ success: false, error: 'Personel listesi alınamadı.' });
  }
}

export async function createStaff(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { fullName, pinCode, role, email, customPermissions } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 2) {
      res.status(400).json({ success: false, error: 'Geçerli bir ad ve soyad giriniz.' });
      return;
    }

    if (!pinCode || !/^\d{4}$/.test(pinCode.toString())) {
      res.status(400).json({ success: false, error: 'PIN kodu tam 4 haneli rakamlardan oluşmalıdır.' });
      return;
    }

    const validRoles = Object.values(Role);
    if (!role || !validRoles.includes(role)) {
      res.status(400).json({ success: false, error: `Geçersiz rol. İzin verilen roller: ${validRoles.join(', ')}` });
      return;
    }

    const existingUsers = await prisma.user.findMany({
      where: { businessId, isActive: true },
    });

    for (const u of existingUsers) {
      const isMatch = await bcrypt.compare(pinCode.toString(), u.pinCodeHash);
      if (isMatch) {
        res.status(409).json({
          success: false,
          error: 'Bu 4 haneli PIN başka bir personel tarafından kullanılıyor. Lütfen farklı bir PIN belirleyin.',
        });
        return;
      }
    }

    const pinCodeHash = await bcrypt.hash(pinCode.toString(), 10);

    const newStaff = await prisma.user.create({
      data: {
        businessId,
        fullName: fullName.trim(),
        pinCodeHash,
        role: role as Role,
        email: email && typeof email === 'string' && email.trim().length > 0 ? email.trim() : null,
        customPermissions: Array.isArray(customPermissions) ? customPermissions : [],
        isActive: true,
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        role: true,
        customPermissions: true,
        isActive: true,
        createdAt: true,
      },
    });

    res.status(201).json({
      success: true,
      message: `${newStaff.fullName} başarıyla personel olarak eklendi.`,
      data: newStaff,
    });
  } catch (error) {
    console.error('Personel oluşturma hatası:', error);
    res.status(500).json({ success: false, error: 'Personel oluşturulamadı.' });
  }
}

export async function updateStaff(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = String(req.params.id);
    const { fullName, role, email, isActive, customPermissions } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    const existing = await prisma.user.findFirst({
      where: { id, businessId },
    });

    if (!existing) {
      res.status(404).json({ success: false, error: 'Personel bulunamadı.' });
      return;
    }

    const updateData: any = {};
    if (fullName && typeof fullName === 'string') updateData.fullName = fullName.trim();
    if (role && Object.values(Role).includes(role)) updateData.role = role as Role;
    if (typeof email === 'string') updateData.email = email.trim() || null;
    if (Array.isArray(customPermissions)) updateData.customPermissions = customPermissions;
    if (typeof isActive === 'boolean') {
      if (req.user?.userId === id && !isActive) {
        res.status(400).json({ success: false, error: 'Kendi hesabınızı pasife alamazsınız.' });
        return;
      }
      updateData.isActive = isActive;
    }

    const updated = await prisma.user.update({
      where: { id },
      data: updateData,
      select: {
        id: true,
        fullName: true,
        email: true,
        role: true,
        customPermissions: true,
        isActive: true,
        updatedAt: true,
      },
    });

    res.json({
      success: true,
      message: 'Personel bilgileri güncellendi.',
      data: updated,
    });
  } catch (error) {
    console.error('Personel güncelleme hatası:', error);
    res.status(500).json({ success: false, error: 'Personel güncellenemedi.' });
  }
}

export async function updateStaffPin(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = String(req.params.id);
    const { pinCode } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    if (!pinCode || !/^\d{4}$/.test(pinCode.toString())) {
      res.status(400).json({ success: false, error: 'Yeni PIN kodu tam 4 haneli rakam olmalıdır.' });
      return;
    }

    const existing = await prisma.user.findFirst({
      where: { id, businessId },
    });

    if (!existing) {
      res.status(404).json({ success: false, error: 'Personel bulunamadı.' });
      return;
    }

    const otherUsers = await prisma.user.findMany({
      where: { businessId, isActive: true, NOT: { id } },
    });

    for (const u of otherUsers) {
      const isMatch = await bcrypt.compare(pinCode.toString(), u.pinCodeHash);
      if (isMatch) {
        res.status(409).json({
          success: false,
          error: 'Bu 4 haneli PIN başka bir personele ait. Lütfen farklı bir PIN girin.',
        });
        return;
      }
    }

    const pinCodeHash = await bcrypt.hash(pinCode.toString(), 10);

    await prisma.user.update({
      where: { id },
      data: { pinCodeHash },
    });

    res.json({
      success: true,
      message: `${existing.fullName} için yeni PIN kodu başarıyla tanımlandı.`,
    });
  } catch (error) {
    console.error('PIN güncelleme hatası:', error);
    res.status(500).json({ success: false, error: 'PIN güncellenemedi.' });
  }
}

export async function deleteStaff(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = String(req.params.id);

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    if (req.user?.userId === id) {
      res.status(400).json({ success: false, error: 'Kendinizi silemezsiniz.' });
      return;
    }

    const existing = await prisma.user.findFirst({
      where: { id, businessId },
    });

    if (!existing) {
      res.status(404).json({ success: false, error: 'Personel bulunamadı.' });
      return;
    }

    const ordersCount = await prisma.order.count({ where: { waiterId: id } });
    const paymentsCount = await prisma.payment.count({ where: { cashierId: id } });

    if (ordersCount > 0 || paymentsCount > 0) {
      await prisma.user.update({
        where: { id },
        data: { isActive: false },
      });
      res.json({
        success: true,
        message: 'Personelin geçmiş sipariş/ödeme kayıtları bulunduğu için hesap pasifleştirildi.',
      });
      return;
    }

    await prisma.user.delete({ where: { id } });
    res.json({
      success: true,
      message: 'Personel hesabı kalıcı olarak silindi.',
    });
  } catch (error) {
    console.error('Personel silme hatası:', error);
    res.status(500).json({ success: false, error: 'Personel silinemedi.' });
  }
}