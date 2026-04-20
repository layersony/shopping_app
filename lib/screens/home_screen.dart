import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/shopping_item.dart';
import '../services/sync_service.dart';
import '../theme.dart';
import '../widgets/add_edit_item_dialog.dart';
import '../widgets/calculator_sheet.dart';
import '../widgets/conflict_resolution_dialog.dart';

class HomeScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleDark;

  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleDark,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ShoppingItem> _items = [];
  int _tab = 0; // 0=home, 1=categories, 2=budget
  String _filter = 'All';
  bool _showBought = true;
  bool _loading = true;

  SyncStatus _syncStatus = SyncStatus.idle;

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
      builder: (_) => const AddEditItemDialog(),
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

  Future<void> _startSync() async {
    setState(() => _syncStatus = SyncStatus.syncing);
    SyncResult result = await SyncService.sync();

    if (result.status == SyncStatus.conflict) {
      if (!mounted) return;
      final resolved = await showDialog<List<ShoppingItem>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ConflictResolutionDialog(conflicts: result.conflicts),
      );
      if (resolved == null) {
        setState(() => _syncStatus = SyncStatus.idle);
        return;
      }
      setState(() => _syncStatus = SyncStatus.syncing);
      result = await SyncService.syncAfterResolution(resolvedItems: resolved);
    }

    setState(() => _syncStatus = result.status);
    await _loadItems();
    if (!mounted) return;

    _showSyncSnackBar(result);

    if (_syncStatus == SyncStatus.success || _syncStatus == SyncStatus.error) {
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) setState(() => _syncStatus = SyncStatus.idle);
    }
  }

  void _showSyncSnackBar(SyncResult result) {
    final String message;
    final Color bgColor;
    final IconData icon;

    switch (result.status) {
      case SyncStatus.success:
        final pushed = result.pushed;
        final pulled = result.pulled;
        if (pushed == 0 && pulled == 0) {
          message = 'Already up to date';
        } else {
          final parts = <String>[];
          if (pushed > 0) parts.add('↑ $pushed pushed');
          if (pulled > 0) parts.add('↓ $pulled pulled');
          message = parts.join(' · ');
        }
        bgColor = const Color(0xFF15803D);
        icon = Icons.cloud_done_outlined;
      case SyncStatus.error:
        message = result.errorMessage ?? 'Sync failed';
        bgColor = const Color(0xFFB91C1C);
        icon = Icons.cloud_off_outlined;
      case SyncStatus.conflict:
        message = '${result.conflicts.length} conflict(s) — resolve them to continue';
        bgColor = const Color(0xFFB45309);
        icon = Icons.warning_amber_outlined;
      default:
        return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _resetList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kSheetRadius)),
        title: Text('Reset list?', style: TextStyle(color: context.inkColor, fontWeight: FontWeight.w700)),
        content: Text(
          'This will mark all items as not bought, clear actual prices, and restore deleted items.',
          style: TextStyle(color: context.subColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.subColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.resetAll();
      await _loadItems();
    }
  }

  void _openCalculator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CalculatorSheet(),
    );
  }

  // ── Derived state ─────────────────────────────────────────
  List<ShoppingItem> get _filteredItems => _items.where((item) {
        if (!_showBought && item.isBought) return false;
        if (_filter != 'All' && item.category != _filter) return false;
        return true;
      }).toList();

  Map<String, List<ShoppingItem>> get _groupedItems {
    final map = <String, List<ShoppingItem>>{};
    for (final item in _filteredItems) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  List<String> get _availableCategories =>
      _items.map((i) => i.category).toSet().toList();

  double get _totalEst   => _items.fold(0, (s, i) => s + i.estimatedPrice);
  double get _totalActual => _items.fold(0, (s, i) => s + (i.actualPrice ?? 0));
  int    get _boughtCount => _items.where((i) => i.isBought).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // ── Tab content ─────────────────────────────────
          IndexedStack(
            index: _tab,
            children: [
              _HomeTab(
                items: _items,
                filteredGrouped: _groupedItems,
                availableCategories: _availableCategories,
                filter: _filter,
                showBought: _showBought,
                loading: _loading,
                totalEst: _totalEst,
                totalActual: _totalActual,
                boughtCount: _boughtCount,
                isDark: widget.isDark,
                onToggleDark: widget.onToggleDark,
                onToggleShowBought: () => setState(() => _showBought = !_showBought),
                onFilterChange: (f) => setState(() => _filter = f),
                onToggleBought: _toggleBought,
                onEdit: _editItem,
                onDelete: _deleteItem,
                onRefresh: _startSync,
              ),
              _CategoriesTab(
                items: _items,
                onPick: (cat) => setState(() { _filter = cat; _tab = 0; }),
              ),
              _BudgetTab(items: _items, onReset: _resetList),
            ],
          ),

          // ── FAB (home tab only) ──────────────────────────
          if (_tab == 0)
            Positioned(
              right: 22,
              bottom: 96,
              child: GestureDetector(
                onTap: _addItem,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: context.accentColor.withValues(alpha: 0.33),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.add, color: context.bgColor, size: 24, weight: 700),
                ),
              ),
            ),

          // ── Floating tab bar ─────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _FloatingTabBar(
              tab: _tab,
              onTab: (t) => setState(() => _tab = t),
              onCalc: _openCalculator,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating tab bar ──────────────────────────────────────────
class _FloatingTabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onCalc;

  const _FloatingTabBar({required this.tab, required this.onTab, required this.onCalc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(kChipRadius),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabItem(icon: Icons.home_outlined, label: 'List',       id: 0, tab: tab, onTab: onTab),
          _TabItem(icon: Icons.grid_view_outlined, label: 'Categories', id: 1, tab: tab, onTab: onTab),
          // Calculator button (center)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: onCalc,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.inkColor,
                ),
                child: Icon(Icons.calculate_outlined, color: context.bgColor, size: 22),
              ),
            ),
          ),
          _TabItem(icon: Icons.bar_chart_outlined, label: 'Budget',     id: 2, tab: tab, onTab: onTab),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int id;
  final int tab;
  final ValueChanged<int> onTab;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.id,
    required this.tab,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final active = tab == id;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTab(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? context.inkColor : context.muteColor,
                weight: active ? 700 : 400,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: active ? context.inkColor : context.muteColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final List<ShoppingItem> items;
  final Map<String, List<ShoppingItem>> filteredGrouped;
  final List<String> availableCategories;
  final String filter;
  final bool showBought;
  final bool loading;
  final double totalEst;
  final double totalActual;
  final int boughtCount;
  final bool isDark;
  final VoidCallback onToggleDark;
  final VoidCallback onToggleShowBought;
  final ValueChanged<String> onFilterChange;
  final ValueChanged<ShoppingItem> onToggleBought;
  final ValueChanged<ShoppingItem> onEdit;
  final ValueChanged<ShoppingItem> onDelete;
  final Future<void> Function() onRefresh;

  const _HomeTab({
    required this.items,
    required this.filteredGrouped,
    required this.availableCategories,
    required this.filter,
    required this.showBought,
    required this.loading,
    required this.totalEst,
    required this.totalActual,
    required this.boughtCount,
    required this.isDark,
    required this.onToggleDark,
    required this.onToggleShowBought,
    required this.onFilterChange,
    required this.onToggleBought,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE · MMMM d').format(DateTime.now());
    final grouped = filteredGrouped;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.inkColor,
      backgroundColor: context.surfaceColor,
      child: ListView(
      padding: const EdgeInsets.only(bottom: 160),
      children: [
        // ── Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      color: context.subColor,
                    ),
                  ),
                  Row(
                    children: [
                      _IconBtn(
                        onTap: onToggleDark,
                        child: Icon(
                          isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                          size: 18,
                          color: context.inkColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _IconBtn(
                        onTap: onToggleShowBought,
                        child: Icon(
                          showBought ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: context.inkColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Shopping\nlist',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1.05,
                  color: context.inkColor,
                ),
              ),
            ],
          ),
        ),

        // ── Stats block ─────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(22, 18, 22, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(color: context.borderColor),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _Stat(label: 'Items',  value: '${items.length}', sub: '$boughtCount bought'),
                VerticalDivider(width: 1, color: context.borderColor),
                _Stat(label: 'Est.',   value: 'Ksh ${totalEst.toStringAsFixed(0)}',    sub: 'budget',  divider: true),
                VerticalDivider(width: 1, color: context.borderColor),
                _Stat(
                  label: 'Spent',
                  value: 'Ksh ${totalActual.toStringAsFixed(0)}',
                  sub: totalActual > totalEst ? '↑ over' : '↓ under',
                  divider: true,
                  valueColor: totalActual > totalEst ? const Color(0xFFB91C1C) : context.accentColor,
                ),
              ],
            ),
          ),
        ),

        // ── Filter chips ─────────────────────────────────────
        const SizedBox(height: 22),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: [
              _Chip(
                label: 'All · ${items.length}',
                active: filter == 'All',
                onTap: () => onFilterChange('All'),
              ),
              ...availableCategories.map((cat) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Chip(
                      label: '${kCategoryIcons[cat] ?? "📦"} $cat',
                      active: filter == cat,
                      onTap: () => onFilterChange(cat),
                    ),
                  )),
            ],
          ),
        ),

        // ── Item list ────────────────────────────────────────
        const SizedBox(height: 18),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (grouped.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Column(
              children: [
                const Text('🧺', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text('Nothing here yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.inkColor)),
                Text('Tap + to add your first item',
                    style: TextStyle(fontSize: 13, color: context.subColor)),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: grouped.entries.map((e) {
                final cat = e.key;
                final catItems = e.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Row(
                        children: [
                          Text(kCategoryIcons[cat] ?? '📦', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            cat.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: context.subColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 1, color: context.borderColor)),
                          const SizedBox(width: 8),
                          Text(
                            '${catItems.length}',
                            style: TextStyle(fontSize: 12, color: context.subColor),
                          ),
                        ],
                      ),
                    ),
                    // Items
                    ...catItems.map((item) => _ItemRow(
                          item: item,
                          onToggle: () => onToggleBought(item),
                          onEdit:   () => onEdit(item),
                          onDelete: () => onDelete(item),
                        )),
                    const SizedBox(height: 18),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
      ),
    );
  }
}

// ── Item row ─────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final overBudget  = item.actualPrice != null && item.actualPrice! > item.estimatedPrice;
    final underBudget = item.actualPrice != null && item.actualPrice! < item.estimatedPrice;

    return GestureDetector(
      onTap: onEdit,
      child: Dismissible(
        key: Key('row_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFB91C1C),
            borderRadius: BorderRadius.circular(kCardRadius),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
        ),
        confirmDismiss: (_) async => await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete item', style: TextStyle(color: context.inkColor)),
            content: Text('Remove "${item.name}"?', style: TextStyle(color: context.subColor)),
            backgroundColor: context.surfaceColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kSheetRadius)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Color(0xFFB91C1C))),
              ),
            ],
          ),
        ),
        onDismissed: (_) => onDelete(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isBought ? context.accentColor : Colors.transparent,
                    border: Border.all(
                      color: item.isBought ? context.accentColor : context.muteColor,
                      width: 1.5,
                    ),
                  ),
                  child: item.isBought
                      ? Icon(Icons.check, color: context.bgColor, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Name + notes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: item.isBought ? context.muteColor : context.inkColor,
                        decoration: item.isBought ? TextDecoration.lineThrough : null,
                        decorationColor: context.muteColor,
                      ),
                    ),
                    if (item.notes != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.notes!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.subColor),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ksh ${(item.actualPrice ?? item.estimatedPrice).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: overBudget
                          ? const Color(0xFFB91C1C)
                          : underBudget
                              ? const Color(0xFF15803D)
                              : context.inkColor,
                    ),
                  ),
                  Text(
                    item.actualPrice != null
                        ? 'est. Ksh ${item.estimatedPrice.toStringAsFixed(0)}'
                        : 'estimated',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.subColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Budget Tab ────────────────────────────────────────────────
class _BudgetTab extends StatelessWidget {
  final List<ShoppingItem> items;
  final Future<void> Function() onReset;

  const _BudgetTab({required this.items, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final est    = items.fold(0.0, (s, i) => s + i.estimatedPrice);
    final actual = items.fold(0.0, (s, i) => s + (i.actualPrice ?? 0));
    final bought = items.where((i) => i.isBought).length;
    final remaining = (est - actual).clamp(0.0, double.infinity);
    final pct = est > 0 ? (actual / est).clamp(0.0, 1.2) : 0.0;

    final byCat = kCategories.map((catKey) {
      final rows = items.where((i) => i.category == catKey).toList();
      return (
        key: catKey,
        emoji: kCategoryIcons[catKey] ?? '📦',
        est: rows.fold(0.0, (s, r) => s + r.estimatedPrice),
        actual: rows.fold(0.0, (s, r) => s + (r.actualPrice ?? 0)),
        count: rows.length,
      );
    }).where((c) => c.count > 0).toList()
      ..sort((a, b) => b.est.compareTo(a.est));

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 160),
      children: [
        Text('Overview',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                letterSpacing: 0.3, color: context.subColor)),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Budget',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700,
                      letterSpacing: -1, color: context.inkColor, height: 1.05)),
              GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFB91C1C)),
                    borderRadius: BorderRadius.circular(kChipRadius),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Headline card ───────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spent so far',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2, color: context.subColor)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Ksh ${actual.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                      color: context.inkColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('of Ksh ${est.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 14, color: context.subColor)),
                ],
              ),
              const SizedBox(height: 14),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(color: context.surface2Color),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          color: pct > 1 ? const Color(0xFFB91C1C) : context.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$bought of ${items.length} bought',
                      style: TextStyle(fontSize: 12, color: context.subColor)),
                  Text(
                    'Ksh ${remaining.toStringAsFixed(0)} left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pct > 1 ? const Color(0xFFB91C1C) : context.accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Category breakdown ──────────────────────────
        const SizedBox(height: 28),
        Text('Category breakdown',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.2, color: context.subColor)),
        const SizedBox(height: 12),
        ...byCat.map((c) {
          final barW   = est > 0 ? (c.est / est * 100).clamp(3.0, 100.0) : 3.0;
          final spentW = c.est > 0 ? (c.actual / c.est * 100).clamp(0.0, 100.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(c.key,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.inkColor)),
                        const SizedBox(width: 6),
                        Text('· ${c.count}',
                            style: TextStyle(fontSize: 11, color: context.subColor)),
                      ],
                    ),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.inkColor),
                        children: [
                          TextSpan(text: 'Ksh ${c.actual.toStringAsFixed(0)}'),
                          TextSpan(
                            text: '/${c.est.toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.w400, color: context.subColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: context.surface2Color),
                        // Budget allocation strip
                        FractionallySizedBox(
                          widthFactor: barW / 100,
                          child: Container(
                            color: context.accentColor.withValues(alpha: 0.12),
                          ),
                        ),
                        // Spent portion
                        FractionallySizedBox(
                          widthFactor: (barW * spentW / 10000),
                          child: Container(color: context.accentColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Categories Tab ────────────────────────────────────────────
class _CategoriesTab extends StatelessWidget {
  final List<ShoppingItem> items;
  final ValueChanged<String> onPick;

  const _CategoriesTab({required this.items, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final counts = kCategories.map((cat) => (
          key: cat,
          emoji: kCategoryIcons[cat] ?? '📦',
          count: items.where((i) => i.category == cat).length,
          est: items.where((i) => i.category == cat).fold(0.0, (s, i) => s + i.estimatedPrice),
        )).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 160),
      children: [
        Text('Browse',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                letterSpacing: 0.3, color: context.subColor)),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Text('Categories',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700,
                  letterSpacing: -1, color: context.inkColor, height: 1.05)),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: counts.map((c) {
            final enabled = c.count > 0;
            return GestureDetector(
              onTap: enabled ? () => onPick(c.key) : null,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(kCardRadius),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 32)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.key,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.inkColor)),
                          const SizedBox(height: 2),
                          Text(
                            '${c.count} item${c.count == 1 ? '' : 's'} · Ksh ${c.est.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.subColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────
class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool divider;
  final Color? valueColor;

  const _Stat({
    required this.label,
    required this.value,
    required this.sub,
    this.divider = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: divider ? 12 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: context.subColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: valueColor ?? context.inkColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: context.subColor)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? context.inkColor : context.surfaceColor,
          borderRadius: BorderRadius.circular(kChipRadius),
          border: Border.all(color: active ? context.inkColor : context.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? context.bgColor : context.inkColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _IconBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.surfaceColor,
          border: Border.all(color: context.borderColor),
        ),
        child: Center(child: child),
      ),
    );
  }
}
