/// 轻量级调试日志工具
///
/// 在 release 模式下，所有调用会被 Dart 编译器 tree-shaking 移除，
/// 不会执行字符串拼接，也不会产生任何运行时开销。
///
/// 用法：将 `debugPrint(...)` 替换为 `appDebugLog(...)` 即可。

import 'package:flutter/foundation.dart';

/// 仅在 debug 模式下输出日志。
/// release 模式下整个函数体（包括参数的字符串拼接）会被编译器消除。
void appDebugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
