import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shopping_item.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _table = 'shopping_items';

  /// Fetch all items from Supabase (including soft-deleted for conflict detection)
  static Future<List<ShoppingItem>> fetchAll() async {
    final response = await _client
        .from(_table)
        .select()
        .order('category')
        .order('name');
    return (response as List).map((m) => ShoppingItem.fromMap(m)).toList();
  }

  /// Upsert a single item to Supabase
  static Future<void> upsert(ShoppingItem item) async {
    await _client.from(_table).upsert(item.toSupabaseMap());
  }

  /// Upsert a batch of items
  static Future<void> upsertBatch(List<ShoppingItem> items) async {
    if (items.isEmpty) return;
    final batch = items.map((i) => i.toSupabaseMap()).toList();
    await _client.from(_table).upsert(batch);
  }

  /// Check connectivity to Supabase by doing a lightweight query
  static Future<bool> isReachable() async {
    try {
      await _client.from(_table).select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}