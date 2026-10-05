import { Request, Response } from 'express';
import { prisma } from '../../config/prisma.js';

export async function createReservation(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { customerName, customerPhone, reservationDate, guestCount, tableId, notes } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const reservation = await prisma.reservation.create({
      data: {
        businessId,
        customerName,
        customerPhone,
        reservationDate: new Date(reservationDate),
        guestCount,
        tableId,
        notes,
        status: 'PENDING',
      },
      include: {
        table: true,
      },
    });

    res.json({ success: true, data: reservation });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Rezervasyon olusturulamadi.' });
  }
}

export async function getReservations(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { date, status } = req.query;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const whereClause: any = { businessId };
    
    if (date) {
      const start = new Date(date as string);
      start.setHours(0, 0, 0, 0);
      const end = new Date(date as string);
      end.setHours(23, 59, 59, 999);
      whereClause.reservationDate = { gte: start, lte: end };
    }

    if (status) {
      whereClause.status = status;
    }

    const reservations = await prisma.reservation.findMany({
      where: whereClause,
      include: {
        table: true,
      },
      orderBy: { reservationDate: 'asc' },
    });

    res.json({ success: true, data: reservations });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Rezervasyonlar getirilemedi.' });
  }
}

export async function updateReservationStatus(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { id } = req.params;
    const { status, tableId } = req.body;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    const updateData: any = {};
    if (status) updateData.status = status;
    if (tableId !== undefined) updateData.tableId = tableId;

    const reservation = await prisma.reservation.update({
      where: { id: id as string, businessId },
      data: updateData,
      include: { table: true },
    });

    res.json({ success: true, data: reservation });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Rezervasyon güncellenemedi.' });
  }
}

export async function deleteReservation(req: Request, res: Response): Promise<void> {
  try {
    const businessId = req.user?.businessId;
    const { id } = req.params;

    if (!businessId) {
      res.status(401).json({ success: false, error: 'Oturum bilgisi bulunamadi.' });
      return;
    }

    await prisma.reservation.delete({
      where: { id: id as string, businessId },
    });

    res.json({ success: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, error: 'Rezervasyon silinemedi.' });
  }
}
