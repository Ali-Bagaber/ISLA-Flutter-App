import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class IslaLogo extends StatelessWidget {
  final double markSize;
  final double textSize;
  final bool showText;
  final MainAxisSize mainAxisSize;

  const IslaLogo({
    super.key,
    this.markSize = 16,
    this.textSize = 18,
    this.showText = true,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;
    final ringColor = primary.withValues(alpha: isDark ? 0.42 : 0.36);
    final dotColor = isDark ? AppTheme.primaryLight : const Color(0xFF7EDDF0);

    return Row(
      mainAxisSize: mainAxisSize,
      children: [
        SizedBox(
          width: markSize,
          height: markSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: markSize,
                height: markSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor,
                    width: (markSize * 0.08).clamp(1.2, 2.2),
                  ),
                ),
              ),
              Container(
                width: markSize * 0.42,
                height: markSize * 0.42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 10),
          Text(
            'ISLA',
            style: TextStyle(
              color: primary,
              fontSize: textSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ],
    );
  }
}

class IslaProfileAvatar extends StatefulWidget {
  final VoidCallback? onTap;
  final double radius;

  const IslaProfileAvatar({
    super.key,
    this.onTap,
    this.radius = 16,
  });

  @override
  State<IslaProfileAvatar> createState() => _IslaProfileAvatarState();
}

class _IslaProfileAvatarState extends State<IslaProfileAvatar> {
  String? _photoUrl;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() => _photoUrl = snap.data()?['photoUrl'] as String?);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppTheme.getSurfaceColor(isDark).withValues(alpha: 0.95);
    final iconColor = AppTheme.getTextSecondary(isDark);
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg,
      backgroundImage: hasPhoto ? NetworkImage(_photoUrl!) : null,
      child: hasPhoto
          ? null
          : Icon(Icons.person, size: widget.radius, color: iconColor),
    );

    if (widget.onTap == null) return avatar;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(widget.radius + 8),
      child: avatar,
    );
  }
}
