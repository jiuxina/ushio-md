typedef DebugProbeRequest = Future<void> Function();

class DebugProbeService {
  DebugProbeService._();

  static final DebugProbeService instance = DebugProbeService._();

  DebugProbeRequest? _requestCodeBlockLanguageProbe;

  void registerCodeBlockLanguageProbe(DebugProbeRequest requester) {
    _requestCodeBlockLanguageProbe = requester;
  }

  void unregisterCodeBlockLanguageProbe(DebugProbeRequest requester) {
    if (_requestCodeBlockLanguageProbe == requester) {
      _requestCodeBlockLanguageProbe = null;
    }
  }

  Future<bool> requestCodeBlockLanguageProbe() async {
    final requester = _requestCodeBlockLanguageProbe;
    if (requester == null) return false;
    await requester();
    return true;
  }
}
