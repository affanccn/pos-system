import { prisma } from '../config/prisma.js';
export async function createAuditLog(params) {
    try {
        await prisma.auditLog.create({
            data: {
                businessId: params.businessId,
                userId: params.userId || null,
                action: params.action,
                entity: params.entity || null,
                entityId: params.entityId || null,
                oldValue: params.oldValue || null,
                newValue: params.newValue || null,
                description: params.description || null,
                details: params.details || null,
            }
        });
    }
    catch (error) {
        console.error('Audit log olusturulamadi:', error);
    }
}
