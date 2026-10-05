import 'dart:io';

void main() {
  final files = [
    'pos_mobile/lib/features/manager/manager_dashboard_screen.dart',
    'pos_mobile/lib/features/waiter/tables_screen.dart',
  ];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    String content = file.readAsStringSync();

    content = content.replaceAll(
        'onSurface70',
        'onSurface.withValues(alpha: 0.7)');
    content = content.replaceAll(
        'onSurface38',
        'onSurface.withValues(alpha: 0.38)');
    
    // Also remove any remaining const on Text, Icon, Padding, Center
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const Center(', 'Center(');
    content = content.replaceAll('const EdgeInsets', 'EdgeInsets');

    file.writeAsStringSync(content);
  }
}
