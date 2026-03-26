import '../db/database_helper.dart';
import '../models/shopping_item.dart';
import 'supabase_service.dart';

enum SyncStatus { idle, syncing, success, error, conflict }

class ConflictItem {
  final ShoppingItem local;
  final ShoppingItem remote;
  ConflictItem({required this.local, required this.remote});
}

class SyncResult {
  final SyncStatus status;
  final int pushed;
  final int pulled;
  final List<ConflictItem> conflicts;
  final String? errorMessage;

  SyncResult({
    required this.status,
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = const [],
    this.errorMessage,
  });
}

class SyncService {
  /// Full sync:
  /// 1. Fetch all remote items
  /// 2. Compare with local — find conflicts (both changed since last sync)
  /// 3. Return conflicts for user to resolve
  /// 4. Push local-only or local-newer items to remote
  /// 5. Pull remote-only or remote-newer items to local
  static Future<SyncResult> sync() async {
    try {
      final isReachable = await SupabaseService.isReachable();
      if (!isReachable) {
        return SyncResult(
          status: SyncStatus.error,
          errorMessage: 'Cannot reach server. Check your internet connection.',
        );
      }

      final localItems = await DatabaseHelper.instance.readAll(includeDeleted: true);
      final remoteItems = await SupabaseService.fetchAll();

      final localMap = {for (final i in localItems) i.id: i};
      final remoteMap = {for (final i in remoteItems) i.id: i};

      final conflicts = <ConflictItem>[];
      final toPushRemote = <ShoppingItem>[];
      final toPullLocal = <ShoppingItem>[];

      // Items in local
      for (final local in localItems) {
        final remote = remoteMap[local.id];
        if (remote == null) {
          // Local only → push to remote
          toPushRemote.add(local);
        } else {
          // Both exist — compare updatedAt
          final localNewer = local.updatedAt.isAfter(remote.updatedAt);
          final remoteNewer = remote.updatedAt.isAfter(local.updatedAt);
          final same = local.updatedAt == remote.updatedAt;

          if (same) continue; // already in sync

          if (localNewer && remoteNewer) {
            // True conflict — both changed
            conflicts.add(ConflictItem(local: local, remote: remote));
          } else if (localNewer) {
            toPushRemote.add(local);
          } else if (remoteNewer) {
            toPullLocal.add(remote);
          }
        }
      }

      // Items only in remote → pull to local
      for (final remote in remoteItems) {
        if (!localMap.containsKey(remote.id)) {
          toPullLocal.add(remote);
        }
      }

      if (conflicts.isNotEmpty) {
        // Return conflicts — don't sync yet, wait for user resolution
        return SyncResult(
          status: SyncStatus.conflict,
          conflicts: conflicts,
          pushed: 0,
          pulled: 0,
        );
      }

      // No conflicts — apply all changes
      await _applySync(toPushRemote, toPullLocal);

      return SyncResult(
        status: SyncStatus.success,
        pushed: toPushRemote.length,
        pulled: toPullLocal.length,
      );
    } catch (e) {
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Called after user resolves all conflicts
  /// resolvedItems: the chosen version for each conflict (local or remote)
  /// Plus the non-conflicted push/pull lists from original sync
  static Future<SyncResult> applyResolutions({
    required List<ShoppingItem> resolvedItems,
    required List<ShoppingItem> toPush,
    required List<ShoppingItem> toPull,
  }) async {
    try {
      final allToPush = [...toPush, ...resolvedItems];
      final allToPull = [...toPull];

      await _applySync(allToPush, allToPull);

      return SyncResult(
        status: SyncStatus.success,
        pushed: allToPush.length,
        pulled: allToPull.length,
      );
    } catch (e) {
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  static Future<void> _applySync(
    List<ShoppingItem> toPush,
    List<ShoppingItem> toPull,
  ) async {
    // Push local → remote
    await SupabaseService.upsertBatch(toPush);

    // Pull remote → local
    for (final item in toPull) {
      await DatabaseHelper.instance.upsert(item);
    }
  }

  /// Re-run sync after conflicts are resolved, passing back the remaining
  /// non-conflict items so they still get synced
  static Future<SyncResult> syncAfterResolution({
    required List<ShoppingItem> resolvedItems,
  }) async {
    try {
      final localItems = await DatabaseHelper.instance.readAll(includeDeleted: true);
      final remoteItems = await SupabaseService.fetchAll();

      final localMap = {for (final i in localItems) i.id: i};
      final remoteMap = {for (final i in remoteItems) i.id: i};

      final toPush = <ShoppingItem>[];
      final toPull = <ShoppingItem>[];

      for (final local in localItems) {
        final remote = remoteMap[local.id];
        if (remote == null) {
          toPush.add(local);
        } else if (local.updatedAt.isAfter(remote.updatedAt)) {
          toPush.add(local);
        }
      }
      for (final remote in remoteItems) {
        if (!localMap.containsKey(remote.id)) {
          toPull.add(remote);
        } else {
          final local = localMap[remote.id]!;
          if (remote.updatedAt.isAfter(local.updatedAt)) {
            toPull.add(remote);
          }
        }
      }

      // Save resolved items locally first, then push everything
      for (final item in resolvedItems) {
        await DatabaseHelper.instance.upsert(item);
        toPush.add(item);
      }

      await _applySync(toPush, toPull);

      return SyncResult(
        status: SyncStatus.success,
        pushed: toPush.length,
        pulled: toPull.length,
      );
    } catch (e) {
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}