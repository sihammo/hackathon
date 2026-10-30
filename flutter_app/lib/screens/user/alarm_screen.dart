import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/emergency_service.dart';

enum _Phase { countdown, sending, done, cancelled }

/// Full-screen alarm: loud sound + 15 s countdown + "I'M OK – CANCEL".
/// If not cancelled, SMS go to police, civil protection and contacts, then a call is placed.
class AlarmScreen extends StatefulWidget {
  final AccidentEvent event;
  final AppUser user;

  const AlarmScreen({super.key, required this.event, required this.user});

  static bool _showing = false;

  /// Opens the alarm unless one is already on screen.
  static Future<void> show(BuildContext context, AccidentEvent event) async {
    if (_showing) return;
    final user = context.read<SessionController>().user;
    if (user == null || user.isAdmin) return;
    _showing = true;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AlarmScreen(event: event, user: user),
        ),
      );
    } finally {
      _showing = false;
    }
  }

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final _player = AudioPlayer();
  late final EmergencyService _emergency;
  late Future<PreparedAlert> _prep;
  Timer? _timer;
  int _left = AppConstants.countdownSeconds;
  bool _flash = false;
  _Phase _phase = _Phase.countdown;
  DispatchResult? _result;

  @override
  void initState() {
    super.initState();
    _emergency = context.read<EmergencyService>();
    _prep = _prepare();
    _emergency.showOverLockScreen(true);
    _startSound();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    HapticFeedback.heavyImpact();
  }

  Future<PreparedAlert> _prepare() async {
    try {
      return await _emergency
          .prepare(widget.user, widget.event)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Minimal fallback: user's own wilaya, defaults (test mode forced).
      return PreparedAlert(
        point: null,
        wilaya: Wilayas.byCode(widget.user.wilayaCode) ?? Wilayas.byCode(16)!,
        numbers: null,
        contacts: const [],
        config: AppConfig.defaults,
      );
    }
  }

  Future<void> _startSound() async {
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      ));
    } catch (_) {}
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alarm.wav'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> _stopSound() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  void _tick() {
    if (!mounted || _phase != _Phase.countdown) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _left--;
      _flash = !_flash;
    });
    if (_left <= 0) _send();
  }

  Future<void> _cancel() async {
    if (_phase != _Phase.countdown) return;
    _timer?.cancel();
    await _stopSound();
    setState(() => _phase = _Phase.cancelled);
    PreparedAlert? p;
    try {
      p = await _prep.timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _emergency.recordCancelled(widget.user, widget.event, p);
  }

  Future<void> _send() async {
    if (_phase != _Phase.countdown) return;
    _timer?.cancel();
    setState(() => _phase = _Phase.sending);
    final p = await _prep;
    // Stop the siren before the phone call starts.
    await _stopSound();
    final r = await _emergency.dispatch(widget.user, widget.event, p);
    if (!mounted) return;
    setState(() {
      _result = r;
      _phase = _Phase.done;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.stop().catchError((_) {});
    _player.dispose();
    _emergency.showOverLockScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canLeave = _phase == _Phase.done || _phase == _Phase.cancelled;
    return PopScope(
      canPop: canLeave,
      child: Scaffold(
        backgroundColor: _bg(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_phase) {
              _Phase.countdown => _countdown(context),
              _Phase.sending => _sending(context),
              _Phase.done => _done(context),
              _Phase.cancelled => _cancelled(context),
            },
          ),
        ),
      ),
    );
  }

  Color _bg() {
    switch (_phase) {
      case _Phase.countdown:
        return _flash ? AppColors.emergencyBlack : AppColors.emergencyRed;
      case _Phase.sending:
        return AppColors.emergencyRed;
      case _Phase.done:
        return AppColors.emergencyBlack;
      case _Phase.cancelled:
        return AppColors.brand;
    }
  }

  Widget _countdown(BuildContext context) {
    const white = Colors.white;
    final e = widget.event;
    return Column(
      children: [
        if (widget.user.testMode) _pill(context.tr('test_mode_active')),
        const Spacer(),
        const Icon(Icons.warning_amber_rounded, color: white, size: 88),
        const SizedBox(height: 12),
        Text(context.tr('accident_detected'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: white, fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(_triggerText(context, e),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 32),
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _left / AppConstants.countdownSeconds,
                strokeWidth: 10,
                color: white,
                backgroundColor: Colors.white24,
              ),
              Center(
                child: Text('$_left',
                    style: const TextStyle(color: white, fontSize: 72, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(context.tr('alert_in_seconds').replaceAll('{s}', '$_left'),
            textAlign: TextAlign.center, style: const TextStyle(color: white, fontSize: 16)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 96,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergencyBlack,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            onPressed: _cancel,
            child: Text(context.tr('im_ok_cancel'), textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() => _left = 0);
            _send();
          },
          child: Text(context.tr('send_now'), style: const TextStyle(color: white)),
        ),
      ],
    );
  }

  Widget _sending(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(context.tr('sending_alert'),
                style: const TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
      );

  Widget _done(BuildContext context) {
    final r = _result!;
    const white = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(r.smsOk.isNotEmpty || r.called != null ? Icons.check_circle : Icons.error,
            color: white, size: 88),
        const SizedBox(height: 16),
        Text(context.tr(r.smsOk.isNotEmpty || r.called != null ? 'alert_sent' : 'alert_failed'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        if (r.testMode) _pill(context.tr('test_mode_sent_note')),
        if (r.missingTestNumber) _pill(context.tr('test_number_missing')),
        _line(Icons.sms, '${context.tr('sms_sent_to')}: ${r.smsOk.isEmpty ? '—' : r.smsOk.join(', ')}'),
        if (r.smsFailed.isNotEmpty)
          _line(Icons.sms_failed, '${context.tr('sms_failed')}: ${r.smsFailed.join(', ')}'),
        _line(Icons.call, '${context.tr('called')}: ${r.called ?? '—'}'),
        _line(Icons.location_on,
            r.hasLocation ? context.tr('location_included') : context.tr('location_unavailable')),
        _line(Icons.cloud_done,
            r.alertId != null ? context.tr('alert_saved') : context.tr('alert_not_saved')),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergencyRed, foregroundColor: white),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
      ],
    );
  }

  Widget _cancelled(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.verified_user, color: Colors.white, size: 96),
          const SizedBox(height: 16),
          Text(context.tr('alert_cancelled'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(context.tr('alert_cancelled_desc'),
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.brand),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('close')),
          ),
        ],
      );

  String _triggerText(BuildContext context, AccidentEvent e) {
    final parts = <String>[context.tr('trigger_${e.trigger}')];
    if (e.peakG != null) parts.add('${e.peakG!.toStringAsFixed(1)} g');
    if (e.tilt != null) parts.add('${e.tilt!.toStringAsFixed(0)}°');
    return parts.join(' • ');
  }

  Widget _pill(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      );

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15))),
          ],
        ),
      );
}
