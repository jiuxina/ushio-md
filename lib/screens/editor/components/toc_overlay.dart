import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/toc_item.dart';
import '../../../widgets/outer_shadow.dart';

class TocOverlayController {
  VoidCallback? _closeImpl;

  void _bind(VoidCallback closeImpl) {
    _closeImpl = closeImpl;
  }

  void _unbind(VoidCallback closeImpl) {
    if (_closeImpl == closeImpl) {
      _closeImpl = null;
    }
  }

  void close() => _closeImpl?.call();
}

class TocOverlay extends StatefulWidget {
  final List<TocItem> items;
  final VoidCallback onClose;
  final void Function(int index, TocItem item) onJumpToHeading;
  final TocOverlayController? controller;
  final int? currentHeadingIndex;
  final bool keepOpenOnJump;

  const TocOverlay({
    super.key,
    required this.items,
    required this.onClose,
    required this.onJumpToHeading,
    this.controller,
    this.currentHeadingIndex,
    this.keepOpenOnJump = false,
  });

  @override
  State<TocOverlay> createState() => _TocOverlayState();
}

class _TocOverlayState extends State<TocOverlay> with TickerProviderStateMixin {
  static const int _filterThreshold = 6;

  late final AnimationController _controller;
  late final Animation<double> _scrimOpacityAnimation;
  late final Animation<Offset> _slideAnimation;

  /// Drives the staggered entrance of list items.
  late final AnimationController _entrance;

  /// Drives the short highlight pulse on the tapped item.
  late final AnimationController _pulse;
  int? _pulsedIndex;

  final TextEditingController _filterController = TextEditingController();
  String _query = '';

  bool _isClosing = false;
  bool _keepOpen = false;

  @override
  void initState() {
    super.initState();
    _keepOpen = widget.keepOpenOnJump;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    )..forward();
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scrimOpacityAnimation = Tween<double>(begin: 0, end: 0.5).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end: Offset.zero,
    ).animate(curve);

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    widget.controller?._bind(_startClose);
  }

  @override
  void dispose() {
    widget.controller?._unbind(_startClose);
    _controller.dispose();
    _entrance.dispose();
    _pulse.dispose();
    _filterController.dispose();
    super.dispose();
  }

  /// Plays the exit animation and then notifies the parent to remove the overlay.
  void _startClose() {
    if (_isClosing) return;
    _isClosing = true;
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _handleTap(int index, TocItem item) {
    setState(() => _pulsedIndex = index);
    _pulse.forward(from: 0);
    widget.onJumpToHeading(index, item);
    if (!_keepOpen) {
      _startClose();
    }
  }

  /// Reveal progress (0..1) for the item at [visualIndex] within the panel.
  double _itemReveal(int visualIndex) {
    const step = 0.05;
    const window = 0.55;
    final start = (visualIndex * step).clamp(0.0, 1.0 - window);
    final v = ((_entrance.value - start) / window).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(v);
  }

  List<(int, TocItem)> _filteredIndexed() {
    final query = _query.trim().toLowerCase();
    final result = <(int, TocItem)>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (query.isEmpty || item.title.toLowerCase().contains(query)) {
        result.add((i, item));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _entrance, _pulse]),
      builder: (context, _) {
        return GestureDetector(
          onTap: _startClose,
          child: Container(
            color: Colors.black.withValues(alpha: _scrimOpacityAnimation.value),
            child: Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OuterShadow(
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(-6, 0),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.78,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Column(
                            children: [
                              _buildHeader(context, l10n),
                              if (widget.items.length >= _filterThreshold)
                                _buildFilter(context, l10n),
                              Expanded(child: _buildList(context, l10n)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.10),
            cs.primary.withValues(alpha: 0.03),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.tableOfContents,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _countPill(context, widget.items.length),
          _compactIconButton(
            context,
            icon: _keepOpen ? Icons.push_pin : Icons.push_pin_outlined,
            tooltip: _keepOpen ? '跳转后保持打开' : '跳转后关闭',
            active: _keepOpen,
            onPressed: () => setState(() => _keepOpen = !_keepOpen),
          ),
          _compactIconButton(
            context,
            icon: Icons.close_rounded,
            onPressed: _startClose,
          ),
        ],
      ),
    );
  }

  Widget _countPill(BuildContext context, int count) {
    if (count <= 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _compactIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool active = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final button = IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      padding: const EdgeInsets.all(7),
      icon: Icon(
        icon,
        size: 20,
        color: active ? cs.primary : cs.onSurfaceVariant,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _buildFilter(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _filterController,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(fontSize: 14, color: cs.onSurface),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.searchContent,
            hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 38,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _filterController.clear();
                      setState(() => _query = '');
                    },
                  ),
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (widget.items.isEmpty) {
      return _emptyState(context, l10n.noHeadingsFound, Icons.tag);
    }
    final filtered = _filteredIndexed();
    if (filtered.isEmpty) {
      return _emptyState(context, l10n.noMatchContent, Icons.search_off);
    }
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent,
        ],
        stops: [0.0, 0.02, 0.98, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, i) {
          final (origIndex, item) = filtered[i];
          return _buildTocItem(context, item, origIndex, i);
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context, String message, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: cs.outlineVariant),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildTocItem(
    BuildContext context,
    TocItem item,
    int origIndex,
    int visualIndex,
  ) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final level = item.level.clamp(1, 6);
    final indent = (level - 1) * 15.0;
    final isCurrent = origIndex == widget.currentHeadingIndex;

    final pulseBoost = (_pulsedIndex == origIndex)
        ? Curves.easeOut.transform(1 - _pulse.value) * 0.14
        : 0.0;

    final baseAlpha = (0.92 - (level - 1) * 0.09).clamp(0.55, 0.92);
    final textColor = isCurrent
        ? accent
        : cs.onSurface.withValues(alpha: baseAlpha);

    final reveal = _itemReveal(visualIndex);

    return Opacity(
      opacity: reveal,
      child: Transform.translate(
        offset: Offset(14 * (1 - reveal), 0),
        child: Padding(
          padding: EdgeInsets.only(left: 4 + indent, bottom: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _handleTap(origIndex, item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? accent.withValues(alpha: 0.10 + pulseBoost)
                      : accent.withValues(alpha: pulseBoost),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    // Current accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 3,
                      height: isCurrent ? 18 : 0,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: isCurrent ? 8 : 11),
                    // Tree node dot
                    _nodeDot(context, isCurrent, accent, cs),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: level == 1
                              ? 15.5
                              : (15.0 - (level - 1) * 0.6).clamp(12.5, 15.0),
                          fontWeight: level == 1
                              ? FontWeight.w700
                              : (level == 2
                                    ? FontWeight.w600
                                    : FontWeight.w400),
                          color: textColor,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nodeDot(
    BuildContext context,
    bool isCurrent,
    Color accent,
    ColorScheme cs,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: isCurrent ? 8 : 6,
      height: isCurrent ? 8 : 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent ? accent : cs.onSurfaceVariant.withValues(alpha: 0.45),
        boxShadow: isCurrent
            ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6)]
            : null,
      ),
    );
  }
}
