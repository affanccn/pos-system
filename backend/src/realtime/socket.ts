import { Server as HttpServer } from 'node:http';
import { Server, Socket } from 'socket.io';
import { verifyToken, type TokenPayload } from '../utils/jwt.js';

interface AuthenticatedSocket extends Socket {
  user?: TokenPayload;
}

let ioInstance: Server | null = null;

export function initSocketServer(server: HttpServer): Server {
  const io = new Server(server, {
    cors: {
      origin: '*', // Mobil uygulamaların erişimi için serbest bırakılır
      methods: ['GET', 'POST'],
    },
  });

  // Handshake Token Doğrulaması (Güvenlik Guard)
  io.use((socket: AuthenticatedSocket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace('Bearer ', '');

    if (!token) {
      return next(new Error('Yetkisiz bağlantı: Token eksik.'));
    }

    try {
      const decoded = verifyToken(token);
      socket.user = decoded;
      next();
    } catch {
      next(new Error('Geçersiz veya süresi dolmuş token.'));
    }
  });

  // Bağlantı Başarılı Olduğunda Odalara Dağıtma (Room Isolation)
  io.on('connection', (socket: AuthenticatedSocket) => {
    const user = socket.user;
    if (!user) return;

    const businessRoom = `business:${user.businessId}`;
    socket.join(businessRoom);

    // Rol bazlı özel kanallara kayıt
    if (user.role === 'KITCHEN' || user.role === 'OWNER' || user.role === 'MANAGER') {
      socket.join(`${businessRoom}:kitchen`);
    }

    if (user.role === 'WAITER' || user.role === 'OWNER' || user.role === 'MANAGER') {
      socket.join(`${businessRoom}:waiters`);
    }

    console.log(`🔌 [Socket Bağlandı]: ${user.fullName} (${user.role}) -> Oda: ${businessRoom}`);

    socket.on('disconnect', () => {
      console.log(`❌ [Socket Ayrıldı]: ${user.fullName}`);
    });
  });

  ioInstance = io;
  return io;
}

// Servis katmanından event fırlatıcı yardımcı fonksiyon
export function getIO(): Server {
  if (!ioInstance) {
    throw new Error('Socket.io henüz başlatılmadı!');
  }
  return ioInstance;
}
