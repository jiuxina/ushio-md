import 'package:flutter/material.dart';

class SearchSheet extends StatefulWidget {
  final String text;
  final Function(int position, int length) onMatchSelected;


  const SearchSheet({
    super.key,
    required this.text,
    required this.onMatchSelected,
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<int> _matchPositions = [];
  int _currentMatchIndex = 0;

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _matchPositions = [];
        _currentMatchIndex = 0;
      });
      return;
    }

    final text = widget.text.toLowerCase();
    final searchText = query.toLowerCase();
    final positions = <int>[];
    int index = 0;
    
    while (true) {
      index = text.indexOf(searchText, index);
      if (index == -1) break;
      positions.add(index);
      index += searchText.length;
    }

    setState(() {
      _matchPositions = positions;
      _currentMatchIndex = positions.isNotEmpty ? 0 : -1;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight - bottomInset - 100;
    
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight > 200 ? maxHeight : 200,
          minHeight: 200,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '搜索内容...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _matchPositions.isNotEmpty
                            ? Text(
                                '${_currentMatchIndex + 1}/${_matchPositions.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(minWidth: 60),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onChanged: _performSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: _matchPositions.isEmpty ? null : () {
                      setState(() {
                        _currentMatchIndex = (_currentMatchIndex - 1 + _matchPositions.length) % _matchPositions.length;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: _matchPositions.isEmpty ? null : () {
                      setState(() {
                        _currentMatchIndex = (_currentMatchIndex + 1) % _matchPositions.length;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _matchPositions.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty ? '输入关键词开始搜索' : '未找到匹配内容',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _matchPositions.length,
                      itemBuilder: (context, index) {
                        final position = _matchPositions[index];
                        final text = widget.text;
                        final start = (position - 20).clamp(0, text.length);
                        final end = (position + _searchController.text.length + 20).clamp(0, text.length);
                        final contextStr = text.substring(start, end).replaceAll('\n', ' ');

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: index == _currentMatchIndex
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: index == _currentMatchIndex
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          title: Text(
                            '...$contextStr...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () => widget.onMatchSelected(position, _searchController.text.length),

                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
