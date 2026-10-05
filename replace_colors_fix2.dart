import 'dart:io';

void main() {
  final files = [
    'pos_mobile/lib/features/manager/audit_log_screen.dart',
    'pos_mobile/lib/features/manager/expense_screen.dart',
    'pos_mobile/lib/order/payment_screen.dart',
    'pos_mobile/lib/features/order/payment_screen.dart',
    'pos_mobile/lib/features/printers/printer_screen.dart',
    'pos_mobile/lib/features/reports/advanced_reports_screen.dart',
    'pos_mobile/lib/features/reports/profitability_screen.dart',
    'pos_mobile/lib/features/waiter/tables_screen.dart',
    'pos_mobile/lib/features/kitchen/kitchen_screen.dart',
  ];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    String content = file.readAsStringSync();

    content = content.replaceAll('const ColorScheme.dark(', 'ColorScheme.dark(');
    content = content.replaceAll('const ColorScheme.light(', 'ColorScheme.light(');

    file.writeAsStringSync(content);
  }
}
