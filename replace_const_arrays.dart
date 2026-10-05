import 'dart:io';

void main() {
  final dir = Directory('pos_mobile/lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  for (final file in files) {
    String content = file.readAsStringSync();
    String originalContent = content;

    content = content.replaceAll('const [', '[');
    content = content.replaceAll('const <Widget>[', '<Widget>[');
    content = content.replaceAll('const <DropdownMenuItem<String>>[', '<DropdownMenuItem<String>>[');
    content = content.replaceAll('const EdgeInsets', 'EdgeInsets');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const Scaffold(', 'Scaffold(');
    
    if (content != originalContent) {
      file.writeAsStringSync(content);
    }
  }
}
