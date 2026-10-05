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

    // Fix Scaffold backgrounds
    content = content.replaceAll(
        'backgroundColor: const Color(0xFF0B1221)',
        'backgroundColor: Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll(
        'backgroundColor: const Color(0xFF0F172A)',
        'backgroundColor: Theme.of(context).scaffoldBackgroundColor');

    // Fix Card/Surface colors
    content = content.replaceAll(
        'color: const Color(0xFF1E293B)',
        'color: Theme.of(context).cardColor');
    content = content.replaceAll(
        'color: const Color(0xFF162032)',
        'color: Theme.of(context).cardColor');
    content = content.replaceAll(
        'backgroundColor: const Color(0xFF1E293B)',
        'backgroundColor: Theme.of(context).cardColor');

    // For BackdropFilter blocks that use const Color(0xFF1E293B).withValues
    content = content.replaceAll(
        'const Color(0xFF1E293B).withValues',
        'Theme.of(context).cardColor.withValues');

    // Fix borders/dividers
    content = content.replaceAll(
        'color: const Color(0xFF334155)',
        'color: Theme.of(context).dividerColor');
    content = content.replaceAll(
        'color: Color(0xFF334155)',
        'color: Theme.of(context).dividerColor');

    // Fix Text colors
    content = content.replaceAll(
        'color: Colors.white',
        'color: Theme.of(context).colorScheme.onSurface');
    content = content.replaceAll(
        'color: const Color(0xFF94A3B8)',
        'color: Theme.of(context).textTheme.bodyMedium?.color');
    content = content.replaceAll(
        'color: Color(0xFF94A3B8)',
        'color: Theme.of(context).textTheme.bodyMedium?.color');

    // Strip out const where we just injected Theme.of(context)
    // A quick hack is to replace 'const TextStyle(' with 'TextStyle(' etc.
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const Border(', 'Border(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const Divider(', 'Divider(');

    file.writeAsStringSync(content);
  }
}
