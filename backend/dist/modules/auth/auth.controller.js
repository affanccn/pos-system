import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma.js';
import { signToken } from '../../utils/jwt.js';
import { getPermissionsForUser } from '../../constants/permissions.js';
export async function loginWithPin(req, res) {
    try {
        const { businessSlug, pinCode } = req.body;
        if (!businessSlug || !pinCode) {
            res.status(400).json({
                success: false,
                error: 'İşletme kodu (slug) ve PIN kodu zorunludur.',
            });
            return;
        }
        // 1. Önce işletmeyi bul
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
        // 2. İşletmeye bağlı aktif personelleri getir
        const users = await prisma.user.findMany({
            where: { businessId: business.id, isActive: true },
        });
        // 3. Girilen PIN kodunu personellerin hash'li PIN'leriyle eşleştir
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
        // 4. Role ve kullanıcıya ait yetkileri hesapla
        const permissions = getPermissionsForUser(matchedUser.role, matchedUser.customPermissions);
        // 5. JWT Token üret (yetkiler token içine de gömülür)
        const token = signToken({
            userId: matchedUser.id,
            businessId: business.id,
            role: matchedUser.role,
            fullName: matchedUser.fullName,
            permissions,
        });
        // 6. Mobil uygulamanın ihtiyaç duyacağı kullanıcı profilini ve yetkilerini dön
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
                },
                business: {
                    id: business.id,
                    name: business.name,
                    slug: business.slug,
                    currency: business.currency,
                },
            },
        });
    }
    catch (error) {
        console.error('Login Hatası:', error);
        res.status(500).json({
            success: false,
            error: 'Sunucu hatası: Giriş işlemi gerçekleştirilemedi.',
        });
    }
}
// Token doğrulama ve mevcut kullanıcı profilini getirme rotası
export async function getProfile(req, res) {
    if (!req.user) {
        res.status(401).json({ success: false, error: 'Oturum bulunamadı.' });
        return;
    }
    res.json({
        success: true,
        data: req.user,
    });
}
