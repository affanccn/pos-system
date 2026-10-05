import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'node:http';
import { initSocketServer } from './realtime/socket.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { tablesRouter } from './modules/tables/tables.routes.js';
import { catalogRouter } from './modules/catalog/catalog.routes.js';
import { ordersRouter } from './modules/orders/orders.routes.js';
import { paymentsRouter } from './modules/payments/payments.routes.js';
import { reportsRouter } from './modules/reports/reports.routes.js';
import { staffRouter } from './modules/staff/staff.routes.js';
import { printersRouter } from './modules/printers/printers.routes.js';
import { stockRouter } from './modules/stock/stock.routes.js';
import { expenseRouter } from './modules/expense/expense.routes.js';
import { cashRouter } from './modules/cash/cash.routes.js';
import { auditRouter } from './modules/audit/audit.routes.js';
import { reservationRouter } from './modules/reservation/reservation.routes.js';
import { branchRouter } from './modules/branch/branch.routes.js';
dotenv.config();
const app = express();
const httpServer = createServer(app);
const PORT = process.env.PORT || 3000;
app.use(express.json());
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
}));
initSocketServer(httpServer);
app.get('/api/health', (req, res) => {
    res.json({
        status: 'online',
        system: 'Restaurant POS SaaS Backend',
        message: 'Sunucu ve Socket.io sorunsuz calisiyor!',
        timestamp: new Date().toISOString(),
    });
});
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/tables', tablesRouter);
app.use('/api/v1/catalog', catalogRouter);
app.use('/api/v1/orders', ordersRouter);
app.use('/api/v1/payments', paymentsRouter);
app.use('/api/v1/reports', reportsRouter);
app.use('/api/v1/staff', staffRouter);
app.use('/api/v1/printers', printersRouter);
app.use('/api/v1/stock', stockRouter);
app.use('/api/v1/expenses', expenseRouter);
app.use('/api/v1/cash', cashRouter);
app.use('/api/v1/audit', auditRouter);
app.use('/api/v1/reservations', reservationRouter);
app.use('/api/v1/branches', branchRouter);
httpServer.listen(Number(PORT), '0.0.0.0', () => {
    console.log('==================================================');
    console.log('🚀 POS Backend & Socket.io çalışıyor!');
    console.log(`📡 HTTP & WS URL: http://0.0.0.0:${PORT}`);
    console.log(`🩺 Sağlık Testi:  http://localhost:${PORT}/api/health`);
    console.log('==================================================');
});
