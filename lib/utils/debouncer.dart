/// 防抖工具类
///
/// 提供简单易用的防抖功能，防止快速重复操作
library;

/// 防抖器
///
/// 用于防止快速重复调用同一操作
///
/// 示例:
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 300));
///
/// // 快速点击只会执行最后一次
/// debouncer.run(() {
///   print('执行操作');
/// });
/// ```
class Debouncer {
  /// 防抖延迟时间
  final Duration duration;
  
  /// 当前待执行的 Timer
  Timer? _timer;
  
  Debouncer({this.duration = const Duration(milliseconds: 300)});
  
  /// 执行防抖操作
  ///
  /// [action] 要执行的操作
  /// 在 [duration] 时间内多次调用，只会执行最后一次
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }
  
  /// 执行防抖异步操作
  ///
  /// [action] 要执行的异步操作
  /// 在 [duration] 时间内多次调用，只会执行最后一次
  Future<T?> runAsync<T>(Future<T> Function() action) async {
    _timer?.cancel();
    final completer = Completer<T?>();
    
    _timer = Timer(duration, () async {
      try {
        final result = await action();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });
    
    return completer.future;
  }
  
  /// 立即执行并取消待执行的操作
  void flush(VoidCallback action) {
    _timer?.cancel();
    action();
  }
  
  /// 取消待执行的操作
  void cancel() {
    _timer?.cancel();
  }
  
  /// 是否有待执行的操作
  bool get isActive => _timer?.isActive ?? false;
  
  /// 释放资源
  void dispose() {
    _timer?.cancel();
  }
}

/// 操作锁
///
/// 用于防止并发执行同一操作
///
/// 示例:
/// ```dart
/// final lock = OperationLock();
///
/// if (lock.tryAcquire()) {
///   try {
///     await performOperation();
///   } finally {
///     lock.release();
///   }
/// }
/// ```
class OperationLock {
  bool _isLocked = false;
  
  /// 尝试获取锁
  ///
  /// 返回 true 表示成功获取锁
  /// 返回 false 表示锁已被占用
  bool tryAcquire() {
    if (_isLocked) return false;
    _isLocked = true;
    return true;
  }
  
  /// 释放锁
  void release() {
    _isLocked = false;
  }
  
  /// 是否已锁定
  bool get isLocked => _isLocked;
  
  /// 在锁保护下执行操作
  ///
  /// 如果锁已被占用，返回 null
  /// 如果成功获取锁，执行操作后自动释放
  Future<T?> withLock<T>(Future<T> Function() action) async {
    if (!tryAcquire()) return null;
    try {
      return await action();
    } finally {
      release();
    }
  }
}

/// 全局防抖管理器
///
/// 通过 key 管理多个防抖操作
///
/// 示例:
/// ```dart
/// // 快速点击只会执行一次
/// GlobalDebouncer.run('save_button', () {
///   saveFile();
/// });
///
/// // 检查操作是否正在执行
/// if (!GlobalDebouncer.isRunning('save_button')) {
///   GlobalDebouncer.run('save_button', () => saveFile());
/// }
/// ```
class GlobalDebouncer {
  static final Map<String, Timer> _timers = {};
  static final Map<String, bool> _locks = {};
  
  /// 默认防抖延迟
  static const Duration defaultDuration = Duration(milliseconds: 300);
  
  /// 执行防抖操作
  ///
  /// [key] 操作标识
  /// [action] 要执行的操作
  /// [duration] 防抖延迟（默认 300ms）
  static void run(String key, VoidCallback action, {Duration? duration}) {
    _timers[key]?.cancel();
    _timers[key] = Timer(duration ?? defaultDuration, () {
      action();
      _timers.remove(key);
    });
  }
  
  /// 执行防抖异步操作
  ///
  /// [key] 操作标识
  /// [action] 要执行的异步操作
  /// [duration] 防抖延迟
  static Future<T?> runAsync<T>(
    String key,
    Future<T> Function() action, {
    Duration? duration,
  }) async {
    final completer = Completer<T?>();
    
    _timers[key]?.cancel();
    _timers[key] = Timer(duration ?? defaultDuration, () async {
      try {
        final result = await action();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
      _timers.remove(key);
    });
    
    return completer.future;
  }
  
  /// 尝试执行操作（带锁）
  ///
  /// 如果操作正在执行，返回 null
  /// 否则执行操作并返回结果
  static Future<T?> tryRun<T>(String key, Future<T> Function() action) async {
    if (_locks[key] == true) return null;
    
    _locks[key] = true;
    try {
      return await action();
    } finally {
      _locks[key] = false;
    }
  }
  
  /// 检查操作是否正在执行
  static bool isRunning(String key) => _locks[key] == true;
  
  /// 检查是否有待执行的操作
  static bool isPending(String key) => _timers[key]?.isActive ?? false;
  
  /// 取消指定操作
  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
  }
  
  /// 取消所有操作
  static void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
  
  /// 释放锁
  static void releaseLock(String key) {
    _locks[key] = false;
  }
}
