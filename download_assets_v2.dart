import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const mirror = 'https://gstatic.qaq.qa';
  
  final fontsToDownload = {
    'Noto Sans SC': 'NotoSansSC-Regular.ttf',
    'Noto Serif SC': 'NotoSerifSC-Regular.ttf',
    'LXGW WenKai': 'LXGWWenKai-Regular.ttf',
    'JetBrains Mono': 'JetBrainsMono-Regular.ttf',
  };

  final outputDir = Directory('assets/fonts');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  for (final entry in fontsToDownload.entries) {
    var fontFamily = entry.key;
    final fileName = entry.value;
    
    // Check if file already exists
    final file = File('${outputDir.path}/$fileName');
    if (file.existsSync() && file.lengthSync() > 0) {
      print('$fileName already exists, skipping.');
      continue;
    }
    
    print('Processing $fontFamily ...');
    
    try {
      final familyParam = fontFamily.replaceAll(' ', '+');
      final cssUrl = '$mirror/css2?family=$familyParam:wght@400';
      
      print('  Get CSS: $cssUrl');
      final cssResponse = await http.get(Uri.parse(cssUrl));
      
      if (cssResponse.statusCode != 200) {
        print('  Failed to get CSS: ${cssResponse.statusCode}');
        // Try fallback for LXGW WenKai if failed
        if (fontFamily == 'LXGW WenKai') {
           print('  Retrying with "Ma Shan Zheng" as fallback...');
           fontFamily = 'Ma Shan Zheng'; // Google Fonts equivalent-ish? Or maybe it doesn't exist yet on mirror
           // Actually LXGW WenKai is surprisingly new.
           // Let's try Ma Shan Zheng anyway if LXGW fails.
           final altParam = 'Ma+Shan+Zheng';
           final altUrl = '$mirror/css2?family=$altParam:wght@400';
           final altResponse = await http.get(Uri.parse(altUrl));
           if (altResponse.statusCode == 200) {
             print('  Fallback CSS found.');
             // Process fallback...
             await _processCss(altResponse.body, file, mirror);
             continue;
           }
        }
        continue;
      }
      
      await _processCss(cssResponse.body, file, mirror);
      
    } catch (e) {
      print('  Error: $e');
    }
  }
}

Future<void> _processCss(String cssContent, File outputFile, String mirror) async {
  // Regex extracting url
  final match = RegExp(r'url\(([^)]+)\)').firstMatch(cssContent);
  if (match == null) {
    print('  No URL found in CSS');
    return;
  }
  
  String url = match.group(1)!.trim();
  if ((url.startsWith('"') && url.endsWith('"')) || 
      (url.startsWith("'") && url.endsWith("'"))) {
    url = url.substring(1, url.length - 1);
  }
  
  // Replace domain if google
  if (url.contains('fonts.gstatic.com')) {
     final mirrorUri = Uri.parse(mirror);
     final fontUri = Uri.parse(url);
     url = fontUri.replace(scheme: mirrorUri.scheme, host: mirrorUri.host).toString();
  }
  
  print('  Downloading font from: $url');
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    await outputFile.writeAsBytes(response.bodyBytes);
    print('  Saved to ${outputFile.path} (${response.bodyBytes.length} bytes)');
  } else {
    print('  Download failed: ${response.statusCode}');
  }
}
