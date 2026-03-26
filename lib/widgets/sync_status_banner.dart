import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncStatusBanner extends StatelessWidget {
  final SyncStatus status;
  final SyncResult? lastResult;
  final DateTime? lastSynced;

  const SyncStatusBanner({
    super.key,
    required this.status,
    this.lastResult,
    this.lastSynced,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (status == SyncStatus.idle && lastSynced == null) {
      return const SizedBox.shrink();
    }

    Color bgColor;
    Color textColor;
    IconData icon;
    String message;

    switch (status) {
      case SyncStatus.syncing:
        bgColor = cs.primaryContainer;
        textColor = cs.onPrimaryContainer;
        icon = Icons.sync;
        message = 'Syncing...';
        break;
      case SyncStatus.success:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.cloud_done_outlined;
        final r = lastResult;
        message = r != null
            ? 'Synced — ↑${r.pushed} pushed, ↓${r.pulled} pulled'
            : 'Sync complete';
        break;
      case SyncStatus.error:
        bgColor = cs.errorContainer;
        textColor = cs.onErrorContainer;
        icon = Icons.cloud_off_outlined;
        message = lastResult?.errorMessage ?? 'Sync failed';
        break;
      case SyncStatus.conflict:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        icon = Icons.warning_amber_outlined;
        message = '${lastResult?.conflicts.length ?? 0} conflict(s) need resolution';
        break;
      case SyncStatus.idle:
        bgColor = cs.surfaceVariant;
        textColor = cs.onSurfaceVariant;
        icon = Icons.cloud_outlined;
        message = lastSynced != null
            ? 'Last synced ${_timeAgo(lastSynced!)}'
            : 'Not synced yet';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          status == SyncStatus.syncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                )
              : Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}