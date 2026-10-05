import { Server } from 'socket.io';
import { PrismaClient } from '@prisma/client';
import { verifyToken } from '../utils/jwt.js';
const prisma = new PrismaClient();
let ioInstance = null;
export function initSocketServer(server) {
    const io = new Server(server, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST'],
        },
    });
    io.use((socket, next) => {
        const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace('Bearer ', '');
        if (!token) {
            return next(new Error('Yetkisiz bağlantı: Token eksik.'));
        }
        try {
            const decoded = verifyToken(token);
            socket.user = decoded;
            next();
        }
        catch {
            next(new Error('Geçersiz veya süresi dolmuş token.'));
        }
    });
    io.on('connection', async (socket) => {
        const user = socket.user;
        if (!user)
            return;
        const businessRoom = `business:${user.businessId}`;
        socket.join(businessRoom);
        if (user.role === 'KITCHEN' || user.role === 'OWNER' || user.role === 'MANAGER') {
            socket.join(`${businessRoom}:kitchen`);
        }
        if (user.role === 'WAITER' || user.role === 'OWNER' || user.role === 'MANAGER') {
            socket.join(`${businessRoom}:waiters`);
        }
        console.log(`🔌 [Socket Bağlandı]: ${user.fullName} (${user.role}) -> Oda: ${businessRoom}`);
        // Cihaz ilk bağlandığında işletmenin güncel Windows Kasa ve Gün durumunu gönder
        try {
            const business = await prisma.business.findUnique({
                where: { id: user.businessId },
                select: { isWindowsOnline: true, isDayOpen: true },
            });
            if (business) {
                socket.emit('kasa_status_changed', {
                    isWindowsOnline: business.isWindowsOnline,
                    isDayOpen: business.isDayOpen,
                    canWaiterWork: business.isWindowsOnline && business.isDayOpen,
                });
            }
        }
        catch (err) {
            console.error('Kasa durumu okunamadı:', err);
        }
        // 1. WINDOWS UYGULAMASI AÇILDIĞINDA KENDİNİ "ANA KASA" OLARAK KAYDEDER
        socket.on('register_windows_kasa', async () => {
            if (user.role !== 'OWNER' && user.role !== 'MANAGER') {
                socket.emit('kasa_error', { message: 'Windows Ana Kasayı sadece Patron veya Müdür açabilir!' });
                return;
            }
            try {
                socket.join(`${businessRoom}:windows_kasa`);
                const updatedBusiness = await prisma.business.update({
                    where: { id: user.businessId },
                    data: {
                        isWindowsOnline: true,
                        windowsSocketId: socket.id,
                    },
                });
                console.log(`💻 [Windows Ana Kasa Aktif]: ${user.fullName} (Socket: ${socket.id})`);
                // İşletmedeki tüm telefonlara Windows'un açıldığını anında bildir
                io.to(businessRoom).emit('kasa_status_changed', {
                    isWindowsOnline: true,
                    isDayOpen: updatedBusiness.isDayOpen,
                    canWaiterWork: updatedBusiness.isDayOpen, // Gün de açıksa garsonlar çalışabilir
                });
            }
            catch (err) {
                console.error('Windows kasa kaydı hatası:', err);
            }
        });
        // 2. WINDOWS'TAN "GÜNÜ BAŞLAT" VEYA "GÜN SONU AL (KAPAT)" TETİKLENDİĞİNDE
        socket.on('toggle_day_status', async (data) => {
            if (user.role !== 'OWNER' && user.role !== 'MANAGER')
                return;
            try {
                const updatedBusiness = await prisma.business.update({
                    where: { id: user.businessId },
                    data: {
                        isDayOpen: data.isDayOpen,
                        dayOpenedAt: data.isDayOpen ? new Date() : null,
                    },
                });
                io.to(businessRoom).emit('kasa_status_changed', {
                    isWindowsOnline: updatedBusiness.isWindowsOnline,
                    isDayOpen: updatedBusiness.isDayOpen,
                    canWaiterWork: updatedBusiness.isWindowsOnline && updatedBusiness.isDayOpen,
                });
            }
            catch (err) {
                console.error('Gün durumu güncellenemedi:', err);
            }
        });
        // 3. BAĞLANTI KOPTUĞUNDA: EĞER KOPAN CİHAZ WINDOWS KASA İSE TELEFONLARI ANINDA KİLİTLE!
        socket.on('disconnect', async () => {
            console.log(`❌ [Socket Ayrıldı]: ${user.fullName}`);
            try {
                const business = await prisma.business.findUnique({
                    where: { id: user.businessId },
                    select: { windowsSocketId: true, isDayOpen: true },
                });
                if (business && business.windowsSocketId === socket.id) {
                    await prisma.business.update({
                        where: { id: user.businessId },
                        data: {
                            isWindowsOnline: false,
                            windowsSocketId: null,
                        },
                    });
                    console.log(`⚠️ [Windows Ana Kasa Koptu]: İşletme (${user.businessId}) garson ekranları kilitlendi!`);
                    // Tüm telefonlara anında kilit sinyali gönder
                    io.to(businessRoom).emit('kasa_status_changed', {
                        isWindowsOnline: false,
                        isDayOpen: business.isDayOpen,
                        canWaiterWork: false,
                    });
                }
            }
            catch (err) {
                console.error('Disconnect kasa kontrol hatası:', err);
            }
        });
    });
    ioInstance = io;
    return io;
}
export function getIO() {
    if (!ioInstance) {
        throw new Error('Socket.io henüz başlatılmadı!');
    }
    return ioInstance;
}
// Sipariş ve Hesap Fişlerini doğrudan o işletmenin Windows Kasasına gönderen yardımcı fonksiyon
export function emitToWindowsKasa(businessId, event, payload) {
    if (!ioInstance)
        return;
    ioInstance.to(`business:${businessId}:windows_kasa`).emit(event, payload);
}
