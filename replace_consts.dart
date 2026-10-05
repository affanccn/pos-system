import 'dart:io';

void main() {
  final dir = Directory('pos_mobile/lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (final file in files) {
    String content = file.readAsStringSync();
    String originalContent = content;

    content = content.replaceAll('const DropdownMenuItem(', 'DropdownMenuItem(');
    content = content.replaceAll('const IconThemeData(', 'IconThemeData(');
    content = content.replaceAll('const FloatingActionButton(', 'FloatingActionButton(');
    content = content.replaceAll('const Scaffold(', 'Scaffold(');
    content = content.replaceAll('const AppBar(', 'AppBar(');
    content = content.replaceAll('const Row(', 'Row(');
    content = content.replaceAll('const Column(', 'Column(');
    content = content.replaceAll('const Stack(', 'Stack(');
    content = content.replaceAll('const ListView(', 'ListView(');
    content = content.replaceAll('const GridView(', 'GridView(');
    content = content.replaceAll('const SingleChildScrollView(', 'SingleChildScrollView(');
    content = content.replaceAll('const Expanded(', 'Expanded(');
    content = content.replaceAll('const SizedBox(', 'SizedBox(');
    content = content.replaceAll('const Card(', 'Card(');
    content = content.replaceAll('const ListTile(', 'ListTile(');
    content = content.replaceAll('const Align(', 'Align(');
    content = content.replaceAll('const CircularProgressIndicator(', 'CircularProgressIndicator(');
    content = content.replaceAll('const ElevatedButton(', 'ElevatedButton(');
    content = content.replaceAll('const OutlinedButton(', 'OutlinedButton(');
    content = content.replaceAll('const TextButton(', 'TextButton(');
    content = content.replaceAll('const IconButton(', 'IconButton(');
    content = content.replaceAll('const InkWell(', 'InkWell(');
    content = content.replaceAll('const Flexible(', 'Flexible(');
    content = content.replaceAll('const Drawer(', 'Drawer(');
    content = content.replaceAll('const DrawerHeader(', 'DrawerHeader(');
    content = content.replaceAll('const Tooltip(', 'Tooltip(');
    content = content.replaceAll('const Divider(', 'Divider(');
    
    if (content != originalContent) {
      file.writeAsStringSync(content);
    }
  }
}
