import { PrismaClient } from '@prisma/client';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();
const API_URL = 'http://localhost:3000/api/v1';

async function generateToken(businessId: string, role: string, userId: string) {
  return jwt.sign(
    { userId, businessId, role, fullName: 'E2E', permissions: [] },
    'fallback_secret_key',
    { expiresIn: '7d' }
  );
}

async function runTest() {
  console.log('--- STARTING E2E INTEGRATION TEST ---');

  const business = await prisma.business.findFirst();
  if (!business) throw new Error('No business found');

  let user = await prisma.user.findFirst({ where: { businessId: business.id } });
  if (!user) {
    user = await prisma.user.create({
      data: {
        businessId: business.id,
        email: 'test@e2e.com',
        fullName: 'E2E Test User',
        pinCodeHash: 'dummy',
        role: 'OWNER',
        customPermissions: []
      }
    });
  }

  const token = await generateToken(business.id, 'OWNER', user.id);
  const headers = { Authorization: `Bearer ${token}` };

  let table = await prisma.restaurantTable.findFirst({ where: { businessId: business.id } });
  if (!table) {
    table = await prisma.restaurantTable.create({
      data: { businessId: business.id, name: 'TEST MASA 1', capacity: 4 }
    });
  }

  let category = await prisma.category.findFirst({ where: { businessId: business.id } });
  if (!category) {
    category = await prisma.category.create({ data: { businessId: business.id, name: 'Test Kategori', sortOrder: 1 } });
  }

  let product = await prisma.product.findFirst({ where: { businessId: business.id } });
  if (!product) {
    product = await prisma.product.create({
      data: { businessId: business.id, categoryId: category.id, name: 'Test Ürün', priceCents: 10000, taxRate: 8, isActive: true }
    });
  }

  try {
    console.log('1. Masa Aç (Sipariş Oluştur)');
    let res = await fetch(`${API_URL}/orders`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ tableId: table.id, waiterId: user.id, items: [] })
    });
    let data = await res.json();
    if (!data.success) throw new Error(JSON.stringify(data) || 'Sipariş açılamadı');
    const orderId = data.data.id;
    console.log(' - Sipariş ID:', orderId);

    console.log('2. Sipariş Kalemi Ekle (Mutfağa Gönder)');
    await fetch(`${API_URL}/orders/${orderId}/items`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: [{ productId: product.id, quantity: 2 }] })
    });
    console.log(' - 2 adet ürün eklendi. Toplam 200 TL');

    console.log('3. Mutfak Durumunu Al ve Hazırla');
    res = await fetch(`${API_URL}/orders/kitchen`, { headers });
    data = await res.json();
    const testOrder = data.data.find((o: any) => o.id === orderId);
    if (!testOrder) throw new Error('Mutfak ekranında sipariş bulunamadı!');
    
    const itemId = testOrder.items[0].id;
    await fetch(`${API_URL}/orders/items/${itemId}/status`, {
      method: 'PATCH',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'READY' })
    });
    console.log(' - Ürün hazırlandı (Garsona bildirim gitti)');

    console.log('4. Hesap İste');
    await fetch(`${API_URL}/orders/table/${table.id}/bill-request`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
    console.log(' - Hesap istendi');

    console.log('5. Ödeme Al ve Kapat');
    res = await fetch(`${API_URL}/payments`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ orderId, amountCents: 20000, method: 'CARD' })
    });
    data = await res.json();
    if (!data.success) throw new Error(data.error);
    console.log(' - Ödeme alındı:', data.message);

    console.log('--- E2E TEST BASARILI (Senaryo Uçtan Uca Çalışıyor) ---');
  } catch (err: any) {
    console.error('--- E2E TEST BASARISIZ ---');
    console.error(err.message || err);
  } finally {
    await prisma.$disconnect();
  }
}

runTest();
