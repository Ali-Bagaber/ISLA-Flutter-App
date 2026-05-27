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
    this.markSize = 28,
    this.textSize = 17,
    this.showText = true,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/isla_logo_512.png',
          width: markSize,
          height: markSize,
          fit: BoxFit.contain,
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF81ECFF), Color(0xFF4A90D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'ISLA',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: textSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Colors.white,
              ),
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

    final size = widget.radius * 2;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.network(
              _photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person, size: widget.radius, color: iconColor),
            )
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
