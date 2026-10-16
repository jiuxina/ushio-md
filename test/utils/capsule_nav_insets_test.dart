import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/utils/capsule_nav_insets.dart';
import 'package:mdreader/widgets/capsule_tab_bar_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('无作用域时返回 0', (tester) async {
    double value = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            value = capsuleTabBarBottomInset(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(value, 0);
  });

  testWidgets('读取作用域提供的动态测量余量', (tester) async {
    double value = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CapsuleTabBarScope(
          inset: 123,
          child: Builder(
            builder: (context) {
              value = capsuleTabBarBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(value, 123);
  });

  testWidgets('二级页取系统导航栏的真实占用', (tester) async {
    double value = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(bottom: 48),
          ),
          child: Builder(
            builder: (context) {
              value = systemNavBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    // padding 会被祖先 SafeArea 清零，viewPadding 才是系统导航栏的真实占用。
    expect(value, 48);
  });

  testWidgets('胶囊只补自带留白不够的那一段', (tester) async {
    Future<double> liftFor(double navInset) async {
      double value = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: navInset),
            ),
            child: Builder(
              builder: (context) {
                value = capsuleBottomLift(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return value;
    }

    expect(await liftFor(0), 0); // 没有系统占用就不抬
    expect(await liftFor(15), 0); // 胶囊自带的 15dp 已经够
    expect(await liftFor(48), 33); // 三键横条：只补差额
  });
}
