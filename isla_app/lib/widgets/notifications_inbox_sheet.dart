import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

void showIslaNotificationsInbox(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _NotificationsInboxSheet(),
  );
}

class _NotificationsInboxSheet extends StatefulWidget {
  const _NotificationsInboxSheet();

  @override
  State<_NotificationsInboxSheet> createState() =>
      _NotificationsInboxSheetState();
}

class _NotificationsInboxSheetState extends State<_NotificationsInboxSheet> {
  List<Map<String, dynamic>> _todayTasks = const [];
  List<Map<String, dynamic>> _upcomingTasks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (Firebase.apps.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final snap = await db
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .get();

    final tasks =
        snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    final active = tasks.where((t) => t['completed'] != true).toList();

    final todayTasks = active.where((t) {
      final d = _toDate(t['dueDate']);
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(today) && day.isBefore(tomorrow);
    }).toList();

    final upcoming = List<Map<String, dynamic>>.from(active)
      ..sort((a, b) => _compareUrgency(a, b, now));

    if (mounted) {
      setState(() {
        _todayTasks = todayTasks;
        _upcomingTasks = upcoming;
        _loading = false;
      });
    }
  }

  DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  int _priorityRank(dynamic p) {
    switch ((p ?? '').toString().toLowerCase()) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }

  int _compareUrgency(
      Map<String, dynamic> a, Map<String, dynamic> b, DateTime now) {
    final ad = _toDate(a['dueDate']);
    final bd = _toDate(b['dueDate']);
    final aOver = ad != null && ad.isBefore(now);
    final bOver = bd != null && bd.isBefore(now);
    if (aOver != bOver) return aOver ? -1 : 1;
    final ap = _priorityRank(a['priority']);
    final bp = _priorityRank(b['priority']);
    if (ap != bp) return ap.compareTo(bp);
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  String _formatDue(dynamic rawDate) {
    final date = _toDate(rawDate);
    if (date == null) return 'No date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(date.year, date.month, date.day);
    final diff = due.difference(today).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text('Notifications', style: AppTheme.headingSmall),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_todayTasks.isEmpty && _upcomingTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "You're all caught up. Nothing to remind you of.",
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(isDark)),
                  ),
                ),
              )
            else ...[
              if (_todayTasks.isNotEmpty) ...[
                Text('Due today',
                    style: AppTheme.labelMedium
                        .copyWith(color: AppTheme.primaryColor)),
                const SizedBox(height: 6),
                ..._todayTasks.take(3).map((t) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.primaryColor),
                      title: Text(t['title']?.toString() ?? ''),
                      subtitle: Text(t['subject']?.toString() ?? ''),
                    )),
                const SizedBox(height: 8),
              ],
              if (_upcomingTasks.isNotEmpty) ...[
                Text('Upcoming',
                    style: AppTheme.labelMedium
                        .copyWith(color: AppTheme.warning)),
                const SizedBox(height: 6),
                ..._upcomingTasks.take(5).map((t) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.access_time_rounded,
                          color: AppTheme.warning),
                      title: Text(t['title']?.toString() ?? ''),
                      subtitle: Text(_formatDue(t['dueDate'])),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
