import 'package:flutter/material.dart';
import '../models/shopping_item.dart';

class ShoppingItemCard extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ShoppingItemCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBought = item.isBought;

    return Dismissible(
      key: Key('item_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text('Remove "${item.name}" from your list?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: isBought ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isBought
              ? BorderSide(color: colorScheme.outlineVariant)
              : BorderSide.none,
        ),
        color: isBought
            ? colorScheme.surfaceVariant.withOpacity(0.5)
            : colorScheme.surface,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBought ? colorScheme.primary : Colors.transparent,
                      border: Border.all(
                        color: isBought
                            ? colorScheme.primary
                            : colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: isBought
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: isBought
                              ? TextDecoration.lineThrough
                              : null,
                          color: isBought
                              ? colorScheme.onSurface.withOpacity(0.4)
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.notes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _PriceChip(
                            label: 'Est.',
                            amount: item.estimatedPrice,
                            color: colorScheme.tertiary,
                            isBought: isBought,
                          ),
                          if (item.actualPrice != null) ...[
                            const SizedBox(width: 6),
                            _PriceChip(
                              label: 'Actual',
                              amount: item.actualPrice!,
                              color: _getPriceDiffColor(
                                item.estimatedPrice,
                                item.actualPrice!,
                                colorScheme,
                              ),
                              isBought: isBought,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriceDiffColor(double est, double actual, ColorScheme cs) {
    if (actual > est) return cs.error;
    if (actual < est) return Colors.green;
    return cs.primary;
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isBought;

  const _PriceChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.isBought,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isBought ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBought ? Colors.transparent : color.withOpacity(0.3),
        ),
      ),
      child: Text(
        '$label: \$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isBought ? color.withOpacity(0.4) : color,
        ),
      ),
    );
  }
}