import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeAreaBody = false,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool safeAreaBody;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title), actions: actions),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.backgroundGradient),
        child: safeAreaBody ? SafeArea(child: body) : body,
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.compact,
      AppSpacing.md,
      AppSpacing.xs,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppGlassSurface extends StatefulWidget {
  const AppGlassSurface({
    required this.child,
    super.key,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.borderColor,
    this.radius = AppRadii.lg,
    this.elevated = false,
    this.selected = false,
    this.blur = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final bool elevated;
  final bool selected;
  final bool blur;
  final Clip clipBehavior;

  @override
  State<AppGlassSurface> createState() => _AppGlassSurfaceState();
}

class _AppGlassSurfaceState extends State<AppGlassSurface> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final baseColor = widget.backgroundColor ?? tokens.glassSurfaceRaised;
    final color = _surfaceColor(tokens, baseColor);
    final border = widget.borderColor ??
        (widget.selected ? tokens.glassBorderStrong : tokens.glassBorder);
    final borderRadius = BorderRadius.circular(widget.radius);
    final blurSigma = widget.blur ? tokens.glassBlurSigma : 0.0;
    final decoratedChild = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              tokens.glassHighlight.withValues(alpha: 0.08),
              color,
            ),
            color,
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: border),
        boxShadow: _shadow(tokens),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: widget.clipBehavior,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: Colors.transparent,
            clipBehavior: widget.clipBehavior,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: borderRadius,
              onHover: (hovered) => setState(() => _hovered = hovered),
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: widget.margin,
      child: decoratedChild,
    );
  }

  Color _surfaceColor(EvolyDesignTokens tokens, Color baseColor) {
    if (widget.selected) {
      return Color.alphaBlend(
        tokens.hudAccent.withValues(alpha: 0.12),
        baseColor,
      );
    }
    if (_hovered && widget.onTap != null) {
      return Color.alphaBlend(
        tokens.hudAccent.withValues(alpha: 0.06),
        baseColor,
      );
    }
    return baseColor;
  }

  List<BoxShadow>? _shadow(EvolyDesignTokens tokens) {
    if (!widget.elevated && !_hovered && !widget.selected) {
      return null;
    }

    return [
      BoxShadow(
        color: tokens.glassShadow,
        blurRadius: widget.selected || _hovered ? 24 : 18,
        offset: const Offset(0, 10),
      ),
    ];
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    this.backgroundColor,
    this.borderColor,
    this.radius = AppRadii.lg,
    this.elevated = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final bool elevated;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    return AppGlassSurface(
      onTap: onTap,
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor ?? tokens.glassSurfaceRaised,
      borderColor: borderColor,
      radius: radius,
      elevated: elevated,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class AppListCard extends StatelessWidget {
  const AppListCard({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.meta,
    this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? meta;
  final VoidCallback? onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);

    return AppSurfaceCard(
      onTap: onTap,
      elevated: selected,
      backgroundColor: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.36)
          : tokens.glassSurfaceRaised,
      borderColor: selected ? tokens.glassBorderStrong : null,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: compact ? AppSpacing.sm : AppSpacing.compact,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  subtitle!,
                ],
                if (meta != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  meta!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppMetaPill extends StatelessWidget {
  const AppMetaPill({
    required this.label,
    super.key,
    this.icon,
    this.color,
    this.selected = false,
    this.compact = true,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final accent = color ?? colorScheme.onSurfaceVariant;
    final background =
        selected ? accent.withValues(alpha: 0.14) : tokens.glassSurfaceSubtle;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border:
            Border.all(color: accent.withValues(alpha: selected ? 0.28 : 0)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? 3 : AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppMetaPill(
      label: label,
      icon: icon,
      color: color,
      selected: true,
    );
  }
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    super.key,
    this.subtitle,
    this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = color ?? colorScheme.primary;

    return AppSurfaceCard(
      onTap: onTap,
      elevated: onTap != null,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon, color: accent, size: 22),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: theme.textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    this.label,
    this.compact = false,
  });

  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = this.label;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 18 : 28,
              height: compact ? 18 : 28,
              child: CircularProgressIndicator(strokeWidth: compact ? 2 : 2.6),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
