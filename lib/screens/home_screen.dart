import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/shopping_item.dart';
import '../services/sync_service.dart';
import '../widgets/add_edit_item_dialog.dart';
import '../widgets/shopping_item_card.dart';
import '../widgets/sync_status_banner.dart';
import '../widgets/conflict_resolution_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ShoppingItem> _items = [];
  String _filterCategory = 'All';
  bool _showBought = true;
  bool _loading = true;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncResult? _lastSyncResult;
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final items = await DatabaseHelper.instance.readAll();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    final result = await showDialog<ShoppingItem>(
      context: context,
      builder: (_) => AddEditItemDialog(),
    );
    if (result != null) {
      await DatabaseHelper.instance.create(result);
      await _loadItems();
    }
  }

  Future<void> _editItem(ShoppingItem item) async {
    final result = await showDialog<ShoppingItem>(
      context: context,
      builder: (_) => AddEditItemDialog(item: item),
    );
    if (result != null) {
      await DatabaseHelper.instance.update(result);
      await _loadItems();
    }
  }

  Future<void> _toggleBought(ShoppingItem item) async {
    final updated = item.copyWith(isBought: !item.isBought);
    await DatabaseHelper.instance.update(updated);
    await _loadItems();
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    await DatabaseHelper.instance.softDelete(item.id);
    await _loadItems();
  }

  // ── Sync ──────────────────────────────────────────────────
  Future<void> _startSync() async {
    setState(() => _syncStatus = SyncStatus.syncing);

    final result = await SyncService.sync();

    if (result.status == SyncStatus.conflict) {
      // Show conflict resolution dialog
      if (!mounted) return;
      final resolved = await showDialog<List<ShoppingItem>>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            ConflictResolutionDialog(conflicts: result.conflicts),
      );

      if (resolved == null) {
        // User cancelled
        setState(() {
          _syncStatus = SyncStatus.idle;
          _lastSyncResult = null;
        });
        return;
      }

      // Apply resolutions + remaining non-conflict items
      setState(() => _syncStatus = SyncStatus.syncing);
      final finalResult = await SyncService.syncAfterResolution(
        resolvedItems: resolved,
      );
      setState(() {
        _syncStatus = finalResult.status;
        _lastSyncResult = finalResult;
        if (finalResult.status == SyncStatus.success) {
          _lastSynced = DateTime.now();
        }
      });
    } else {
      setState(() {
        _syncStatus = result.status;
        _lastSyncResult = result;
        if (result.status == SyncStatus.success) {
          _lastSynced = DateTime.now();
        }
      });
    }

    await _loadItems();

    // Reset to idle after a few seconds so banner fades to "last synced"
    if (_syncStatus == SyncStatus.success || _syncStatus == SyncStatus.error) {
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) setState(() => _syncStatus = SyncStatus.idle);
    }
  }

  // ── Derived state ─────────────────────────────────────────
  List<ShoppingItem> get _filteredItems => _items.where((item) {
        if (!_showBought && item.isBought) return false;
        if (_filterCategory != 'All' && item.category != _filterCategory) {
          return false;
        }
        return true;
      }).toList();

  Map<String, List<ShoppingItem>> get _groupedItems {
    final map = <String, List<ShoppingItem>>{};
    for (final item in _filteredItems) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  List<String> get _availableCategories {
    final cats = _items.map((i) => i.category).toSet().toList()..sort();
    return cats;
  }

  double get _totalEstimated =>
      _items.fold(0, (s, i) => s + i.estimatedPrice);
  double get _totalActual =>
      _items.fold(0, (s, i) => s + (i.actualPrice ?? 0));
  int get _boughtCount => _items.where((i) => i.isBought).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final grouped = _groupedItems;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── App Bar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'My Shopping List',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.tertiary],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCard(
                        label: 'Items',
                        value: '${_items.length}',
                        sub: '$_boughtCount bought',
                        onPrimary: cs.onPrimary,
                      ),
                      _StatCard(
                        label: 'Estimated',
                        value: '\$${_totalEstimated.toStringAsFixed(0)}',
                        sub: 'budget',
                        onPrimary: cs.onPrimary,
                      ),
                      _StatCard(
                        label: 'Actual',
                        value: '\$${_totalActual.toStringAsFixed(0)}',
                        sub: _totalActual > _totalEstimated
                            ? '▲ over budget'
                            : '✓ on track',
                        onPrimary: cs.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // Sync button
              IconButton(
                icon: _syncStatus == SyncStatus.syncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : Icon(
                        _syncStatus == SyncStatus.conflict
                            ? Icons.warning_amber
                            : Icons.sync,
                        color: _syncStatus == SyncStatus.conflict
                            ? Colors.orange
                            : cs.onPrimary,
                      ),
                tooltip: 'Sync with server',
                onPressed: _syncStatus == SyncStatus.syncing
                    ? null
                    : _startSync,
              ),
              IconButton(
                icon: Icon(
                  _showBought ? Icons.visibility : Icons.visibility_off,
                  color: cs.onPrimary,
                ),
                tooltip: _showBought ? 'Hide bought' : 'Show bought',
                onPressed: () => setState(() => _showBought = !_showBought),
              ),
            ],
          ),

          // ── Sync status banner ────────────────────────────
          SliverToBoxAdapter(
            child: SyncStatusBanner(
              status: _syncStatus,
              lastResult: _lastSyncResult,
              lastSynced: _lastSynced,
            ),
          ),

          // ── Category filter chips ─────────────────────────
          if (_availableCategories.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                color: cs.surface,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filterCategory == 'All',
                        onTap: () => setState(() => _filterCategory = 'All'),
                      ),
                      ..._availableCategories.map((cat) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterChip(
                              label:
                                  '${kCategoryIcons[cat] ?? "📦"} $cat',
                              selected: _filterCategory == cat,
                              onTap: () =>
                                  setState(() => _filterCategory = cat),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],

        // ── Body ─────────────────────────────────────────────
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : grouped.isEmpty
                ? _EmptyState(onAdd: _addItem)
                : RefreshIndicator(
                    onRefresh: _loadItems,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: grouped.length,
                      itemBuilder: (context, idx) {
                        final category = grouped.keys.elementAt(idx);
                        final catItems = grouped[category]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 12, bottom: 4, left: 4),
                              child: Row(children: [
                                Text(kCategoryIcons[category] ?? '📦',
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${catItems.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            ...catItems.map((item) => ShoppingItemCard(
                                  item: item,
                                  onToggle: () => _toggleBought(item),
                                  onEdit: () => _editItem(item),
                                  onDelete: () => _deleteItem(item),
                                )),
                          ],
                        );
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color onPrimary;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.sub,
      required this.onPrimary});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: onPrimary.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(sub,
              style:
                  TextStyle(color: onPrimary.withOpacity(0.6), fontSize: 10)),
        ],
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 80, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('Your list is empty',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Tap the button below to add items',
              style: TextStyle(color: cs.outlineVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add First Item')),
        ],
      ),
    );
  }
}