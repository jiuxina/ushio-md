import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/constants.dart';

/// 成绩录入页面
///
/// 提供课程选择、学生成绩录入和自定义数字键盘。
class GradeEntryScreen extends StatefulWidget {
  const GradeEntryScreen({super.key});

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  String _selectedCourse = '高等数学 A';
  final List<String> _courses = [
    '高等数学 A',
    '大学英语 III',
    '线性代数',
    '概率论与数理统计',
    '数据结构',
  ];

  late final List<_StudentGrade> _students;
  int? _activeStudentIndex;
  final FocusNode _hiddenFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _students = [
      _StudentGrade(name: '张三', studentId: '2021001'),
      _StudentGrade(name: '李四', studentId: '2021002'),
      _StudentGrade(name: '王五', studentId: '2021003'),
      _StudentGrade(name: '赵六', studentId: '2021004'),
      _StudentGrade(name: '刘七', studentId: '2021005'),
      _StudentGrade(name: '陈八', studentId: '2021006'),
      _StudentGrade(name: '杨九', studentId: '2021007'),
      _StudentGrade(name: '黄十', studentId: '2021008'),
    ];
  }

  @override
  void dispose() {
    _hiddenFocus.dispose();
    for (final s in _students) {
      s.controller.dispose();
    }
    super.dispose();
  }

  // ==================== Stats ====================

  List<double> get _validScores => _students
      .where((s) => s.score != null)
      .map((s) => s.score!)
      .toList();

  double get _average {
    final scores = _validScores;
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  double get _highest {
    final scores = _validScores;
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a > b ? a : b);
  }

  double get _lowest {
    final scores = _validScores;
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a < b ? a : b);
  }

  String get _passRate {
    final scores = _validScores;
    if (scores.isEmpty) return '0.0';
    final passed = scores.where((s) => s >= 60).length;
    return (passed / scores.length * 100).toStringAsFixed(1);
  }

  // ==================== Keypad ====================

  void _onKeyTap(String key) {
    if (_activeStudentIndex == null) return;
    final student = _students[_activeStudentIndex!];
    setState(() {
      if (key == '⌫') {
        if (student.controller.text.isNotEmpty) {
          student.controller.text = student.controller.text
              .substring(0, student.controller.text.length - 1);
        }
      } else if (key == '✓') {
        _activeStudentIndex = null;
      } else {
        // Prevent scores > 100 and multiple decimals
        final newText = student.controller.text + key;
        if (key == '.' && student.controller.text.contains('.')) return;
        final parsed = double.tryParse(newText);
        if (parsed != null && parsed > 100) return;
        student.controller.text = newText;
      }
      student.score = double.tryParse(student.controller.text);
    });
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩录入'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                const SizedBox(height: 16),
                _buildCourseSelector(context),
                const SizedBox(height: 16),
                _buildStudentGradeList(context),
                const SizedBox(height: 16),
                _buildStatistics(context),
                const SizedBox(height: 16),
                _buildSubmitButton(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_activeStudentIndex != null) _buildCustomKeypad(context),
        ],
      ),
    );
  }

  // ==================== Course Selector ====================

  Widget _buildCourseSelector(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCourse,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: _courses.map((c) {
            return DropdownMenuItem<String>(value: c, child: Text(c));
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCourse = v);
          },
        ),
      ),
    );
  }

  // ==================== Student Grade List ====================

  Widget _buildStudentGradeList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _students.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          final isLast = index == _students.length - 1;
          final isActive = _activeStudentIndex == index;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _activeStudentIndex = index);
                },
                child: Container(
                  color: isActive
                      ? AppConstants.primaryColor.withValues(alpha: 0.05)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppConstants.primaryColor
                            .withValues(alpha: 0.15),
                        child: Text(
                          student.name[0],
                          style: const TextStyle(
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              student.studentId,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppConstants.primaryColor
                                    .withValues(alpha: 0.1)
                                : cs.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? AppConstants.primaryColor
                                  : theme.dividerColor
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            student.controller.text.isEmpty
                                ? '—'
                                : student.controller.text,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: student.score != null &&
                                      student.score! < 60
                                  ? AppConstants.errorColor
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ==================== Statistics ====================

  Widget _buildStatistics(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
              context, _average.toStringAsFixed(1), '平均分', AppConstants.primaryColor),
          _buildStatDivider(context),
          _buildStatItem(
              context, _highest.toStringAsFixed(0), '最高分', AppConstants.successColor),
          _buildStatDivider(context),
          _buildStatItem(
              context, _lowest.toStringAsFixed(0), '最低分', AppConstants.warningColor),
          _buildStatDivider(context),
          _buildStatItem(
              context, '$_passRate%', '及格率', AppConstants.accentColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
    );
  }

  // ==================== Submit ====================

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('成绩已提交')),
          );
        },
        icon: const Icon(Icons.upload_rounded),
        label: const Text('全部提交'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ==================== Custom Keypad ====================

  Widget _buildCustomKeypad(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      '.', '0', '⌫',
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.2,
              ),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                return _buildKeyButton(context, key);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8)
                  .copyWith(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _onKeyTap('✓'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('完成'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyButton(BuildContext context, String key) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBackspace = key == '⌫';

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.lightImpact();
          _onKeyTap(key);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: isBackspace
                ? Icon(Icons.backspace_outlined,
                    size: 20, color: cs.onSurface)
                : Text(
                    key,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ==================== Helper Classes ====================

class _StudentGrade {
  final String name;
  final String studentId;
  final TextEditingController controller;
  double? score;

  _StudentGrade({
    required this.name,
    required this.studentId,
    double? initialScore,
  })  : controller = TextEditingController(
            text: initialScore?.toString() ?? ''),
        score = initialScore;
}
