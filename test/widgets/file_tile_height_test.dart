import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/screens/folder/components/file_tile.dart';
import 'package:mdreader/utils/app_style.dart';

void main() {
  testWidgets('FileTile 高度不随文件/文件夹/拖拽手柄变化', (tester) async {
    final dir = Directory.systemTemp.createTempSync('file_tile_height_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/note.md')..writeAsStringSync('# hi');

    final appStyle = AppStyleTheme.resolve(
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(),
      textSecondary: Colors.black45,
      buttonStyleMode: AppButtonStyleMode.softShadow,
      cardOpacity: 1,
    );

    Future<double> heightOf(Widget widget) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [appStyle]),
          home: Scaffold(
            body: SizedBox(width: 360, child: widget),
          ),
        ),
      );
      return tester.getSize(find.byType(FileTile)).height;
    }

    final folderHeight = await heightOf(FileTile(entity: dir));
    final fileHeight = await heightOf(FileTile(entity: file));
    final draggableHeight = await heightOf(
      FileTile(entity: file, isDraggable: true, index: 0),
    );

    expect(folderHeight, closeTo(fileHeight, 0.01));
    expect(draggableHeight, closeTo(fileHeight, 0.01));
  });
}
