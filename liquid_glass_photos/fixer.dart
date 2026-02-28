import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content = await file.readAsString();
    if (content.contains('.withOpacity(')) {
      final replaced = content.replaceAllMapped(
        RegExp(r'\.withOpacity\(\s*([^)]+)\s*\)'),
         (match) => '.withValues(alpha: ${match.group(1)})',
      );
      if (replaced != content) {
        await file.writeAsString(replaced);
        print('Updated ${file.path}');
      }
    }
  }
}
