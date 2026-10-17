// 历史页「文件/文件夹」切换按钮的溢出回归测试
//
// 这个按钮只放图标：包内 GlassSegmentedControl 一旦同时给 icon 和 label，就会
// 竖排成「16 图标 + 2 间距 + 标签行盒」，而标签行盒由字体度量决定（中文字体约
// 1.46em），固定 height 会被撑破，设备上的表现就是 BOTTOM OVERFLOWED BY 1.00
// PIXELS。改成纯图标后内容高与文字无关，这里跨系统字号缩放档把这条不变量钉住。
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/widgets/sliding_segment_toggle.dart';

Widget _glass(double scale) => _host(
  scale,
  SizedBox(
    width: 88,
    child: GlassSegmentedControl(
      height: 40,
      selectedIndex: 0,
      onSegmentSelected: (_) {},
      segments: const [
        GlassSegment(icon: Icon(Icons.description), semanticLabel: '文件'),
        GlassSegment(icon: Icon(Icons.folder), semanticLabel: '文件夹'),
      ],
    ),
  ),
);

Widget _sliding(double scale) => _host(
  scale,
  SizedBox(
    width: 88,
    child: SlidingSegmentToggle(
      width: 88,
      height: 36,
      selectedIndex: 0,
      onChanged: (_) {},
      items: const [
        SlidingSegmentItem(icon: Icons.description, semanticLabel: '文件'),
        SlidingSegmentItem(icon: Icons.folder, semanticLabel: '文件夹'),
      ],
    ),
  ),
);

Widget _host(double scale, Widget child) => MaterialApp(
  home: Scaffold(
    body: MediaQuery.withClampedTextScaling(
      minScaleFactor: scale,
      maxScaleFactor: scale,
      child: Center(child: child),
    ),
  ),
);

void main() {
  for (final scale in [1.0, 1.6, 2.4, 3.0]) {
    testWidgets('液态玻璃档 系统字号 $scale 倍不溢出', (tester) async {
      await tester.pumpWidget(_glass(scale));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('简洁立体档 系统字号 $scale 倍不溢出', (tester) async {
      await tester.pumpWidget(_sliding(scale));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
