import 'dart:io';

void main() {
  final file = File('pos_mobile/lib/features/order/order_screen.dart');
  if (file.existsSync()) {
    String content = file.readAsStringSync();
    content = content.replaceAll('color: isSelected ? Colors.black : Colors.white70,', 'color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface,');
    file.writeAsStringSync(content);
  }
}
