import 'package:flutter/material.dart';

/// Plays a one-time fade + slide-up when a screen's content first mounts.
///
/// Robust by design: the controller lives in [State], so it survives rebuilds
/// (stream updates, setState) and never replays. Place it at a STABLE position
/// in the tree — e.g. wrapping a `StreamBuilder` — NOT around list items that
/// are added/removed (that's what caused the earlier replay/lifecycle issues).
class PageEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double dy;

  const PageEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 480),
    this.dy = 0.035,
  });

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: Offset(0, widget.dy), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
