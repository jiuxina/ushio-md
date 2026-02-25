import 'package:flutter/material.dart';
import '../../../models/toc_item.dart';

class TocOverlay extends StatefulWidget {
  final List<TocItem> items;
  final VoidCallback onClose;
  final Function(TocItem) onJumpToHeading;

  const TocOverlay({
    super.key,
    required this.items,
    required this.onClose,
    required this.onJumpToHeading,
  });

  @override
  State<TocOverlay> createState() => _TocOverlayState();
}

class _TocOverlayState extends State<TocOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Plays the exit animation and then notifies the parent to remove the overlay.
  void _startClose() {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return GestureDetector(
          onTap: _startClose,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5 * value), // 背景淡入
            child: Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: Offset((1 - value) * 100, 0), // 从右侧滑入
                child: Opacity(
                  opacity: value,
                  child: GestureDetector(
                    onTap: () {}, // Prevent close on panel tap
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
                          // Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
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
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.list,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '目录',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _startClose,
                                ),
                              ],
                            ),
                          ),
                          // TOC items
                          Expanded(
                            child: widget.items.isEmpty
                                ? Center(
                                    child: Text(
                                      '没有找到标题',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: widget.items.length,
                                    itemBuilder: (context, index) {
                                      final item = widget.items[index];
                                      return _buildTocItem(context, item);
                                    },
                                  ),
                          ),
                        ],
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

  Widget _buildTocItem(BuildContext context, TocItem item) {
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
          onTap: () => widget.onJumpToHeading(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
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
                      fontWeight: item.level == 1 ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
