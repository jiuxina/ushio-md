import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/toc_item.dart';

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

class _TocOverlayState extends State<TocOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scrimOpacityAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isClosing = false;
  bool _keepOpen = false;

  @override
  void initState() {
    super.initState();
    _keepOpen = widget.keepOpenOnJump;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
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
    widget.controller?._bind(_startClose);
  }

  @override
  void dispose() {
    widget.controller?._unbind(_startClose);
    _controller.dispose();
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

  void _onItemTap(int index, TocItem item) {
    widget.onJumpToHeading(index, item);
    if (!_keepOpen) {
      _startClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _controller,
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
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(-5, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.list,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.tableOfContents,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              // Keep open toggle
                              Tooltip(
                                message: _keepOpen ? '跳转后保持打开' : '跳转后关闭',
                                child: IconButton(
                                  icon: Icon(
                                    _keepOpen ? Icons.lock : Icons.lock_open,
                                    size: 20,
                                    color: _keepOpen
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                  onPressed: () {
                                    setState(() => _keepOpen = !_keepOpen);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _startClose,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: widget.items.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.noHeadingsFound,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  ),
                                )
                              : RepaintBoundary(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: widget.items.length,
                                    itemBuilder: (context, index) {
                                      final item = widget.items[index];
                                      final isCurrent =
                                          index == widget.currentHeadingIndex;
                                      return _buildTocItem(
                                        context,
                                        item,
                                        index,
                                        isCurrent,
                                      );
                                    },
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
      },
    );
  }

  Widget _buildTocItem(
    BuildContext context,
    TocItem item,
    int index,
    bool isCurrent,
  ) {
    final indent = (item.level - 1) * 16.0;
    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    final color = colors[(item.level - 1) % colors.length];

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onItemTap(index, item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? color.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? color.withValues(alpha: 0.5)
                    : color.withValues(alpha: 0.2),
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      'H${item.level}',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16 - (item.level - 1) * 1.0,
                      fontWeight: item.level == 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent) Icon(Icons.arrow_left, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
