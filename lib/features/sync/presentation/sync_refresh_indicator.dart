import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/features/sync/application/sync_coordinator.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';

class SyncRefreshIndicator extends StatelessWidget {
  const SyncRefreshIndicator({
    required this.child,
    this.fallbackRefresh,
    super.key,
  });

  final Widget child;
  final Future<void> Function()? fallbackRefresh;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return child;
    }

    return RefreshIndicator.adaptive(
      onRefresh: () => _sync(context),
      child: child,
    );
  }

  Future<void> _sync(BuildContext context) async {
    final SyncCoordinator coordinator;
    try {
      coordinator = context.read<SyncCoordinator>();
    } on ProviderNotFoundException {
      await fallbackRefresh?.call();
      return;
    }

    try {
      final result = await coordinator.syncNow();
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, _messageFor(result));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      _showSnackBar(context, '同步失败：$error');
    }
  }

  String _messageFor(SyncResult result) {
    if (result.skipped) {
      return result.message ?? '同步已跳过';
    }

    return result.message ??
        '同步完成：上传 ${result.pushedCount} 条，拉取 ${result.pulledCount} 条';
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
