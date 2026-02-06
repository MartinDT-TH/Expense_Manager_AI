import 'package:flutter/material.dart';

/// Badge to indicate sync status of a transaction/entity
/// Shows a small icon when the item is not synced (pending upload)
class SyncStatusBadge extends StatelessWidget {
  final bool isSynced;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const SyncStatusBadge({
    super.key,
    required this.isSynced,
    this.size = 16,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isSynced) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.orange.shade600,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.cloud_upload_outlined,
        size: size * 0.625,
        color: iconColor ?? Colors.white,
      ),
    );
  }
}

/// A more detailed sync status indicator with text
class SyncStatusIndicator extends StatelessWidget {
  final bool isSynced;
  final bool isCompact;

  const SyncStatusIndicator({
    super.key,
    required this.isSynced,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSynced) {
      if (isCompact) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 14,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Đã đồng bộ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.green.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 14,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'Chờ đồng bộ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating action button style sync indicator
/// Shows pending sync count
class PendingSyncFab extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onPressed;
  final bool isSyncing;

  const PendingSyncFab({
    super.key,
    required this.pendingCount,
    this.onPressed,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0 && !isSyncing) return const SizedBox.shrink();

    return FloatingActionButton.small(
      heroTag: 'sync_fab',
      onPressed: isSyncing ? null : onPressed,
      backgroundColor: isSyncing ? Colors.grey : Colors.orange.shade600,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(Icons.cloud_sync_outlined, size: 20),
          if (pendingCount > 0 && !isSyncing)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  pendingCount > 9 ? '9+' : pendingCount.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner to show at top of screen when there are unsynced items
class PendingSyncBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onSyncPressed;
  final bool isSyncing;

  const PendingSyncBanner({
    super.key,
    required this.pendingCount,
    this.onSyncPressed,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0 && !isSyncing) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSyncing
              ? [Colors.blue.shade400, Colors.blue.shade600]
              : [Colors.orange.shade400, Colors.orange.shade600],
        ),
      ),
      child: Row(
        children: [
          if (isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isSyncing
                  ? 'Đang đồng bộ dữ liệu...'
                  : '$pendingCount giao dịch chờ đồng bộ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isSyncing && onSyncPressed != null)
            GestureDetector(
              onTap: onSyncPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Đồng bộ ngay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
