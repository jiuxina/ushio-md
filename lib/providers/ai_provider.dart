import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';

/// AI 助理状态提供者
///
/// 管理聊天消息、语音输入状态和模拟 AI 响应流式输出。
class AiProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _isListening = false;
  String? _error;

  Timer? _streamTimer;
  int _idCounter = 0;

  List<ChatMessage> get messages => _messages;
  bool get isProcessing => _isProcessing;
  bool get isListening => _isListening;
  String? get error => _error;

  // ==================== 消息发送 ====================

  /// Sends a user message and simulates a streaming AI response.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _error = null;

    // Add user message immediately
    final userMsg = ChatMessage(
      id: _nextId(),
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    _messages.add(userMsg);
    _isProcessing = true;
    notifyListeners();

    // Determine canned response
    final response = _cannedResponse(text.trim());
    final cardType = _detectCardType(text.trim());

    // Delay before starting the stream
    await Future.delayed(const Duration(milliseconds: 500));

    // Create the assistant message placeholder
    final assistantId = _nextId();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      cardType: cardType,
    );
    _messages.add(assistantMsg);
    notifyListeners();

    // Stream response character by character
    int charIndex = 0;
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (charIndex >= response.length) {
          timer.cancel();
          _updateAssistantMessage(
            assistantId,
            response,
            isStreaming: false,
          );
          _isProcessing = false;
          notifyListeners();
          return;
        }
        charIndex++;
        _updateAssistantMessage(
          assistantId,
          response.substring(0, charIndex),
          isStreaming: true,
        );
        notifyListeners();
      },
    );
  }

  // ==================== 重新生成 ====================

  /// Removes the last assistant message and re-generates a response.
  Future<void> regenerateLastResponse() async {
    if (_messages.isEmpty) return;

    _streamTimer?.cancel();

    // Find the last assistant message and the user message before it
    String? lastUserText;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'assistant') {
        _messages.removeAt(i);
        break;
      }
    }
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        lastUserText = _messages[i].content;
        break;
      }
    }

    _isProcessing = false;
    notifyListeners();

    if (lastUserText != null) {
      await sendMessage(lastUserText);
    }
  }

  // ==================== 点赞 ====================

  /// Toggles the liked state of a message.
  void toggleLike(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final msg = _messages[index];
    final newLiked = msg.liked == true ? null : true;
    _messages[index] = msg.copyWith(liked: newLiked);
    notifyListeners();
  }

  // ==================== 清空 ====================

  /// Clears all chat messages.
  void clearChat() {
    _streamTimer?.cancel();
    _messages = [];
    _isProcessing = false;
    _error = null;
    notifyListeners();
  }

  // ==================== 语音输入 ====================

  /// Starts voice input mode.
  void startListening() {
    _isListening = true;
    notifyListeners();
  }

  /// Stops voice input mode.
  void stopListening() {
    _isListening = false;
    notifyListeners();
  }

  // ==================== 内部辅助 ====================

  String _nextId() {
    _idCounter++;
    return 'msg_$_idCounter';
  }

  void _updateAssistantMessage(
    String id,
    String content, {
    required bool isStreaming,
  }) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    _messages[index] = _messages[index].copyWith(
      content: content,
      isStreaming: isStreaming,
    );
  }

  String? _detectCardType(String text) {
    if (text.contains('请假')) return 'leave_form';
    if (text.contains('成绩') || text.contains('课') || text.contains('课表')) {
      return 'schedule';
    }
    return null;
  }

  String _cannedResponse(String text) {
    if (text.contains('请假')) {
      return '好的，我帮你准备了请假申请表，请填写以下信息后一键提交：';
    }
    if (text.contains('成绩')) {
      return '以下是你本学期的成绩概览，各科目已按时间排列：';
    }
    if (text.contains('课') || text.contains('课表')) {
      return '以下是你今天的课程安排，点击可查看详情：';
    }
    if (text.contains('场馆')) {
      return '目前开放的场馆有：篮球馆（空闲）、游泳馆（较忙）、羽毛球馆（空闲）。需要我帮你预约吗？';
    }
    if (text.contains('心理') || text.contains('咨询')) {
      return '学校心理咨询中心位于大学生活动中心 3 楼，工作时间为周一至周五 9:00-17:00。你可以拨打预约热线 0771-12345678，也可以通过"相思同行"App 在线预约。';
    }
    return '收到！我正在为你处理，请稍等。如有其他问题，随时告诉我 😊';
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }
}
