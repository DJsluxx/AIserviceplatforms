import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications` so the rest of the app can stay
/// platform-agnostic. The plugin doesn't support web, so every public
/// method here short-circuits when [kIsWeb] is true.
///
/// Strategy for "background notifications": when the app goes to the
/// background we schedule a handful of local notifications at staggered
/// intervals over the next few hours, telling the user the package has
/// arrived. When the app comes back to the foreground, all scheduled
/// notifications are cancelled.
///
/// Until we have a real backend pushing arrivals, this is the closest
/// honest approximation — the user gets a regular drumbeat of "open
/// PEELED, the package is here" pings without any server round-trips.
class NotificationService {
  static const _channelId = 'peeled_arrivals';
  static const _channelName = 'Package arrivals';
  static const _channelDesc = "Buzz when the package lands in your hands.";
  static const int _baseId = 1000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;
  final Random _rng = Random();

  /// Deep-link payload used on every scheduled/immediate notification.
  /// When the user taps the notification, the payload is handed to
  /// [onTap] (set by the app). The convention is a go_router path,
  /// e.g. `"/opening/pkg_123"`, or the sentinel `"/home"` when no
  /// specific package is known yet.
  String _lastPayload = '/home';

  /// App-level callback fired with the notification payload when the
  /// user taps a PEELED notification. Set once from main.dart so the
  /// router can navigate.
  void Function(String payload)? onTap;

  /// Initialise the plugin, request permission on Android 13+ / iOS,
  /// and create the Android channel. Safe to call repeatedly. Returns
  /// quietly on web.
  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload ?? _lastPayload;
        onTap?.call(payload);
      },
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
      try {
        await androidImpl.requestNotificationsPermission();
      } catch (_) {/* older Android, no-op */}
    }
    _initialized = true;
  }

  void setEnabled(bool v) {
    _enabled = v;
    if (!v) cancelAll();
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) debugPrint('cancelAll failed: $e');
    }
  }

  /// Called when the app goes to the background. Schedules a small
  /// staggered set of "package arrived" reminders across the next few
  /// hours so the player stays engaged even when PEELED is closed.
  Future<void> scheduleBackgroundReminders() async {
    if (kIsWeb || !_enabled || !_initialized) return;
    await cancelAll();

    final messages = _arrivalMessages();
    final offsets = <Duration>[
      Duration(seconds: 180 + _rng.nextInt(120)),
      Duration(minutes: 18 + _rng.nextInt(8)),
      Duration(minutes: 55 + _rng.nextInt(20)),
      Duration(hours: 2, minutes: 50 + _rng.nextInt(40)),
    ];
    for (var i = 0; i < offsets.length; i++) {
      final msg = messages[_rng.nextInt(messages.length)];
      final when = tz.TZDateTime.from(
        DateTime.now().add(offsets[i]),
        tz.local,
      );
      try {
        await _plugin.zonedSchedule(
          _baseId + i,
          '🎁 Your package just arrived',
          msg,
          when,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: _lastPayload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('schedule[$i] failed: $e');
      }
    }
  }

  /// Foreground arrival ping. Called from the simulator when the
  /// package lands in the user's hands while the app is open. If
  /// [deepLink] is provided it becomes the notification's tap payload;
  /// we also store it as a fallback for the staggered reminders that
  /// fire later.
  Future<void> showImmediate(String body, {String? deepLink}) async {
    if (kIsWeb || !_enabled || !_initialized) return;
    final payload = deepLink ?? _lastPayload;
    _lastPayload = payload;
    try {
      await _plugin.show(
        0,
        '🎁 Your package just arrived',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (_) {/* swallow */}
  }

  List<String> _arrivalMessages() => const [
        'Open PEELED — you have one peel attempt waiting.',
        "It's your turn. Tap before the package hops away.",
        'Time to peel. One shot. Feeling lucky?',
        'A mystery package just landed in your hands.',
      ];
}
