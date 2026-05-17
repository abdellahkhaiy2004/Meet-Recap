import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ── Payload ────────────────────────────────────────────────────────────────────

/// Data encoded in every notification payload so the tap handler can navigate.
class NotificationPayload {
  const NotificationPayload({required this.folderId, required this.eventId});

  final int folderId;
  final int eventId;

  String encode() => jsonEncode({'folderId': folderId, 'eventId': eventId});

  static NotificationPayload? decode(String? raw) {
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload(
        folderId: map['folderId'] as int,
        eventId: map['eventId'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Service ────────────────────────────────────────────────────────────────────

/// Wraps `flutter_local_notifications` for meeting reminders (architecture §7).
///
/// **Initialisation** — call [init] once in `main()` before `runApp`.
/// **Deep-link on tap** — bind a [GoRouter] reference via [bindOnTap] after
/// the router is created; the service calls it with the route string when the
/// user taps a notification.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  void Function(String route)? _onTap;

  static const _channelId = 'meeting_reminders';
  static const _channelName = 'Rappels de réunion';

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    // Create the Android notification channel.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Notifications de rappel avant vos réunions planifiées',
            importance: Importance.max,
            enableVibration: true,
          ),
        );
  }

  // ── Deep-link binding ──────────────────────────────────────────────────────

  /// Called once from App after the GoRouter is created.
  void bindOnTap(void Function(String route) handler) => _onTap = handler;

  // ── Schedule ───────────────────────────────────────────────────────────────

  /// Schedules a local notification at [fireAt] for the given [eventId].
  ///
  /// [notificationId] must match the value stored in `CalendarEvents.notificationId`
  /// so [cancel] can remove it later.
  ///
  /// ⚠ Android 13+ requires exact-alarm permission — call [requestExactAlarmPermission]
  /// before scheduling and warn the user if denied ([IP-0038]).
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required int folderId,
    required int eventId,
  }) async {
    final tz.TZDateTime tzFire = tz.TZDateTime.from(fireAt, tz.local);

    final payload = NotificationPayload(
      folderId: folderId,
      eventId: eventId,
    ).encode();

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tzFire,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Notifications de rappel avant vos réunions planifiées',
          importance: Importance.max,
          priority: Priority.high,
          ticker: title,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Cancels the notification with [notificationId].
  Future<void> cancel(int notificationId) =>
      _plugin.cancel(notificationId);

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Requests Android exact-alarm permission (API 33+).
  /// Returns true if granted or not required.
  Future<bool> requestExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isGranted) return true;
    final result = await Permission.scheduleExactAlarm.request();
    return result.isGranted;
  }

  /// Returns true if exact-alarm permission is granted (or not required).
  Future<bool> get hasExactAlarmPermission async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return (await Permission.scheduleExactAlarm.status).isGranted;
  }

  // ── Tap handlers ───────────────────────────────────────────────────────────

  void _onResponse(NotificationResponse response) {
    final payload = NotificationPayload.decode(response.payload);
    if (payload == null) return;
    final route =
        '/record?folderId=${payload.folderId}&eventId=${payload.eventId}';
    _onTap?.call(route);
  }
}

// Background handler must be a top-level function.
@pragma('vm:entry-point')
void _onBackgroundResponse(NotificationResponse response) {
  // Navigation is not possible from a background isolate.
  // The tap will be handled when the app is foregrounded via onDidReceiveNotificationResponse.
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService.instance,
);
