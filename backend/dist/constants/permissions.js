export const PERMISSIONS = {
    TABLE_VIEW: 'table.view',
    TABLE_CREATE: 'table.create',
    TABLE_EDIT: 'table.edit',
    TABLE_DELETE: 'table.delete',
    TABLE_TRANSFER: 'table.transfer',
    TABLE_MERGE: 'table.merge',
    TABLE_SPLIT: 'table.split',
    ORDER_CREATE: 'order.create',
    ORDER_EDIT: 'order.edit',
    ORDER_CANCEL: 'order.cancel',
    ORDER_VOID: 'order.void',
    ORDER_DISCOUNT: 'order.discount',
    ORDER_COMPLIMENTARY: 'order.complimentary',
    PAYMENT_CREATE: 'payment.create',
    PAYMENT_REFUND: 'payment.refund',
    PAYMENT_SPLIT: 'payment.split',
    PRODUCT_VIEW: 'product.view',
    PRODUCT_CREATE: 'product.create',
    PRODUCT_EDIT: 'product.edit',
    PRODUCT_DELETE: 'product.delete',
    PRODUCT_PRICE_EDIT: 'product.price_edit',
    STOCK_VIEW: 'stock.view',
    STOCK_CREATE: 'stock.create',
    STOCK_ADJUST: 'stock.adjust',
    REPORT_VIEW: 'report.view',
    REPORT_FINANCIAL: 'report.financial',
    STAFF_VIEW: 'staff.view',
    STAFF_CREATE: 'staff.create',
    STAFF_EDIT: 'staff.edit',
    STAFF_DELETE: 'staff.delete',
    SETTINGS_VIEW: 'settings.view',
    SETTINGS_EDIT: 'settings.edit',
    KITCHEN_VIEW: 'kitchen.view',
    KITCHEN_MANAGE: 'kitchen.manage',
};
export const ROLE_DEFAULT_PERMISSIONS = {
    OWNER: Object.values(PERMISSIONS),
    MANAGER: [
        PERMISSIONS.TABLE_VIEW,
        PERMISSIONS.TABLE_CREATE,
        PERMISSIONS.TABLE_EDIT,
        PERMISSIONS.TABLE_DELETE,
        PERMISSIONS.TABLE_TRANSFER,
        PERMISSIONS.TABLE_MERGE,
        PERMISSIONS.TABLE_SPLIT,
        PERMISSIONS.ORDER_CREATE,
        PERMISSIONS.ORDER_EDIT,
        PERMISSIONS.ORDER_CANCEL,
        PERMISSIONS.ORDER_VOID,
        PERMISSIONS.ORDER_DISCOUNT,
        PERMISSIONS.ORDER_COMPLIMENTARY,
        PERMISSIONS.PAYMENT_CREATE,
        PERMISSIONS.PAYMENT_REFUND,
        PERMISSIONS.PAYMENT_SPLIT,
        PERMISSIONS.PRODUCT_VIEW,
        PERMISSIONS.PRODUCT_CREATE,
        PERMISSIONS.PRODUCT_EDIT,
        PERMISSIONS.PRODUCT_PRICE_EDIT,
        PERMISSIONS.STOCK_VIEW,
        PERMISSIONS.STOCK_CREATE,
        PERMISSIONS.STOCK_ADJUST,
        PERMISSIONS.REPORT_VIEW,
        PERMISSIONS.REPORT_FINANCIAL,
        PERMISSIONS.STAFF_VIEW,
        PERMISSIONS.STAFF_CREATE,
        PERMISSIONS.STAFF_EDIT,
        PERMISSIONS.SETTINGS_VIEW,
        PERMISSIONS.KITCHEN_VIEW,
        PERMISSIONS.KITCHEN_MANAGE,
    ],
    WAITER: [
        PERMISSIONS.TABLE_VIEW,
        PERMISSIONS.TABLE_TRANSFER,
        PERMISSIONS.ORDER_CREATE,
        PERMISSIONS.ORDER_EDIT,
        PERMISSIONS.PAYMENT_CREATE,
        PERMISSIONS.PAYMENT_SPLIT,
        PERMISSIONS.PRODUCT_VIEW,
    ],
    KITCHEN: [
        PERMISSIONS.KITCHEN_VIEW,
        PERMISSIONS.KITCHEN_MANAGE,
        PERMISSIONS.PRODUCT_VIEW,
    ],
};
/**
 * Kullanıcı için atanmış nihai yetki listesini döner.
 * Rol varsayılanlarına ek olarak varsa özel yetkileri de birleştirir.
 */
export function getPermissionsForUser(role, customPermissions) {
    const normalizedRole = role.toUpperCase();
    const basePermissions = ROLE_DEFAULT_PERMISSIONS[normalizedRole] || [];
    if (!customPermissions || customPermissions.length === 0) {
        return basePermissions;
    }
    return customPermissions;
}
