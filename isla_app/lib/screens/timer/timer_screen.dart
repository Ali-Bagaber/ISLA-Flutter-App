import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_provider.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  // Timer settings
  int _workDuration = 25; // minutes
  int _breakDuration = 5; // minutes
  int _longBreakDuration = 15; // minutes
  int _sessionsBeforeLongBreak = 4;

  // Timer state
  int _currentSeconds = 25 * 60;
  int _completedSessions = 0;
  bool _isRunning = false;
  bool _isBreak = false;
  Timer? _timer;

  // Subject selection
  String? _selectedSubject;
  final List<String> _subjects = ['BCS2033', 'BCS3012', 'BCS2042', 'BCS4051'];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
      } else {
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _currentSeconds = _workDuration * 60;
      _isBreak = false;
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;

      if (!_isBreak) {
        _completedSessions++;
        _showSessionCompleteDialog();

        // Switch to break
        if (_completedSessions % _sessionsBeforeLongBreak == 0) {
          _currentSeconds = _longBreakDuration * 60;
        } else {
          _currentSeconds = _breakDuration * 60;
        }
        _isBreak = true;
      } else {
        // Switch back to work
        _currentSeconds = _workDuration * 60;
        _isBreak = false;
      }
    });
  }

  void _showSessionCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 20),
            Text('Session Complete!', style: AppTheme.headingSmall),
            const SizedBox(height: 8),
            Text(
              'Great job! You completed $_completedSessions session(s) today.',
              style:
                  AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Time for a ${_completedSessions % _sessionsBeforeLongBreak == 0 ? 'long' : 'short'} break!',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip Break'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final totalSeconds = _isBreak
        ? (_completedSessions % _sessionsBeforeLongBreak == 0
            ? _longBreakDuration * 60
            : _breakDuration * 60)
        : _workDuration * 60;
    return _currentSeconds / totalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(isDark),
      appBar: AppBar(
        title: const Text('Study Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsBottomSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Session Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isBreak
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: AppTheme.borderRadiusMedium,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isBreak ? Icons.coffee_rounded : Icons.psychology_rounded,
                    color: _isBreak ? AppTheme.success : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBreak ? 'Break Time' : 'Focus Session',
                    style: AppTheme.labelMedium.copyWith(
                      color:
                          _isBreak ? AppTheme.success : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Timer Circle
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background Circle
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 12,
                      backgroundColor: AppTheme.surfaceColor,
                      valueColor: AlwaysStoppedAnimation(
                        AppTheme.surfaceColor,
                      ),
                    ),
                  ),
                  // Progress Circle
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        _isBreak ? AppTheme.success : AppTheme.primaryColor,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Timer Display
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isRunning
                                ? 1 + (_pulseController.value * 0.02)
                                : 1,
                            child: Text(
                              _formatTime(_currentSeconds),
                              style: AppTheme.headingLarge.copyWith(
                                fontSize: 56,
                                fontWeight: FontWeight.w700,
                                color: _isBreak
                                    ? AppTheme.success
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Session $_completedSessions',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Subject Selection
            if (!_isRunning)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppTheme.borderRadiusMedium,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Studying Subject', style: AppTheme.labelMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _subjects.map((subject) {
                        final isSelected = _selectedSubject == subject;
                        return ChoiceChip(
                          label: Text(subject),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() =>
                                _selectedSubject = selected ? subject : null);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset Button
                _CircleButton(
                  icon: Icons.refresh_rounded,
                  onTap: _resetTimer,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 24),

                // Play/Pause Button
                _CircleButton(
                  icon: _isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: _isRunning ? _pauseTimer : _startTimer,
                  color: _isBreak ? AppTheme.success : AppTheme.primaryColor,
                  size: 80,
                  iconSize: 40,
                  filled: true,
                ),
                const SizedBox(width: 24),

                // Skip Button
                _CircleButton(
                  icon: Icons.skip_next_rounded,
                  onTap: () {
                    _timer?.cancel();
                    _onTimerComplete();
                  },
                  color: AppTheme.textSecondary,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Today's Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.borderRadiusLarge,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Progress", style: AppTheme.headingSmall),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          icon: Icons.timer_outlined,
                          value: '${_completedSessions * _workDuration}',
                          unit: 'min',
                          label: 'Total Time',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: AppTheme.surfaceColor,
                      ),
                      Expanded(
                        child: _StatItem(
                          icon: Icons.local_fire_department_rounded,
                          value: '$_completedSessions',
                          unit: '',
                          label: 'Sessions',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: AppTheme.surfaceColor,
                      ),
                      Expanded(
                        child: _StatItem(
                          icon: Icons.emoji_events_rounded,
                          value:
                              '${_completedSessions ~/ _sessionsBeforeLongBreak}',
                          unit: '',
                          label: 'Cycles',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Timer Settings', style: AppTheme.headingSmall),
              const SizedBox(height: 24),
              _SettingSlider(
                label: 'Focus Duration',
                value: _workDuration,
                min: 15,
                max: 60,
                unit: 'min',
                onChanged: (value) {
                  setModalState(() => _workDuration = value.toInt());
                },
              ),
              const SizedBox(height: 20),
              _SettingSlider(
                label: 'Short Break',
                value: _breakDuration,
                min: 3,
                max: 15,
                unit: 'min',
                onChanged: (value) {
                  setModalState(() => _breakDuration = value.toInt());
                },
              ),
              const SizedBox(height: 20),
              _SettingSlider(
                label: 'Long Break',
                value: _longBreakDuration,
                min: 10,
                max: 30,
                unit: 'min',
                onChanged: (value) {
                  setModalState(() => _longBreakDuration = value.toInt());
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (!_isRunning) {
                        _currentSeconds = _workDuration * 60;
                      }
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Apply Settings'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final double iconSize;
  final bool filled;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.size = 56,
    this.iconSize = 28,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: AppTheme.headingMedium.copyWith(
                color: AppTheme.primaryColor,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.labelMedium),
            Text(
              '$value $unit',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: AppTheme.primaryColor,
          inactiveColor: AppTheme.surfaceColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
