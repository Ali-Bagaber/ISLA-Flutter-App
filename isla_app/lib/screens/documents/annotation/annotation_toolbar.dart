import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'annotation_models.dart';

/// Shared palette for the annotation board (always dark, premium ISLA look).
class AnnotationStyle {
  static const Color bg = Color(0xFF05101F); // dark navy
  static const Color bar = Color(0xFF0B1B2E); // toolbar surface
  static const Color barBorder = Color(0xFF18324A);
  static const Color accent = AppTheme.primaryColor; // cyan
  static const Color icon = Color(0xFFB9C7D6);
  static const Color iconDim = Color(0xFF5C6F82);

  /// Pen colors offered in the tool bar.
  static const List<Color> penColors = [
    AppTheme.primaryColor, // cyan
    Color(0xFFFF4D4D), // red
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFFF9F0A), // orange
    Color(0xFFA855F7), // purple
    Color(0xFF111111), // black
  ];

  /// Pen widths in PDF points: small / medium / large.
  static const List<double> penWidths = [1.5, 3.0, 6.0];
}

/// Top toolbar: back, draw/view mode, undo, redo, clear page, save.
class AnnotationTopToolbar extends StatelessWidget {
  final String title;
  final bool drawMode;
  final bool dirty;
  final bool saving;
  final bool canUndo;
  final bool canRedo;
  final bool canClear;

  /// When false the PDF has not rendered yet — drawing/Save controls are hidden
  /// and only Back (plus an optional Retry) remain.
  final bool enabled;
  final VoidCallback? onRetry;
  final VoidCallback onBack;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClearPage;
  final VoidCallback onSave;

  const AnnotationTopToolbar({
    super.key,
    required this.title,
    required this.drawMode,
    required this.dirty,
    required this.saving,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.onBack,
    required this.onModeChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClearPage,
    required this.onSave,
    this.enabled = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AnnotationStyle.bar,
        border: Border(
          bottom: BorderSide(color: AnnotationStyle.barBorder),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 4),
              _BarIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: onBack,
              ),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (dirty)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9F0A),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
              if (enabled) ...[
                _ModeToggle(drawMode: drawMode, onChanged: onModeChanged),
                const SizedBox(width: 4),
                _BarIconButton(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: canUndo,
                  onTap: onUndo,
                ),
                _BarIconButton(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: canRedo,
                  onTap: onRedo,
                ),
                _BarIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Clear page',
                  enabled: canClear,
                  onTap: onClearPage,
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 8),
                  child: _SaveButton(saving: saving, onTap: onSave),
                ),
              ] else if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                        foregroundColor: AnnotationStyle.accent),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool drawMode;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.drawMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AnnotationStyle.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AnnotationStyle.barBorder),
      ),
      child: Row(
        children: [
          _segment(
            label: 'Draw',
            icon: Icons.edit_rounded,
            selected: drawMode,
            onTap: () => onChanged(true),
          ),
          _segment(
            label: 'View',
            icon: Icons.pan_tool_alt_rounded,
            selected: !drawMode,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AnnotationStyle.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.black : AnnotationStyle.iconDim),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : AnnotationStyle.iconDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AnnotationStyle.accent, Color(0xFF00B8D4)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AnnotationStyle.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saving)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            else
              const Icon(Icons.save_rounded, size: 16, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              saving ? 'Saving' : 'Save',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        splashRadius: 20,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          icon,
          size: 20,
          color: enabled ? AnnotationStyle.icon : AnnotationStyle.iconDim,
        ),
      ),
    );
  }
}

/// Bottom tool bar: tools (pen / highlighter / eraser), colors and sizes.
class AnnotationToolBar extends StatelessWidget {
  final AnnotationTool tool;
  final int colorValue;
  final double penWidth;
  final ValueChanged<AnnotationTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onClearAll;

  const AnnotationToolBar({
    super.key,
    required this.tool,
    required this.colorValue,
    required this.penWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
    required this.onClearAll,
  });

  bool get _colorEnabled => tool != AnnotationTool.eraser;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AnnotationStyle.bar,
        border: Border(top: BorderSide(color: AnnotationStyle.barBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1 — tools + clear all
              Row(
                children: [
                  _ToolChip(
                    icon: Icons.edit_rounded,
                    label: 'Pen',
                    selected: tool == AnnotationTool.pen,
                    onTap: () => onToolChanged(AnnotationTool.pen),
                  ),
                  const SizedBox(width: 8),
                  _ToolChip(
                    icon: Icons.brush_rounded,
                    label: 'Marker',
                    selected: tool == AnnotationTool.highlighter,
                    onTap: () => onToolChanged(AnnotationTool.highlighter),
                  ),
                  const SizedBox(width: 8),
                  _ToolChip(
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Eraser',
                    selected: tool == AnnotationTool.eraser,
                    onTap: () => onToolChanged(AnnotationTool.eraser),
                  ),
                  const Spacer(),
                  _SizeDots(
                    width: penWidth,
                    enabled: _colorEnabled,
                    onChanged: onWidthChanged,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2 — colors + clear all
              Row(
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: _colorEnabled ? 1 : 0.35,
                      child: IgnorePointer(
                        ignoring: !_colorEnabled,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final c in AnnotationStyle.penColors)
                              _ColorDot(
                                color: c,
                                selected: _colorEnabled &&
                                    colorValue == c.toARGB32(),
                                onTap: () => onColorChanged(c),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClearAll,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AnnotationStyle.barBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_clear_rounded,
                              size: 15, color: AnnotationStyle.iconDim),
                          SizedBox(width: 5),
                          Text('All',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AnnotationStyle.iconDim)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AnnotationStyle.accent.withValues(alpha: 0.15)
              : AnnotationStyle.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AnnotationStyle.accent : AnnotationStyle.barBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color:
                    selected ? AnnotationStyle.accent : AnnotationStyle.iconDim),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AnnotationStyle.iconDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeDots extends StatelessWidget {
  final double width;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SizeDots({
    required this.width,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final w in AnnotationStyle.penWidths)
              GestureDetector(
                onTap: () => onChanged(w),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    color: width == w
                        ? AnnotationStyle.accent.withValues(alpha: 0.15)
                        : AnnotationStyle.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: width == w
                          ? AnnotationStyle.accent
                          : AnnotationStyle.barBorder,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: w * 2.2,
                      height: w * 2.2,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
