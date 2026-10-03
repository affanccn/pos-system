import type { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';
import { StationType } from '@prisma/client';

export async function getPrinters(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    const printers = await prisma.printer.findMany({
      where: { businessId, isActive: true },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ success: true, data: printers });
  } catch (error) {
    console.error('Yazıcılar listelenirken hata:', error);
    res.status(500).json({ success: false, error: 'Yazıcılar getirilemedi.' });
  }
}

export async function createPrinter(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { name, ipAddress, port, stationType, isCashier } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    if (!name || !ipAddress) {
      res.status(400).json({ success: false, error: 'Yazıcı adı ve IP adresi zorunludur.' });
      return;
    }

    const printer = await prisma.printer.create({
      data: {
        businessId,
        name: name.trim(),
        ipAddress: ipAddress.trim(),
        port: port ? Number(port) : 9100,
        stationType: stationType as StationType | null,
        isCashier: Boolean(isCashier),
      },
    });

    res.status(201).json({ success: true, data: printer });
  } catch (error) {
    console.error('Yazıcı oluşturulurken hata:', error);
    res.status(500).json({ success: false, error: 'Yazıcı eklenemedi.' });
  }
}

export async function updatePrinter(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = req.params.id as string;
    const { name, ipAddress, port, stationType, isCashier, isActive } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    const printer = await prisma.printer.updateMany({
      where: { id, businessId },
      data: {
        ...(name && { name: name.trim() }),
        ...(ipAddress && { ipAddress: ipAddress.trim() }),
        ...(port && { port: Number(port) }),
        ...(stationType !== undefined && { stationType: stationType as StationType | null }),
        ...(isCashier !== undefined && { isCashier: Boolean(isCashier) }),
        ...(isActive !== undefined && { isActive: Boolean(isActive) }),
      },
    });

    if (printer.count === 0) {
      res.status(404).json({ success: false, error: 'Yazıcı bulunamadı.' });
      return;
    }

    const updated = await prisma.printer.findUnique({ where: { id } });
    res.json({ success: true, data: updated });
  } catch (error) {
    console.error('Yazıcı güncellenirken hata:', error);
    res.status(500).json({ success: false, error: 'Yazıcı güncellenemedi.' });
  }
}

export async function deletePrinter(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const id = req.params.id as string;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
      return;
    }

    await prisma.printer.updateMany({
      where: { id, businessId },
      data: { isActive: false },
    });

    res.json({ success: true, message: 'Yazıcı silindi.' });
  } catch (error) {
    console.error('Yazıcı silinirken hata:', error);
    res.status(500).json({ success: false, error: 'Yazıcı silinemedi.' });
  }
}
