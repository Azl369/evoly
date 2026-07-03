import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class SlideSelectField<T> extends StatefulWidget {
  const SlideSelectField({
    required this.label,
    required this.values,
    required this.value,
    required this.labelBuilder,
    required this.icon,
    required this.colorBuilder,
    required this.onChanged,
    super.key,
    this.compact = false,
    this.semanticHint,
  }) : assert(values.length > 0);

  final String label;
  final List<T> values;
  final T value;
  final String Function(T value) labelBuilder;
  final IconData icon;
  final Color Function(BuildContext context, T value) colorBuilder;
  final ValueChanged<T> onChanged;
  final bool compact;
  final String? semanticHint;

  @override
  State<SlideSelectField<T>> createState() => _SlideSelectFieldState<T>();
}

class _SlideSelectFieldState<T> extends State<SlideSelectField<T>> {
  static const _dragStep = 38.0;
  static const _optionHeight = 34.0;
  static const _optionGap = 4.0;
  static const _floatingWidth = 112.0;

  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  var _isDragging = false;
  var _dragStartIndex = 0;
  int? _previewIndex;

  @override
  void didUpdateWidget(covariant SlideSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _overlayEntry?.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _previewIndex ?? _selectedIndex;
    final value = widget.values[selectedIndex];
    final valueLabel = widget.labelBuilder(value);
    final accentColor = widget.colorBuilder(context, value);
    final nextLabel = selectedIndex + 1 < widget.values.length
        ? widget.labelBuilder(widget.values[selectedIndex + 1])
        : null;
    final previousLabel = selectedIndex - 1 >= 0
        ? widget.labelBuilder(widget.values[selectedIndex - 1])
        : null;

    return Semantics(
      button: true,
      label: widget.label,
      value: valueLabel,
      hint: widget.semanticHint ?? '长按后上下滑动调整，也可以用方向键调整',
      increasedValue: nextLabel,
      decreasedValue: previousLabel,
      onIncrease: nextLabel == null ? null : _selectNext,
      onDecrease: previousLabel == null ? null : _selectPrevious,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): _selectNext,
          const SingleActivator(LogicalKeyboardKey.arrowRight): _selectNext,
          const SingleActivator(LogicalKeyboardKey.arrowUp): _selectPrevious,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _selectPrevious,
        },
        child: Focus(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: _handleLongPressStart,
            onLongPressMoveUpdate: _handleLongPressMoveUpdate,
            onLongPressEnd: (_) => _finishGesture(),
            onLongPressCancel: _finishGesture,
            child: RepaintBoundary(
              key: _fieldKey,
              child: _SlideSelectSurface(
                label: widget.label,
                valueLabel: valueLabel,
                icon: widget.icon,
                accentColor: accentColor,
                isActive: _isDragging,
                compact: widget.compact,
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get _selectedIndex {
    final index = widget.values.indexOf(widget.value);
    return index < 0 ? 0 : index.clamp(0, widget.values.length - 1).toInt();
  }

  int get _visibleSideCount {
    if (widget.values.length <= 1) {
      return 0;
    }
    return widget.values.length <= 3 ? widget.values.length - 1 : 2;
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _isDragging = true;
      _dragStartIndex = _selectedIndex;
      _previewIndex = _selectedIndex;
    });
    _showOverlay();
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _selectByDragOffset(details.localOffsetFromOrigin.dy);
  }

  void _selectByDragOffset(double dragOffset) {
    final steps = (dragOffset / _dragStep).round();
    final nextIndex =
        (_dragStartIndex + steps).clamp(0, widget.values.length - 1).toInt();
    _selectIndex(nextIndex);
  }

  void _selectNext() {
    _selectIndex(
        (_selectedIndex + 1).clamp(0, widget.values.length - 1).toInt());
  }

  void _selectPrevious() {
    _selectIndex(
        (_selectedIndex - 1).clamp(0, widget.values.length - 1).toInt());
  }

  void _selectIndex(int index) {
    final nextIndex = index.clamp(0, widget.values.length - 1).toInt();
    final currentIndex = _previewIndex ?? _selectedIndex;
    if (nextIndex == currentIndex) {
      return;
    }

    HapticFeedback.selectionClick();
    if (_isDragging) {
      setState(() => _previewIndex = nextIndex);
    }
    widget.onChanged(widget.values[nextIndex]);
    _overlayEntry?.markNeedsBuild();
  }

  void _finishGesture() {
    if (!_isDragging) {
      return;
    }

    _removeOverlay();
    setState(() {
      _isDragging = false;
      _previewIndex = null;
    });
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final rect = _fieldRectFor(overlay);
        if (rect == null) {
          return const SizedBox.shrink();
        }

        final selectedIndex = _previewIndex ?? _selectedIndex;
        return Theme(
          data: theme,
          child: _SlideSelectOverlay<T>(
            fieldRect: rect,
            values: widget.values,
            selectedIndex: selectedIndex,
            sideCount: _visibleSideCount,
            labelBuilder: widget.labelBuilder,
            colorBuilder: widget.colorBuilder,
            optionHeight: _optionHeight,
            optionGap: _optionGap,
            floatingWidth: _floatingWidth,
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  Rect? _fieldRectFor(OverlayState overlay) {
    final context = _fieldKey.currentContext;
    if (context == null) {
      return null;
    }

    final renderObject = context.findRenderObject();
    final overlayObject = overlay.context.findRenderObject();
    if (renderObject is! RenderBox || overlayObject is! RenderBox) {
      return null;
    }

    final topLeft = renderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    return topLeft & renderObject.size;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _SlideSelectSurface extends StatelessWidget {
  const _SlideSelectSurface({
    required this.label,
    required this.valueLabel,
    required this.icon,
    required this.accentColor,
    required this.isActive,
    required this.compact,
  });

  final String label;
  final String valueLabel;
  final IconData icon;
  final Color accentColor;
  final bool isActive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : (isActive ? MotionTokens.normal : MotionTokens.fast);

    return AnimatedSlide(
      duration: duration,
      curve: MotionTokens.standard,
      offset: isActive ? const Offset(0, -0.045) : Offset.zero,
      child: AnimatedScale(
        duration: duration,
        curve: isActive ? MotionTokens.emphasized : MotionTokens.standard,
        scale: isActive ? 1.018 : 1,
        child: AnimatedContainer(
          duration: duration,
          curve: MotionTokens.standard,
          constraints: BoxConstraints(
            minHeight: compact ? 50 : AppSpacing.minTouchTarget,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.compact : AppSpacing.md,
            vertical: compact ? AppSpacing.sm : AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: isActive ? tokens.surfaceRaised : tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: isActive
                  ? accentColor.withValues(alpha: 0.34)
                  : tokens.outlineSubtle,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: compact ? 18 : 20, color: accentColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            valueLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (!compact)
                AnimatedScale(
                  duration: duration,
                  curve: isActive
                      ? MotionTokens.emphasized
                      : MotionTokens.standard,
                  scale: isActive ? 1.08 : 1,
                  child: _SelectedValuePill(
                    label: valueLabel,
                    color: accentColor,
                    elevated: isActive,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.unfold_more_rounded,
                size: compact ? 18 : 24,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideSelectOverlay<T> extends StatelessWidget {
  const _SlideSelectOverlay({
    required this.fieldRect,
    required this.values,
    required this.selectedIndex,
    required this.sideCount,
    required this.labelBuilder,
    required this.colorBuilder,
    required this.optionHeight,
    required this.optionGap,
    required this.floatingWidth,
  });

  final Rect fieldRect;
  final List<T> values;
  final int selectedIndex;
  final int sideCount;
  final String Function(T value) labelBuilder;
  final Color Function(BuildContext context, T value) colorBuilder;
  final double optionHeight;
  final double optionGap;
  final double floatingWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topSafe = mediaQuery.padding.top + AppSpacing.sm;
    final bottomSafe =
        mediaQuery.size.height - mediaQuery.padding.bottom - AppSpacing.sm;
    final left = (fieldRect.right - floatingWidth - AppSpacing.lg)
        .clamp(AppSpacing.sm,
            mediaQuery.size.width - floatingWidth - AppSpacing.sm)
        .toDouble();
    final aboveValues = _valuesAbove;
    final belowValues = _valuesBelow;
    final itemExtent = optionHeight + optionGap;
    final aboveHeight = aboveValues.length * itemExtent;
    final belowHeight = belowValues.length * itemExtent;
    final aboveTop = (fieldRect.top - optionGap - aboveHeight)
        .clamp(topSafe, bottomSafe - aboveHeight)
        .toDouble();
    final belowTop = (fieldRect.bottom + optionGap)
        .clamp(topSafe, bottomSafe - belowHeight)
        .toDouble();

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            for (final entry in aboveValues.indexed)
              Positioned(
                left: left,
                top: aboveTop + entry.$1 * itemExtent,
                width: floatingWidth,
                child: _SlideOptionPill(
                  label: labelBuilder(entry.$2),
                  color: colorBuilder(context, entry.$2),
                  height: optionHeight,
                ),
              ),
            for (final entry in belowValues.indexed)
              Positioned(
                left: left,
                top: belowTop + entry.$1 * itemExtent,
                width: floatingWidth,
                child: _SlideOptionPill(
                  label: labelBuilder(entry.$2),
                  color: colorBuilder(context, entry.$2),
                  height: optionHeight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<T> get _valuesAbove {
    final start = (selectedIndex - sideCount).clamp(0, selectedIndex).toInt();
    return values.sublist(start, selectedIndex);
  }

  List<T> get _valuesBelow {
    final end = (selectedIndex + sideCount + 1)
        .clamp(selectedIndex + 1, values.length)
        .toInt();
    return values.sublist(selectedIndex + 1, end);
  }
}

class _SelectedValuePill extends StatelessWidget {
  const _SelectedValuePill({
    required this.label,
    required this.color,
    required this.elevated,
  });

  final String label;
  final Color color;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MotionTokens.normal,
      curve: MotionTokens.standard,
      decoration: BoxDecoration(
        color: color.withValues(alpha: elevated ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: color.withValues(alpha: elevated ? 0.32 : 0.20),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 1,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _SlideOptionPill extends StatelessWidget {
  const _SlideOptionPill({
    required this.label,
    required this.color,
    required this.height,
  });

  final String label;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MotionTokens.normal;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: MotionTokens.standard,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 6),
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: tokens.shadowSoft,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
