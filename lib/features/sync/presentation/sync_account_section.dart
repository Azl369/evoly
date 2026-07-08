import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:evoly/features/sync/application/supabase_auth_controller.dart';
import 'package:evoly/features/sync/application/sync_coordinator.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

class SyncAccountSection extends StatelessWidget {
  const SyncAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupabaseAuthController>();

    return ListTile(
      leading: Icon(_iconFor(controller.status)),
      title: const Text('数据同步'),
      subtitle: Text(_subtitleFor(controller)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _showSyncSheet(context),
    );
  }

  IconData _iconFor(SupabaseAuthStatus status) {
    return switch (status) {
      SupabaseAuthStatus.unavailable => Icons.cloud_off_outlined,
      SupabaseAuthStatus.signedOut => Icons.cloud_sync_outlined,
      SupabaseAuthStatus.signing => Icons.sync_rounded,
      SupabaseAuthStatus.signedIn => Icons.cloud_done_outlined,
    };
  }

  String _subtitleFor(SupabaseAuthController controller) {
    return switch (controller.status) {
      SupabaseAuthStatus.unavailable => '未配置，当前保持本地模式',
      SupabaseAuthStatus.signedOut => '未登录，同步关闭',
      SupabaseAuthStatus.signing => '正在更新登录状态',
      SupabaseAuthStatus.signedIn =>
        '已登录：${controller.email ?? 'Supabase 用户'} · 同步已开启',
    };
  }

  Future<void> _showSyncSheet(BuildContext context) {
    return showAdaptiveFormModal<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _SyncAccountSheet(),
    );
  }
}

class _SyncAccountSheet extends StatefulWidget {
  const _SyncAccountSheet();

  @override
  State<_SyncAccountSheet> createState() => _SyncAccountSheetState();
}

class _SyncAccountSheetState extends State<_SyncAccountSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBottomSheetBody(
      minHeight: 300,
      child: Consumer<SupabaseAuthController>(
        builder: (context, controller, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('数据同步', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _SyncStatusSummary(controller: controller),
              const SizedBox(height: AppSpacing.md),
              if (controller.status == SupabaseAuthStatus.unavailable)
                const _SupabaseUnavailableState()
              else if (controller.isSignedIn)
                _SignedInActions(controller: controller)
              else
                _SignInForm(
                  controller: controller,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  onToggleObscure: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SyncStatusSummary extends StatelessWidget {
  const _SyncStatusSummary({required this.controller});

  final SupabaseAuthController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorMessage = controller.errorMessage;
    final noticeMessage = controller.noticeMessage;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.62),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _statusBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (noticeMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                noticeMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                errorMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _statusTitle {
    return switch (controller.status) {
      SupabaseAuthStatus.unavailable => '本地模式',
      SupabaseAuthStatus.signedOut => '未登录',
      SupabaseAuthStatus.signing => _busyTitle,
      SupabaseAuthStatus.signedIn => '已登录',
    };
  }

  String get _statusBody {
    return switch (controller.status) {
      SupabaseAuthStatus.unavailable => 'Supabase 未配置，同步保持关闭',
      SupabaseAuthStatus.signedOut => '未登录，同步关闭',
      SupabaseAuthStatus.signing => _busyBody,
      SupabaseAuthStatus.signedIn =>
        '${controller.email ?? 'Supabase 用户'} · 同步已开启',
    };
  }

  String get _busyTitle {
    return switch (controller.operation) {
      SupabaseAuthOperation.signIn => '正在登录',
      SupabaseAuthOperation.signUp => '正在创建账号',
      SupabaseAuthOperation.signOut => '正在退出',
      null => '处理中',
    };
  }

  String get _busyBody {
    return switch (controller.operation) {
      SupabaseAuthOperation.signIn => '正在连接 Supabase 并恢复 session',
      SupabaseAuthOperation.signUp => '正在向 Supabase 创建账号',
      SupabaseAuthOperation.signOut => '正在关闭 session 和本地同步',
      null => '正在更新 session 状态',
    };
  }
}

class _SupabaseUnavailableState extends StatelessWidget {
  const _SupabaseUnavailableState();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.check_rounded),
      label: const Text('知道了'),
    );
  }
}

class _SignedInActions extends StatefulWidget {
  const _SignedInActions({required this.controller});

  final SupabaseAuthController controller;

  @override
  State<_SignedInActions> createState() => _SignedInActionsState();
}

class _SignedInActionsState extends State<_SignedInActions> {
  var _syncing = false;

  @override
  Widget build(BuildContext context) {
    final busy = widget.controller.isBusy || _syncing;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : widget.controller.signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(widget.controller.isBusy ? '退出中' : '退出登录'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : _syncNow,
          icon: _syncing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          label: Text(_syncing ? '同步中' : '立即同步'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: busy ? null : widget.controller.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(widget.controller.isBusy ? '退出中' : '退出登录'),
        ),
      ],
    );
  }

  Future<void> _syncNow() async {
    if (_syncing) {
      return;
    }

    setState(() => _syncing = true);
    try {
      final result = await context.read<SyncCoordinator>().syncNow();
      if (!mounted) {
        return;
      }

      final message = result.skipped
          ? result.message ?? '同步已跳过'
          : result.message ??
              '同步完成：上传 ${result.pushedCount} 条，拉取 ${result.pulledCount} 条';
      _showSnackBar(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('同步失败：$error');
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.controller,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
  });

  final SupabaseAuthController controller;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(context),
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: obscurePassword ? '显示密码' : '隐藏密码',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: controller.isBusy ? null : () => _signIn(context),
            icon: const Icon(Icons.login_rounded),
            label: Text(
              controller.operation == SupabaseAuthOperation.signIn
                  ? '登录中'
                  : '登录',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: controller.isBusy ? null : () => _signUp(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(
              controller.operation == SupabaseAuthOperation.signUp
                  ? '创建中'
                  : '创建账号',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    await controller.signIn(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!context.mounted) {
      return;
    }
    _showAuthFeedback(context);
  }

  Future<void> _signUp(BuildContext context) async {
    await controller.signUp(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!context.mounted) {
      return;
    }
    _showAuthFeedback(context);
  }

  void _showAuthFeedback(BuildContext context) {
    final message = controller.errorMessage ?? controller.noticeMessage;
    if (message == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
