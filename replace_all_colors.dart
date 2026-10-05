import 'dart:io';

void main() {
  final dir = Directory('pos_mobile/lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (final file in files) {
    String content = file.readAsStringSync();
    
    // Check if the file contains any of the target colors before modifying
    if (!content.contains('0xFF0B1221') && 
        !content.contains('0xFF0F172A') && 
        !content.contains('0xFF1E293B') && 
        !content.contains('0xFF162032') && 
        !content.contains('0xFF334155') && 
        !content.contains('0xFF94A3B8') &&
        !content.contains('0xFFF8FAFC')) {
      continue;
    }

    content = content.replaceAll(RegExp(r'(const\s+)?Color\(0xFF0B1221\)'), 'Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll(RegExp(r'(const\s+)?Color\(0xFF0F172A\)'), 'Theme.of(context).scaffoldBackgroundColor');
    content = content.replaceAll(RegExp(r'(const\s+)?Color\(0xFF1E293B\)'), 'Theme.of(context).cardColor');
    content = content.replaceAll(RegExp(r'(const\s+)?Color\(0xFF162032\)'), 'Theme.of(context).cardColor');
    content = content.replaceAll(RegExp(r'(const\s+)?Color\(0xFF334155\)'), 'Theme.of(context).dividerColor');
    content = content.replaceAll(RegExp(r'(const\s+)?Color\(0xFF94A3B8\)'), '(Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)');
    
    // Strip const from decorators
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const Border(', 'Border(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const Divider(', 'Divider(');
    content = content.replaceAll('const InputDecoration(', 'InputDecoration(');
    content = content.replaceAll('const EdgeInsets', 'EdgeInsets');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const Center(', 'Center(');
    content = content.replaceAll('const Expanded(', 'Expanded(');
    content = content.replaceAll('const Spacer(', 'Spacer(');

    file.writeAsStringSync(content);
  }
}
