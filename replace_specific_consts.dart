import 'dart:io';

void main() {
  final files = [
    'pos_mobile/lib/features/manager/staff_screen.dart',
    'pos_mobile/lib/features/order/table_detail_screen.dart',
  ];

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    String content = file.readAsStringSync();
    
    content = content.replaceAll('const PopupMenuItem(', 'PopupMenuItem(');
    content = content.replaceAll('const CircleAvatar(', 'CircleAvatar(');

    file.writeAsStringSync(content);
  }
}
