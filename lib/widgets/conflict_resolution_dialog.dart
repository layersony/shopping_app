import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../services/sync_service.dart';

class ConflictResolutionDialog extends StatefulWidget {
  final List<ConflictItem> conflicts;

  const ConflictResolutionDialog({super.key, required this.conflicts});

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  late List<ShoppingItem?> _choices; // null = not yet chosen
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _choices = List.filled(widget.conflicts.length, null);
  }

  bool get _allResolved => _choices.every((c) => c != null);

  void _choose(ShoppingItem item) {
    setState(() {
      _choices[_currentIndex] = item;
      if (_currentIndex < widget.conflicts.length - 1) {
        _currentIndex++;
      }
    });
  }

  void _finish() {
    Navigator.of(context).pop(_choices.whereType<ShoppingItem>().toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = widget.conflicts.length;
    final conflict = widget.conflicts[_currentIndex];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.merge_type, color: cs.error, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resolve Conflicts',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Item ${_currentIndex + 1} of $total — "${conflict.local.name}"',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),

            // Progress bar
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / total,
                minHeight: 6,
                backgroundColor: cs.surfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'This item was changed both locally and on the server.\nChoose which version to keep:',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Local version card
            _VersionCard(
              label: '📱 Keep Local Version',
              item: conflict.local,
              isChosen: _choices[_currentIndex] == conflict.local,
              color: cs.primary,
              onTap: () => _choose(conflict.local),
            ),
            const SizedBox(height: 10),

            // Remote version card
            _VersionCard(
              label: '☁️ Keep Server Version',
              item: conflict.remote,
              isChosen: _choices[_currentIndex] == conflict.remote,
              color: cs.tertiary,
              onTap: () => _choose(conflict.remote),
            ),

            const SizedBox(height: 20),

            // Navigation / finish
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentIndex > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                    onPressed: () =>
                        setState(() => _currentIndex--),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    if (_currentIndex < total - 1)
                      FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Next'),
                        onPressed: _choices[_currentIndex] != null
                            ? () => setState(() => _currentIndex++)
                            : null,
                      )
                    else
                      FilledButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Apply'),
                        onPressed: _allResolved ? _finish : null,
                      ),
                  ],
                ),
              ],
            ),

            // Mini dots showing resolved status
            if (total > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final resolved = _choices[i] != null;
                  final current = i == _currentIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: current ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: resolved
                            ? cs.primary
                            : current
                                ? cs.primary.withOpacity(0.5)
                                : cs.outlineVariant,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String label;
  final ShoppingItem item;
  final bool isChosen;
  final Color color;
  final VoidCallback onTap;

  const _VersionCard({
    required this.label,
    required this.item,
    required this.isChosen,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChosen ? color : cs.outlineVariant,
            width: isChosen ? 2.5 : 1,
          ),
          color: isChosen ? color.withOpacity(0.07) : cs.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isChosen ? color : cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isChosen)
                  Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            _Row('Name', item.name),
            _Row('Category', '${kCategoryIcons[item.category] ?? ''} ${item.category}'),
            _Row('Estimated', '\$${item.estimatedPrice.toStringAsFixed(2)}'),
            if (item.actualPrice != null)
              _Row('Actual', '\$${item.actualPrice!.toStringAsFixed(2)}'),
            _Row('Bought', item.isBought ? '✅ Yes' : '❌ No'),
            if (item.notes != null) _Row('Notes', item.notes!),
            _Row(
              'Modified',
              _formatDate(item.updatedAt),
              subtle: true,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _Row(String key, String value, {bool subtle = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              key,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: subtle ? Colors.grey[500] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}