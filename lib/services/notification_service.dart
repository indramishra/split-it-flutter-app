import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _hasPermission = false;

  bool get hasPermission => _hasPermission;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open');

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');

      // Proactively request permissions on launch
      await requestPermissions();
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) {
        _hasPermission = true;
        return true;
      }

      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidPlugin?.requestNotificationsPermission() ?? false;
        _hasPermission = granted;
        debugPrint('Android Notification Permission Granted: $granted');
        return granted;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final darwinPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await darwinPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        _hasPermission = granted;
        debugPrint('iOS/macOS Notification Permission Granted: $granted');
        return granted;
      }
      _hasPermission = true;
      return true;
    } catch (e) {
      debugPrint('NotificationService requestPermissions error: $e');
      return false;
    }
  }

  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      const androidDetails = AndroidNotificationDetails(
        'splitit_alerts_channel',
        'SplitIt Alerts',
        channelDescription:
            'Notifications for expenses, payments, groups, and email verification in SplitIt',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        showWhen: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      debugPrint('Device phone notification dispatched: "$title" - "$body"');
    } catch (e) {
      debugPrint('Error showing system notification: $e');
    }
  }

  Future<void> showEmailVerificationNotification({
    required String email,
    required String code,
  }) async {
    await showNotification(
      id: 9991,
      title: 'SplitIt Verification Code: $code',
      body: 'Your 6-digit code for $email is $code. Tap to complete verification.',
      payload: 'verify_email',
    );
  }

  Future<void> showPasswordResetNotification({
    required String email,
    required String code,
  }) async {
    await showNotification(
      id: 9992,
      title: 'SplitIt Password Reset Code: $code',
      body: 'Your 6-digit password reset code for $email is $code. Enter it in the app to reset your password.',
      payload: 'reset_password',
    );
  }
}
