class AppPermissions {
  static const String tableView = 'table.view';
  static const String tableCreate = 'table.create';
  static const String tableEdit = 'table.edit';
  static const String tableDelete = 'table.delete';
  static const String tableTransfer = 'table.transfer';
  static const String tableMerge = 'table.merge';
  static const String tableSplit = 'table.split';

  static const String orderCreate = 'order.create';
  static const String orderEdit = 'order.edit';
  static const String orderCancel = 'order.cancel';
  static const String orderVoid = 'order.void';
  static const String orderDiscount = 'order.discount';
  static const String orderComplimentary = 'order.complimentary';

  static const String paymentCreate = 'payment.create';
  static const String paymentRefund = 'payment.refund';
  static const String paymentSplit = 'payment.split';

  static const String productView = 'product.view';
  static const String productCreate = 'product.create';
  static const String productEdit = 'product.edit';
  static const String productDelete = 'product.delete';
  static const String productPriceEdit = 'product.price_edit';

  static const String stockView = 'stock.view';
  static const String stockCreate = 'stock.create';
  static const String stockAdjust = 'stock.adjust';

  static const String reportView = 'report.view';
  static const String reportFinancial = 'report.financial';

  static const String staffView = 'staff.view';
  static const String staffCreate = 'staff.create';
  static const String staffEdit = 'staff.edit';
  static const String staffDelete = 'staff.delete';

  static const String settingsView = 'settings.view';
  static const String settingsEdit = 'settings.edit';

  static const String kitchenView = 'kitchen.view';
  static const String kitchenManage = 'kitchen.manage';
}

class AppRoles {
  static const String owner = 'OWNER';
  static const String manager = 'MANAGER';
  static const String waiter = 'WAITER';
  static const String kitchen = 'KITCHEN';

  static String getRoleLabel(String? role) {
    switch (role?.toUpperCase()) {
      case owner:
        return 'Patron';
      case manager:
        return 'Müdür';
      case waiter:
        return 'Garson';
      case kitchen:
        return 'Mutfak';
      default:
        return role ?? 'Personel';
    }
  }
}
