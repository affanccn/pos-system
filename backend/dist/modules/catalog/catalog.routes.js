import { Router } from 'express';
import { getCatalog, createCategory, createProduct } from './catalog.controller.js';
import { authMiddleware } from '../../middleware/auth.js';
export const catalogRouter = Router();
// Tüm katalog rotaları için JWT zorunlu
catalogRouter.use(authMiddleware);
// Menüyü (Kategoriler + Ürünler) listele
catalogRouter.get('/', getCatalog);
// Yeni kategori oluştur
catalogRouter.post('/categories', createCategory);
// Yeni ürün oluştur
catalogRouter.post('/products', createProduct);
