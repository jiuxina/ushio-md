// 内阴影回归测试
//
// 卡片填充是半透明的，BoxShadow 画在填充之下会透出来，在卡片内部留下
// 一圈明暗不均的暗带（就是用户反馈的内阴影）。OuterShadow 把阴影裁到
// 外侧，因此卡片内部必须完全均匀，同时外侧仍然要能看到阴影。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/widgets/outer_shadow.dart';

const _page = Size(400, 400);
const _cardTop = 120.0;
const _cardHeight = 160.0;
const _cardWidth = 240.0;

const _radius = BorderRadius.all(Radius.circular(12));

/// 与 AppStyleTheme.surfaceShadow 同量级的阴影
const _shadows = [
  BoxShadow(
    color: Color(0x3D000000),
    blurRadius: 24,
    offset: Offset(0, 10),
    spreadRadius: -14,
  ),
];

/// 半透明红：白底上绿色通道恒为 127/128，任何透出都会把它压暗
const _fill = Color(0x80FF0000);

/// flutter_test 默认关掉阴影渲染，测之前必须打开、测完立刻还原：
/// 框架在测试体结束时校验 painting debug 变量有没有被改，addTearDown 还原得太晚。
Future<T> _withShadows<T>(Future<T> Function() body) async {
  debugDisableShadows = false;
  try {
    return await body();
  } finally {
    debugDisableShadows = true;
  }
}

Future<Uint8List> _rasterize(WidgetTester tester, Widget card) async {
  tester.view.physicalSize = _page;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: Colors.white,
        child: SizedBox(
          width: _page.width,
          height: _page.height,
          child: Center(child: card),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return _withShadows(() async {
    // 光栅化要真实异步完成，FakeAsync 下直接 await 会一直挂到超时
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return pixels!;
  });
}

int _green(Uint8List pixels, int x, int y) => pixels[(y * 400 + x) * 4 + 1];

/// 卡片内部采样：上沿内侧、正中、下沿内侧、左右各一处
List<int> _interior(Uint8List pixels) => [
  _green(pixels, 200, 128),
  _green(pixels, 200, 200),
  _green(pixels, 200, 272),
  _green(pixels, 120, 200),
  _green(pixels, 280, 200),
];

int _spread(List<int> values) =>
    values.reduce((a, b) => a > b ? a : b) -
    values.reduce((a, b) => a < b ? a : b);

void main() {
  testWidgets('BoxShadow 透进半透明填充，卡片内部明暗不均（内阴影病灶）', (
    WidgetTester tester,
  ) async {
    final pixels = await _rasterize(
      tester,
      Container(
        width: _cardWidth,
        height: _cardHeight,
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: _radius,
          boxShadow: _shadows,
        ),
      ),
    );

    final samples = _interior(pixels);
    // 对照组必须真的能测出透出，否则下面的均匀断言是空测
    expect(_spread(samples), greaterThan(10), reason: 'samples=$samples');
  });

  testWidgets('OuterShadow 卡片内部完全均匀，阴影只留在外侧', (
    WidgetTester tester,
  ) async {
    final pixels = await _rasterize(
      tester,
      OuterShadow(
        shadows: _shadows,
        borderRadius: _radius,
        child: Container(
          width: _cardWidth,
          height: _cardHeight,
          color: _fill,
        ),
      ),
    );

    final samples = _interior(pixels);
    expect(_spread(samples), lessThanOrEqualTo(2), reason: 'samples=$samples');

    // 卡片下沿外侧必须有阴影，证明是改成了外阴影而不是把阴影删掉
    final outsideBelow = _green(
      pixels,
      200,
      (_cardTop + _cardHeight + 12).round(),
    );
    expect(
      outsideBelow,
      lessThan(250),
      reason: '外侧没有投影，阴影被裁没了：outsideBelow=$outsideBelow',
    );
  });
}
