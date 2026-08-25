import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/widgets/sliding_segment_toggle.dart';

class _ToggleHarness extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onChanged;

  const _ToggleHarness({required this.initialIndex, this.onChanged});

  @override
  State<_ToggleHarness> createState() => _ToggleHarnessState();
}

class _ToggleHarnessState extends State<_ToggleHarness> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 40,
      child: SlidingSegmentToggle(
        selectedIndex: _index,
        onChanged: (index) {
          widget.onChanged?.call(index);
          setState(() => _index = index);
        },
        items: const [
          SlidingSegmentItem(icon: Icons.description, label: 'File'),
          SlidingSegmentItem(icon: Icons.folder, label: 'Folder'),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpToggle(
    WidgetTester tester, {
    required int selectedIndex,
    ValueChanged<int>? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: _ToggleHarness(
              initialIndex: selectedIndex,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('渲染两个选项且滑块对准选中项', (tester) async {
    await pumpToggle(tester, selectedIndex: 0);

    expect(find.text('File'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);

    final pillFinder = find.byKey(const ValueKey('sliding_segment_pill'));
    final toggleRect = tester.getRect(find.byType(SlidingSegmentToggle));
    final firstSlotCenter = toggleRect.left + toggleRect.width / 4;
    expect(tester.getCenter(pillFinder).dx, closeTo(firstSlotCenter, 2.0));
  });

  testWidgets('点击选项会触发 onChanged', (tester) async {
    int? changed;
    await pumpToggle(tester, selectedIndex: 0, onChanged: (i) => changed = i);

    await tester.tap(find.text('Folder'));
    await tester.pump();

    expect(changed, 1);
  });

  testWidgets('按住滑块拖动会缩放并切换到最近选项', (tester) async {
    int? changed;
    await pumpToggle(tester, selectedIndex: 0, onChanged: (i) => changed = i);

    final pillFinder = find.byKey(const ValueKey('sliding_segment_pill'));
    final gesture = await tester.startGesture(tester.getCenter(pillFinder));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      lessThan(1.0),
    );

    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changed, 1);
    final toggleRect = tester.getRect(find.byType(SlidingSegmentToggle));
    final secondSlotCenter = toggleRect.left + toggleRect.width * 3 / 4;
    expect(tester.getCenter(pillFinder).dx, closeTo(secondSlotCenter, 2.0));
  });
}
