import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final fonts = {
    'NotoSansSC-Regular.ttf': 'https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC-Regular.ttf',
    'NotoSerifSC-Regular.ttf': 'https://github.com/google/fonts/raw/main/ofl/notoserifsc/NotoSerifSC-Regular.ttf',
    'LXGWWenKai-Regular.ttf': 'https://github.com/google/fonts/raw/main/ofl/lxgwwenkai/LXGWWenKai-Regular.ttf',
    // Try static regular for JetBrains Mono, usually inside static folder or at root if legacy
    // But Google Fonts main repo uses variable fonts mostly now.
    // 'JetBrainsMono-Regular.ttf': 'https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf', // This is valid but filename is weird
    'JetBrainsMono-Regular.ttf': 'https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/static/JetBrainsMono-Regular.ttf', 
  };
  
  // Fallback for JetBrains Mono if static not found
  const jbVariableUrl = 'https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf';

  final outputDir = Directory('assets/fonts');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  for (final entry in fonts.entries) {
    var url = entry.value;
    final filename = entry.key;
    print('Downloading $filename from $url ...');
    
    try {
      var response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200 && filename.contains('JetBrains')) {
         print('Failed to get JetBrains static, trying variable font...');
         url = jbVariableUrl;
         response = await http.get(Uri.parse(url));
      }

      if (response.statusCode == 200) {
        final file = File('${outputDir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        print('Saved to ${file.path} (${response.bodyBytes.length} bytes)');
      } else {
        print('Failed to download $filename: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading $filename: $e');
    }
  }
}
