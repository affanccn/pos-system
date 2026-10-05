import 'dart:io';

void main() {
  final dir = Directory('pos_mobile/lib/features');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
  // also add main files or screens outside features if any?
  // Let's stick to features

  for (final file in files) {
    String content = file.readAsStringSync();
    String originalContent = content;

    content = content.replaceAll('color: Colors.white,', 'color: Theme.of(context).colorScheme.onSurface,');
    content = content.replaceAll('color: Colors.white)', 'color: Theme.of(context).colorScheme.onSurface)');
    
    content = content.replaceAll('color: Colors.white70,', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),');
    content = content.replaceAll('color: Colors.white70)', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey))');
    
    content = content.replaceAll('color: Colors.white54,', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54),');
    content = content.replaceAll('color: Colors.white54)', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))');

    content = content.replaceAll('color: Colors.white60,', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.60),');
    content = content.replaceAll('color: Colors.white60)', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.60))');

    content = content.replaceAll('color: Colors.white38,', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38),');
    content = content.replaceAll('color: Colors.white38)', 'color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.38))');

    // Remove any accidental consts created by Theme.of
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const Padding(', 'Padding(');
    content = content.replaceAll('const Center(', 'Center(');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const InputDecoration(', 'InputDecoration(');
    
    if (content != originalContent) {
      file.writeAsStringSync(content);
    }
  }
}
