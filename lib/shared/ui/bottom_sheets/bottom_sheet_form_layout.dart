import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

class BottomSheetFormLayout extends StatelessWidget {
  const BottomSheetFormLayout({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.trailing,
    this.footer,
    this.minHeight = 280,
    this.spacing = AppSpacing.compact,
    this.headerSpacing = AppSpacing.md,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final Widget? footer;
  final double minHeight;
  final double spacing;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    if (EvolyFormPresentationScope.of(context) ==
        EvolyFormPresentation.fullScreen) {
      return _FullScreenFormLayout(
        title: title,
        subtitle: this.subtitle,
        trailing: this.trailing,
        footer: this.footer,
        spacing: spacing,
        headerSpacing: headerSpacing,
        children: children,
      );
    }

    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    final footer = this.footer;

    return ResponsiveBottomSheetBody(
      minHeight: minHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing,
              ],
            ],
          ),
          if (children.isNotEmpty) ...[
            SizedBox(height: headerSpacing),
            ..._spaced(children, spacing),
          ],
          if (footer != null) ...[
            SizedBox(height: headerSpacing),
            footer,
          ],
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> children, double spacing) {
    return [
      for (var index = 0; index < children.length; index += 1) ...[
        if (index > 0) SizedBox(height: spacing),
        children[index],
      ],
    ];
  }
}

class _FullScreenFormLayout extends StatelessWidget {
  const _FullScreenFormLayout({
    required this.title,
    required this.children,
    required this.spacing,
    required this.headerSpacing,
    this.subtitle,
    this.trailing,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final List<Widget> children;
  final double spacing;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final trailing = this.trailing;
    final footer = this.footer;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleLarge),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(subtitle, style: theme.textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (trailing != null || footer != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (trailing != null) trailing,
                        if (footer != null) footer,
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _KeyboardAwareFormScrollView(
                spacing: spacing,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyboardAwareFormScrollView extends StatelessWidget {
  const _KeyboardAwareFormScrollView({
    required this.children,
    required this.spacing,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        keyboardInset + AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (children.isNotEmpty)
            ...BottomSheetFormLayout._spaced(children, spacing),
        ],
      ),
    );
  }
}
