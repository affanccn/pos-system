import { verifyToken } from '../utils/jwt.js';
export function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({
            success: false,
            error: 'Yetkisiz erişim: Oturum anahtarı (Token) eksik.',
        });
        return;
    }
    const token = authHeader.split(' ')[1];
    try {
        const decoded = verifyToken(token);
        req.user = decoded;
        next();
    }
    catch (error) {
        res.status(401).json({
            success: false,
            error: 'Geçersiz veya süresi dolmuş oturum anahtarı.',
        });
    }
}
/**
 * Belirli rollere sahip kullanıcıların erişimini denetleyen middleware.
 */
export function requireRole(allowedRoles) {
    return (req, res, next) => {
        if (!req.user) {
            res.status(401).json({
                success: false,
                error: 'Oturum bilgisi bulunamadı.',
            });
            return;
        }
        const userRole = req.user.role.toUpperCase();
        const isAllowed = allowedRoles.map((r) => r.toUpperCase()).includes(userRole);
        if (!isAllowed) {
            res.status(403).json({
                success: false,
                error: `Bu işlem için yetkiniz yok. (Gerekli rol: ${allowedRoles.join(', ')})`,
            });
            return;
        }
        next();
    };
}
/**
 * İnce taneli yetki kontrolü yapan middleware.
 * OWNER rolü tüm yetkilere doğrudan erişebilir.
 */
export function requirePermission(permission) {
    const requiredList = Array.isArray(permission) ? permission : [permission];
    return (req, res, next) => {
        if (!req.user) {
            res.status(401).json({
                success: false,
                error: 'Oturum bilgisi bulunamadı.',
            });
            return;
        }
        if (req.user.role.toUpperCase() === 'OWNER') {
            return next();
        }
        const userPermissions = req.user.permissions || [];
        const hasAllRequired = requiredList.every((p) => userPermissions.includes(p));
        if (!hasAllRequired) {
            res.status(403).json({
                success: false,
                error: `Bu işlem için yetkiniz bulunmuyor. (Gerekli Yetki: ${requiredList.join(', ')})`,
            });
            return;
        }
        next();
    };
}
