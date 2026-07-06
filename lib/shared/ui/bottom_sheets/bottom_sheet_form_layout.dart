import 'package:flutter/material.dart';
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
