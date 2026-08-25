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
}
