import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_message.dart';
import '../../../providers/ai_provider.dart';
import '../../../utils/constants.dart';

/// AI 助理聊天界面
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<AiProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppConstants.animationDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ======================== build ========================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConstants.primaryColor.withValues(alpha: 0.2),
                    AppConstants.accentColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            const Text('相思 AI 助理'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.read<AiProvider>().clearChat(),
            child: Text(
              '清空',
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatArea(theme, cs)),
          _buildQuickPrompts(theme, cs),
          _buildInputArea(theme, cs),
        ],
      ),
    );
  }

  // ==================== chat area ====================

  Widget _buildChatArea(ThemeData theme, ColorScheme cs) {
    final ai = context.watch<AiProvider>();
    final messages = ai.messages;

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor.withValues(alpha: 0.15),
                      AppConstants.accentColor.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  size: 48,
                  color: AppConstants.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '你好！我是相思 AI 助理 🤖\n有什么可以帮你的吗？',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.outline,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.role == 'user') {
          return _buildUserBubble(msg, theme, cs);
        }
        return _buildAssistantBubble(msg, theme, cs);
      },
    );
  }

  // ==================== user bubble ====================

  Widget _buildUserBubble(ChatMessage msg, ThemeData theme, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.content,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  // ==================== assistant bubble ====================

  Widget _buildAssistantBubble(
      ChatMessage msg, ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message text with optional blinking cursor
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                    children: [
                      TextSpan(text: msg.content),
                      if (msg.isStreaming)
                        const TextSpan(
                          text: ' █',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                // Special card rendering
                if (msg.cardType == 'leave_form' && !msg.isStreaming)
                  _buildLeaveFormCard(theme, cs),
                if (msg.cardType == 'schedule' && !msg.isStreaming)
                  _buildScheduleCard(theme, cs),
              ],
            ),
          ),
          // Action buttons below assistant message
          if (!msg.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: msg.liked == true
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    color: msg.liked == true
                        ? AppConstants.primaryColor
                        : cs.outline,
                    onTap: () =>
                        context.read<AiProvider>().toggleLike(msg.id),
                  ),
                  const SizedBox(width: 12),
                  _ActionIcon(
                    icon: Icons.thumb_down_outlined,
                    color: cs.outline,
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  _ActionIcon(
                    icon: Icons.refresh_rounded,
                    color: cs.outline,
                    onTap: () =>
                        context.read<AiProvider>().regenerateLastResponse(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== leave form card ====================

  Widget _buildLeaveFormCard(ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: AppConstants.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded,
                  size: 18, color: AppConstants.primaryColor),
              const SizedBox(width: 6),
              Text(
                '请假申请',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FormFieldRow(label: '请假类型', hint: '事假 / 病假 / 公假'),
          const SizedBox(height: 8),
          _FormFieldRow(label: '开始日期', hint: '请选择日期'),
          const SizedBox(height: 8),
          _FormFieldRow(label: '结束日期', hint: '请选择日期'),
          const SizedBox(height: 8),
          _FormFieldRow(label: '请假事由', hint: '请输入原因'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('一键提交'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== schedule card ====================

  Widget _buildScheduleCard(ThemeData theme, ColorScheme cs) {
    final colors = [
      AppConstants.primaryColor,
      AppConstants.successColor,
      AppConstants.warningColor,
      AppConstants.accentColor,
    ];
    final courses = [
      {'name': '高等数学', 'time': '08:00-09:35', 'loc': '理工楼 A301'},
      {'name': '大学英语', 'time': '10:00-11:35', 'loc': '文科楼 B201'},
      {'name': '数据结构', 'time': '14:00-15:35', 'loc': '计算机楼 C102'},
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: AppConstants.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppConstants.accentColor),
              const SizedBox(width: 6),
              Text(
                '今日课表',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(courses.length, (i) {
            final c = courses[i];
            final color = colors[i % colors.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name']!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${c['time']}  ${c['loc']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== quick prompts ====================

  Widget _buildQuickPrompts(ThemeData theme, ColorScheme cs) {
    final prompts = ['帮我查成绩', '我要请假', '今天有什么课', '查场馆', '心理咨询'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: prompts.map((p) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  p,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor:
                    AppConstants.primaryColor.withValues(alpha: 0.08),
                side: BorderSide(
                  color: AppConstants.primaryColor.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: () {
                  context.read<AiProvider>().sendMessage(p);
                  _scrollToBottom();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================== input area ====================

  Widget _buildInputArea(ThemeData theme, ColorScheme cs) {
    final ai = context.watch<AiProvider>();

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          // Microphone button
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            color: cs.outline,
            onPressed: () => _showVoiceOverlay(context),
          ),
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '输入你的问题…',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Send button
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: ai.isProcessing
                ? cs.outline
                : AppConstants.primaryColor,
            onPressed: ai.isProcessing ? null : _send,
          ),
        ],
      ),
    );
  }

  // ==================== voice overlay ====================

  void _showVoiceOverlay(BuildContext context) {
    final ai = context.read<AiProvider>();
    ai.startListening();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _VoiceInputSheet(),
    ).whenComplete(() {
      ai.stopListening();
    });
  }
}

// ========================================================================
// Private helper widgets
// ========================================================================

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _FormFieldRow extends StatelessWidget {
  final String label;
  final String hint;

  const _FormFieldRow({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.5),
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== voice input bottom sheet ====================

class _VoiceInputSheet extends StatefulWidget {
  const _VoiceInputSheet();

  @override
  State<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<_VoiceInputSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          // Microphone icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryColor.withValues(alpha: 0.2),
                  AppConstants.accentColor.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.mic_rounded,
              size: 48,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // Waveform
          SizedBox(
            height: 40,
            width: 200,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WaveformPainter(
                    progress: _waveController.value,
                    color: AppConstants.primaryColor,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '正在聆听...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Cancel button
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: cs.error, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== waveform painter ====================

class _WaveformPainter extends CustomPainter {
  static const double _primaryAmplitude = 8;
  static const double _secondaryAmplitude = 6;

  final double progress;
  final Color color;

  _WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height / 2;

    for (double x = 0; x <= size.width; x += 1) {
      final normalizedX = x / size.width;
      final wave1 = sin(normalizedX * pi * 2) * _primaryAmplitude;
      final wave2 =
          sin(normalizedX * pi * 4 + progress * pi * 2) * _secondaryAmplitude;
      final y = midY + wave1 + wave2;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
