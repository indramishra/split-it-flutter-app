import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide Group;
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/notification_model.dart';
import '../services/debt_simplifier.dart';
import '../services/notification_service.dart';

class SplitwiseProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  // Current Logged In User
  User? _currentUser;
  bool _isAuthLoading = true;

  // Master Lists
  final List<User> _users = [];
  final List<Group> _groups = [];
  final List<Expense> _expenses = [];
  final List<ActivityItem> _activities = [];
  final List<AppNotification> _notifications = [];

  // Currency symbol
  String _currency = '₹';

  // Firestore Subscriptions (User-Scoped)
  StreamSubscription? _currentUserSub;
  StreamSubscription? _groupsSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _activitiesSub;
  StreamSubscription? _notificationsSub;

  SplitwiseProvider() {
    _initAuth();
  }

  // Getters
  bool get isAuthLoading => _isAuthLoading;
  bool get isAuthenticated => _currentUser != null;
  User get currentUser =>
      _currentUser ?? const User(id: '', name: 'Guest', email: '');
  List<User> get users => List.unmodifiable(_users);
  /// Only users explicitly added as friends by the current user.
  List<User> get friends {
    final myId = _currentUser?.id ?? '';
    if (myId.isEmpty) return const [];
    final myFriendIds = _currentUser?.friendIds ?? const [];
    return _users
        .where((u) => u.id != myId && myFriendIds.contains(u.id))
        .toList();
  }
  // Groups the current user is a member of (scoped via Firestore query)
  List<Group> get groups => List.unmodifiable(_groups);

  // Unscoped list of all groups if needed internally
  List<Group> get allGroups => List.unmodifiable(_groups);

  List<Expense> get expenses => List.unmodifiable(_expenses);

  List<ActivityItem> get activities => List.unmodifiable(_activities);

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;
  int get totalUnreadAllMembersCount => unreadNotificationCount;
  String get currency => _currency;

  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    notifyListeners();
  }

  void switchCurrentUser(String userId) {
    final user = _users.where((u) => u.id == userId).firstOrNull;
    if (user != null) {
      _currentUser = user;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('active_user_id', user.id);
      });
      _bindUserStreams();
      notifyListeners();
    }
  }

  User? getUser(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId);
    } catch (_) {
      _fetchSingleUser(userId);
      return null;
    }
  }

  Future<void> _fetchSingleUser(String userId) async {
    if (userId.isEmpty || _users.any((u) => u.id == userId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final u = User.fromJson(doc.data()!);
        if (!_users.any((x) => x.id == u.id)) {
          _users.add(u);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching single user $userId: $e');
    }
  }

  Group? getGroup(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // AUTHENTICATION & SESSION PERSISTENCE
  // ==========================================

  Future<void> _initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('active_user_id');
      if (savedUserId != null && savedUserId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(savedUserId)
            .get();
        if (doc.exists && doc.data() != null) {
          _currentUser = User.fromJson(doc.data()!);
          if (!_users.any((u) => u.id == _currentUser!.id)) {
            _users.add(_currentUser!);
          }
          _bindUserStreams();
        } else {
          await prefs.remove('active_user_id');
          _currentUser = null;
        }
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phoneNumber?.trim();
    if (cleanName.isEmpty) return 'Please enter your full name.';
    
    // Email is optional, but phone must be provided if no email
    if (cleanEmail.isNotEmpty && !cleanEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (cleanEmail.isEmpty && (cleanPhone == null || cleanPhone.isEmpty)) {
      return 'Please enter either an email address or phone number.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Check email uniqueness
      final existing = await firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return 'An account with this email already exists. Please log in.';
      }

      // Check phone uniqueness if provided
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        final phoneExisting = await firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (phoneExisting.docs.isNotEmpty) {
          return 'An account with this phone number already exists.';
        }
      }

      final emailCode = cleanEmail.isNotEmpty ? (100000 + Random().nextInt(900000)).toString() : null;
      final phoneCode = cleanPhone != null && cleanPhone.isNotEmpty
          ? (100000 + Random().nextInt(900000)).toString()
          : null;

      final newUser = User(
        id: _uuid.v4(),
        name: cleanName,
        email: cleanEmail,
        password: password,
        isEmailVerified: cleanEmail.isEmpty, // Skip email verification if no email
        verificationCode: emailCode,
        verificationCodeSentAt: emailCode != null ? DateTime.now() : null,
        createdAt: DateTime.now(),
        phoneNumber: cleanPhone,
        isPhoneVerified: false,
        phoneVerificationCode: phoneCode,
        phoneVerificationCodeSentAt: phoneCode != null ? DateTime.now() : null,
      );

      await firestore
          .collection('users')
          .doc(newUser.id)
          .set(newUser.toJson());

      // Welcome activity
      final welcomeAct = ActivityItem(
        id: _uuid.v4(),
        title: 'Welcome to SplitIt, $cleanName!',
        subtitle: 'Account created. Verification code sent.',
        timestamp: DateTime.now(),
        userId: newUser.id,
      );
      firestore
          .collection('activities')
          .doc(welcomeAct.id)
          .set(welcomeAct.toJson())
          .catchError((_) {});

      _currentUser = newUser;

      // Email verification notification (only if email provided)
      if (emailCode != null) {
        final verifyNotif = AppNotification(
          id: _uuid.v4(),
          recipientUserId: newUser.id,
          recipientName: newUser.name,
          recipientEmail: newUser.email,
          title: 'SplitIt Email Verification Code: $emailCode',
          body: 'Welcome to SplitIt! Your 6-digit email verification code is $emailCode. Enter it in the app to activate your account.',
          timestamp: DateTime.now(),
          type: 'email_verification',
        );
        firestore
            .collection('notifications')
            .doc(verifyNotif.id)
            .set(verifyNotif.toJson())
            .catchError((_) {});
        _notifications.add(verifyNotif);
      }

      // Phone verification notification if phone number provided
      if (phoneCode != null) {
        final phoneNotif = AppNotification(
          id: _uuid.v4(),
          recipientUserId: newUser.id,
          recipientName: newUser.name,
          recipientEmail: newUser.email,
          title: 'SplitIt SMS Code: $phoneCode',
          body: 'Your SplitIt phone verification code is $phoneCode. Enter it to verify your phone number.',
          timestamp: DateTime.now(),
          type: 'phone_verification',
        );
        firestore
            .collection('notifications')
            .doc(phoneNotif.id)
            .set(phoneNotif.toJson())
            .catchError((_) {});
        _notifications.add(phoneNotif);
      }

      // Show notifications via the notification service
      if (emailCode != null) {
        NotificationService().showEmailVerificationNotification(
          email: cleanEmail,
          code: emailCode,
        );
      }
      if (phoneCode != null) {
        NotificationService().showNotification(
          id: 9992,
          title: 'SplitIt SMS Code: $phoneCode',
          body: 'Your SplitIt phone verification code is $phoneCode.',
        );
      }

      _currentUser = newUser;
      if (!_users.any((u) => u.id == newUser.id)) {
        _users.add(newUser);
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_id', newUser.id);
      } catch (prefErr) {
        debugPrint('Failed to save session to SharedPreferences: $prefErr');
      }

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Registration exception: $e');
      return 'Registration failed: $e';
    }
  }

  Future<String?> login({
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    if (email == null || email.isEmpty) {
      if (phoneNumber == null || phoneNumber.isEmpty) {
        return 'Please enter your email or phone number.';
      }
    }
    if (password.isEmpty) {
      return 'Please enter your password.';
    }

    final isEmail = email != null && email.isNotEmpty;
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final cleanPhone = phoneNumber?.trim();
    final isPhone = !isEmail && phoneNumber != null && phoneNumber.isNotEmpty; // ignore: unused_local_variable

    try {
      final firestore = FirebaseFirestore.instance;
      User? user;

      if (isEmail) {
        final snap = await firestore
            .collection('users')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          user = User.fromJson(snap.docs.first.data());
        }
      } else {
        // Query phone number
        final snap = await firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          user = User.fromJson(snap.docs.first.data());
        } else {
          // Try with stripped phone digits
          final snapDigits = await firestore
              .collection('users')
              .where('phoneNumber', isEqualTo: cleanPhone?.replaceAll(RegExp(r'[\s\-().]'), ''))
              .limit(1)
              .get();
          if (snapDigits.docs.isNotEmpty) {
            user = User.fromJson(snapDigits.docs.first.data());
          }
        }
      }

      // Fallback to in-memory search
      user ??= _users.where((u) {
        if (isEmail) {
          return u.email.toLowerCase() == cleanEmail;
        } else {
          final uPhone = u.phoneNumber?.replaceAll(RegExp(r'[\s\-().]'), '') ?? '';
          return u.phoneNumber == cleanPhone || (uPhone.isNotEmpty && uPhone == cleanPhone?.replaceAll(RegExp(r'[\s\-().]'), ''));
        }
      }).firstOrNull;

      if (user == null) {
        return isEmail
            ? 'No account found with this email. Please register.'
            : 'No account found with this phone number. Please register.';
      }

      if (user.password != null && user.password != password) {
        return 'Incorrect password. Please try again.';
      }

      _currentUser = user;

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_id', _currentUser!.id);
      } catch (prefErr) {
        debugPrint('Failed to save session to SharedPreferences: $prefErr');
      }

      // Check if email or phone verification is needed
      if (!_currentUser!.isEmailVerified) {
        if (_currentUser!.verificationCode == null) {
          sendEmailVerificationCode();
        } else {
          NotificationService().showEmailVerificationNotification(
            email: _currentUser!.email,
            code: _currentUser!.verificationCode!,
          );
        }
      }

      if (_currentUser!.phoneNumber != null &&
          _currentUser!.phoneNumber!.isNotEmpty &&
          !_currentUser!.isPhoneVerified) {
        if (_currentUser!.phoneVerificationCode == null) {
          sendPhoneVerificationCode();
        } else {
          NotificationService().showNotification(
            id: 9991,
            title: 'SplitIt SMS Code: ${_currentUser!.phoneVerificationCode}',
            body: 'Your SplitIt phone verification code is ${_currentUser!.phoneVerificationCode}.',
          );
        }
      }

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Login exception: $e');
      return 'Login failed: $e';
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_user_id');
    } catch (prefErr) {
      debugPrint('Failed to clear session in SharedPreferences: $prefErr');
    }
    notifyListeners();
  }

  // ==========================================
  // NOTIFICATION PERMISSIONS & EMAIL VERIFICATION
  // ==========================================

  Future<bool> requestNotificationPermission() async {
    return await NotificationService().requestPermissions();
  }

  Future<String?> sendEmailVerificationCode() async {
    if (_currentUser == null) return 'No user is currently signed in.';
    final code = (100000 + Random().nextInt(900000)).toString();
    final updatedUser = _currentUser!.copyWith(
      verificationCode: code,
      verificationCodeSentAt: DateTime.now(),
    );
    _currentUser = updatedUser;

    final notif = AppNotification(
      id: _uuid.v4(),
      recipientUserId: updatedUser.id,
      recipientName: updatedUser.name,
      recipientEmail: updatedUser.email,
      title: 'SplitIt Verification Code: $code',
      body: 'Your 6-digit verification code is $code. Enter it in the app to activate your account.',
      timestamp: DateTime.now(),
      type: 'email_verification',
    );
    _notifications.add(notif);

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'verificationCode': code,
        'verificationCodeSentAt': DateTime.now().toIso8601String(),
      });
      batch.set(firestore.collection('notifications').doc(notif.id), notif.toJson());
      await batch.commit();

      await NotificationService().showEmailVerificationNotification(
        email: updatedUser.email,
        code: code,
      );
      return null;
    } catch (e) {
      debugPrint('Error sending verification code: $e');
      return 'Failed to send verification code: $e';
    }
  }

  Future<String?> verifyEmail(String code) async {
    if (_currentUser == null) return 'No user is currently signed in.';
    final cleanCode = code.trim();
    final userCode = _currentUser!.verificationCode?.trim();

    if (userCode != null && userCode.isNotEmpty && userCode != cleanCode) {
      return 'Invalid verification code. Please check your notification or enter the 6 digits sent to you.';
    }

    final updatedUser = _currentUser!.copyWith(
      isEmailVerified: true,
      clearVerificationCode: true,
    );
    _currentUser = updatedUser;

    final verifyAct = ActivityItem(
      id: _uuid.v4(),
      title: 'Email verified',
      subtitle: '${updatedUser.email} was confirmed',
      timestamp: DateTime.now(),
      userId: updatedUser.id,
    );
    _activities.add(verifyAct);

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'isEmailVerified': true,
        'verificationCode': FieldValue.delete(),
      });
      batch.set(firestore.collection('activities').doc(verifyAct.id), verifyAct.toJson());
      await batch.commit();

      await NotificationService().showNotification(
        id: 9992,
        title: 'Email Verified',
        body: 'Your email (${updatedUser.email}) is successfully verified. Welcome to SplitIt!',
      );
      return null;
    } catch (e) {
      debugPrint('Error verifying email: $e');
      return 'Failed to update verification status: $e';
    }
  }

  // ==========================================
  // PHONE VERIFICATION
  // ==========================================

  Future<String?> sendPhoneVerificationCode() async {
    if (_currentUser == null) return 'No user is currently signed in.';
    if (_currentUser!.phoneNumber == null || _currentUser!.phoneNumber!.isEmpty) {
      return 'No phone number linked to this account.';
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    final updatedUser = _currentUser!.copyWith(
      phoneVerificationCode: code,
      phoneVerificationCodeSentAt: DateTime.now(),
    );
    _currentUser = updatedUser;

    final notif = AppNotification(
      id: _uuid.v4(),
      recipientUserId: updatedUser.id,
      recipientName: updatedUser.name,
      recipientEmail: updatedUser.email,
      title: 'SplitIt SMS Code: $code',
      body: 'Your SplitIt phone verification code is $code.',
      timestamp: DateTime.now(),
      type: 'phone_verification',
    );
    _notifications.add(notif);
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'phoneVerificationCode': code,
        'phoneVerificationCodeSentAt': DateTime.now().toIso8601String(),
      });
      batch.set(
          firestore.collection('notifications').doc(notif.id), notif.toJson());
      await batch.commit();
      await NotificationService().showNotification(
        id: 9994,
        title: 'SplitIt SMS: $code',
        body:
            'Your phone verification code is $code. Enter it in the app.',
      );
      return null;
    } catch (e) {
      debugPrint('Error sending phone verification code: $e');
      return 'Failed to send phone verification code: $e';
    }
  }

  Future<String?> verifyPhone(String code) async {
    if (_currentUser == null) return 'No user is currently signed in.';
    final cleanCode = code.trim();
    final userCode = _currentUser!.phoneVerificationCode?.trim();

    if (userCode == null || userCode.isEmpty) {
      return 'No pending phone verification code. Please request a new one.';
    }
    if (userCode != cleanCode) {
      return 'Invalid phone verification code. Please check your notifications.';
    }

    // Check expiry (15 minutes)
    if (_currentUser!.phoneVerificationCodeSentAt != null) {
      final age = DateTime.now()
          .difference(_currentUser!.phoneVerificationCodeSentAt!);
      if (age.inMinutes > 15) {
        return 'Phone verification code has expired. Please request a new one.';
      }
    }

    final updatedUser = _currentUser!.copyWith(
      isPhoneVerified: true,
      clearPhoneVerificationCode: true,
    );
    _currentUser = updatedUser;

    final verifyAct = ActivityItem(
      id: _uuid.v4(),
      title: 'Phone verified',
      subtitle: '${updatedUser.phoneNumber} was confirmed',
      timestamp: DateTime.now(),
      userId: updatedUser.id,
    );
    _activities.add(verifyAct);
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'isPhoneVerified': true,
        'phoneVerificationCode': FieldValue.delete(),
      });
      batch.set(
          firestore.collection('activities').doc(verifyAct.id),
          verifyAct.toJson());
      await batch.commit();
      await NotificationService().showNotification(
        id: 9995,
        title: 'Phone Verified',
        body: 'Your phone number is now verified on SplitIt!',
      );
      return null;
    } catch (e) {
      debugPrint('Error verifying phone: $e');
      return 'Failed to update phone verification status: $e';
    }
  }

  // ==========================================
  // CONTACT LIST FRIEND SEARCH
  // ==========================================

  /// Requests contact permission and returns a list of [User]s from Firestore
  /// whose phone or email matches any contact on the device.
  Future<ContactFriendResult> searchContactFriends() async {
    // Request contacts permission
    final status = await Permission.contacts.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      return ContactFriendResult(
        permissionDenied: true,
        friends: [],
        contactsCount: 0,
      );
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      final phones = <String>{};
      final emails = <String>{};
      for (final c in contacts) {
        for (final p in c.phones) {
          final normalized = p.number.replaceAll(RegExp(r'[\s\-().+]'), '');
          if (normalized.isNotEmpty) phones.add(normalized);
        }
        for (final e in c.emails) {
          final addr = e.address.trim().toLowerCase();
          if (addr.isNotEmpty) emails.add(addr);
        }
      }

      final myId = _currentUser?.id ?? '';
      final matchedFriends = <User>{};

      final firestore = FirebaseFirestore.instance;

      // Batch query Firestore for contacts matching email (max 30 per whereIn)
      final emailList = emails.toList();
      for (var i = 0; i < emailList.length; i += 30) {
        final chunk = emailList.sublist(i, min(i + 30, emailList.length));
        final snap = await firestore
            .collection('users')
            .where('email', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final u = User.fromJson(doc.data());
          if (u.id != myId) matchedFriends.add(u);
        }
      }

      // Batch query Firestore for contacts matching phone (max 30 per whereIn)
      final phoneList = phones.toList();
      for (var i = 0; i < phoneList.length; i += 30) {
        final chunk = phoneList.sublist(i, min(i + 30, phoneList.length));
        final snap = await firestore
            .collection('users')
            .where('phoneNumber', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final u = User.fromJson(doc.data());
          if (u.id != myId) matchedFriends.add(u);
        }
      }

      // Cache matched users locally
      for (final u in matchedFriends) {
        if (!_users.any((x) => x.id == u.id)) {
          _users.add(u);
        }
      }

      return ContactFriendResult(
        permissionDenied: false,
        friends: matchedFriends.toList(),
        contactsCount: contacts.length,
      );
    } catch (e) {
      debugPrint('Contact search error: $e');
      return ContactFriendResult(
        permissionDenied: false,
        friends: [],
        contactsCount: 0,
        error: e.toString(),
      );
    }
  }

  // ==========================================
  // FORGOT & RESET PASSWORD
  // ==========================================

  Future<String?> sendPasswordResetCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snap = await firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      User? targetUser;
      if (snap.docs.isNotEmpty) {
        targetUser = User.fromJson(snap.docs.first.data());
      } else {
        targetUser = _users
            .where((u) => u.email.toLowerCase() == cleanEmail)
            .firstOrNull;
      }

      if (targetUser == null) {
        return 'No account found with this email. Please check the spelling or sign up.';
      }

      final code = (100000 + Random().nextInt(900000)).toString();
      final updatedUser = targetUser.copyWith(
        resetPasswordCode: code,
        resetPasswordCodeSentAt: DateTime.now(),
      );

      final index = _users.indexWhere((u) => u.id == targetUser!.id);
      if (index != -1) {
        _users[index] = updatedUser;
      } else {
        _users.add(updatedUser);
      }

      final notif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: updatedUser.id,
        recipientName: updatedUser.name,
        recipientEmail: updatedUser.email,
        title: 'SplitIt Password Reset Code: $code',
        body: 'Your 6-digit password reset code is $code. Enter it in the app to reset your password.',
        timestamp: DateTime.now(),
        type: 'password_reset',
      );
      _notifications.add(notif);
      notifyListeners();

      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'resetPasswordCode': code,
        'resetPasswordCodeSentAt': DateTime.now().toIso8601String(),
      });
      batch.set(firestore.collection('notifications').doc(notif.id), notif.toJson());
      await batch.commit();

      await NotificationService().showPasswordResetNotification(
        email: updatedUser.email,
        code: code,
      );

      return null;
    } catch (e) {
      debugPrint('Error sending password reset code: $e');
      return 'Failed to send reset code: $e';
    }
  }

  Future<String?> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (cleanCode.length != 6) {
      return 'Please enter the 6-digit reset code.';
    }
    if (newPassword.length < 6) {
      return 'Password must be at least 6 characters long.';
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snap = await firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      User? targetUser;
      if (snap.docs.isNotEmpty) {
        targetUser = User.fromJson(snap.docs.first.data());
      } else {
        targetUser = _users
            .where((u) => u.email.toLowerCase() == cleanEmail)
            .firstOrNull;
      }

      if (targetUser == null) {
        return 'No account found with this email.';
      }

      final expectedCode = targetUser.resetPasswordCode?.trim();
      if (expectedCode == null || expectedCode != cleanCode) {
        return 'Invalid reset code. Please check your notification or request a new code.';
      }

      if (targetUser.resetPasswordCodeSentAt != null) {
        final age = DateTime.now().difference(targetUser.resetPasswordCodeSentAt!);
        if (age.inMinutes > 15) {
          return 'Reset code has expired. Please request a new one.';
        }
      }

      final updatedUser = targetUser.copyWith(
        password: newPassword,
        clearResetPasswordCode: true,
      );

      final index = _users.indexWhere((u) => u.id == targetUser!.id);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      if (_currentUser?.id == targetUser.id) {
        _currentUser = updatedUser;
      }

      final resetAct = ActivityItem(
        id: _uuid.v4(),
        title: 'Password reset',
        subtitle: 'Password updated successfully.',
        timestamp: DateTime.now(),
        userId: updatedUser.id,
      );

      final resetNotif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: updatedUser.id,
        recipientName: updatedUser.name,
        recipientEmail: updatedUser.email,
        title: 'SplitIt Password Updated',
        body: 'Your SplitIt password was changed successfully.',
        timestamp: DateTime.now(),
        type: 'password_reset_success',
      );
      _notifications.add(resetNotif);
      notifyListeners();

      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'password': newPassword,
        'resetPasswordCode': FieldValue.delete(),
        'resetPasswordCodeSentAt': FieldValue.delete(),
      });
      batch.set(firestore.collection('activities').doc(resetAct.id), resetAct.toJson());
      batch.set(firestore.collection('notifications').doc(resetNotif.id), resetNotif.toJson());
      await batch.commit();

      await NotificationService().showNotification(
        id: 9993,
        title: 'Password Reset Successful',
        body: 'Your SplitIt password has been updated. You can now log in with your new password.',
      );

      return null;
    } catch (e) {
      debugPrint('Error resetting password: $e');
      return 'Failed to reset password: $e';
    }
  }


  // ==========================================
  // PURGE ALL DATA
  // ==========================================

  Future<void> purgeLegacyTestData() async {
    await purgeAllData();
  }

  Future<void> purgeAllData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final uSnap = await firestore.collection('users').get();
      final gSnap = await firestore.collection('groups').get();
      final eSnap = await firestore.collection('expenses').get();
      final aSnap = await firestore.collection('activities').get();
      final nSnap = await firestore.collection('notifications').get();

      final batch = firestore.batch();
      for (final doc in uSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in gSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in eSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in aSnap.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in nSnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _cancelUserStreams();
      _users.clear();
      _groups.clear();
      _expenses.clear();
      _activities.clear();
      _notifications.clear();
      _currentUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_user_id');

      notifyListeners();
      debugPrint('All Firestore data and local state successfully purged.');
    } catch (e) {
      debugPrint('Error purging data: $e');
    }
  }

  // ==========================================
  // FIRESTORE SCOPED USER SYNC & STREAMS
  // ==========================================

  void _bindUserStreams() {
    _cancelUserStreams();
    final myId = _currentUser?.id ?? '';
    if (myId.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // 1. Current user doc stream
      _currentUserSub = firestore.collection('users').doc(myId).snapshots().listen((snap) {
        if (snap.exists && snap.data() != null) {
          final updated = User.fromJson(snap.data()!);
          _currentUser = updated;
          final idx = _users.indexWhere((u) => u.id == myId);
          if (idx != -1) {
            _users[idx] = updated;
          } else {
            _users.add(updated);
          }
          _syncRelatedUsers();
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Current user stream error: $e'));

      // 2. Groups stream: Scoped to groups where memberIds contains myId
      _groupsSub = firestore
          .collection('groups')
          .where('memberIds', arrayContains: myId)
          .snapshots()
          .listen((snap) {
        _groups.clear();
        for (final doc in snap.docs) {
          _groups.add(Group.fromJson(doc.data()));
        }
        _syncRelatedUsers();
        notifyListeners();
      }, onError: (e) => debugPrint('Groups stream error: $e'));

      // 3. Expenses stream: Scoped to expenses where participantIds contains myId
      _expensesSub = firestore
          .collection('expenses')
          .where('participantIds', arrayContains: myId)
          .snapshots()
          .listen((snap) {
        _expenses.clear();
        for (final doc in snap.docs) {
          _expenses.add(Expense.fromJson(doc.data()));
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Expenses stream error: $e'));

      // 4. Activities stream: Scoped to activities where audienceUserIds contains myId
      _activitiesSub = firestore
          .collection('activities')
          .where('audienceUserIds', arrayContains: myId)
          .snapshots()
          .listen((snap) {
        _activities.clear();
        for (final doc in snap.docs) {
          _activities.add(ActivityItem.fromJson(doc.data()));
        }
        _activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }, onError: (e) => debugPrint('Activities stream error: $e'));

      // 5. Notifications stream: Scoped to notifications where recipientUserId == myId
      bool isInitialNotifsLoad = true;
      _notificationsSub = firestore
          .collection('notifications')
          .where('recipientUserId', isEqualTo: myId)
          .snapshots()
          .listen((snap) {
        final newNotifs = snap.docs.map((d) => AppNotification.fromJson(d.data())).toList();

        if (!isInitialNotifsLoad) {
          for (final change in snap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                final notif = AppNotification.fromJson(data);
                if (notif.recipientUserId == myId &&
                    notif.type != 'email_verification') {
                  NotificationService().showNotification(
                    title: notif.title,
                    body: notif.body,
                    payload: notif.id,
                  );
                }
              }
            }
          }
        }
        isInitialNotifsLoad = false;

        _notifications.clear();
        _notifications.addAll(newNotifs);
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }, onError: (e) => debugPrint('Notifications stream error: $e'));
    } catch (e) {
      debugPrint('Error binding user streams: $e');
    }
  }

  void _cancelUserStreams() {
    _currentUserSub?.cancel();
    _currentUserSub = null;
    _groupsSub?.cancel();
    _groupsSub = null;
    _expensesSub?.cancel();
    _expensesSub = null;
    _activitiesSub?.cancel();
    _activitiesSub = null;
    _notificationsSub?.cancel();
    _notificationsSub = null;
  }

  Future<void> _syncRelatedUsers() async {
    final myId = _currentUser?.id ?? '';
    if (myId.isEmpty) return;

    final neededUserIds = <String>{};
    neededUserIds.addAll(_currentUser?.friendIds ?? []);
    for (final g in _groups) {
      neededUserIds.addAll(g.memberIds);
    }
    neededUserIds.remove(myId);

    final missingIds = neededUserIds.where((id) => !_users.any((u) => u.id == id)).toList();
    if (missingIds.isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;
      for (var i = 0; i < missingIds.length; i += 30) {
        final chunk = missingIds.sublist(i, min(i + 30, missingIds.length));
        final snap = await firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final u = User.fromJson(doc.data());
          final existingIdx = _users.indexWhere((x) => x.id == u.id);
          if (existingIdx != -1) {
            _users[existingIdx] = u;
          } else {
            _users.add(u);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing related users: $e');
    }
  }

  // ==========================================
  // EXPENSES & BALANCES
  // ==========================================

  List<Expense> getExpensesForGroup(String groupId) {
    final list = _expenses.where((e) => e.groupId == groupId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<Expense> getExpensesWithFriend(String friendId) {
    final myId = _currentUser?.id ?? '';
    final list = _expenses.where((e) {
      final isDirectParticipant =
          e.participantIds.contains(friendId) && e.participantIds.contains(myId);
      final isPayer = e.paidByUserId == friendId || e.paidByUserId == myId;
      return isDirectParticipant || (isPayer && e.splitShares.containsKey(friendId));
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Map<String, double> getUserOverallBalance(String userId) {
    final net = DebtSimplifier.computeNetBalances(expenses: _expenses);
    final userNet = net[userId] ?? 0.0;

    final debts = DebtSimplifier.computePairwiseDebts(_expenses);
    double totalYouAreOwed = 0.0;
    double totalYouOwe = 0.0;

    for (final d in debts) {
      if (d.toUserId == userId) {
        totalYouAreOwed += d.amount;
      } else if (d.fromUserId == userId) {
        totalYouOwe += d.amount;
      }
    }

    return {
      'net': double.parse(userNet.toStringAsFixed(2)),
      'totalYouAreOwed': double.parse(totalYouAreOwed.toStringAsFixed(2)),
      'totalYouOwe': double.parse(totalYouOwe.toStringAsFixed(2)),
    };
  }

  double getBalanceWithFriend(String friendId) {
    final myId = _currentUser?.id ?? '';
    final debts = DebtSimplifier.computePairwiseDebts(_expenses);
    double balance = 0.0;
    for (final d in debts) {
      if (d.toUserId == myId && d.fromUserId == friendId) {
        balance += d.amount;
      } else if (d.fromUserId == myId && d.toUserId == friendId) {
        balance -= d.amount;
      }
    }
    return double.parse(balance.toStringAsFixed(2));
  }

  List<Debt> getGroupDebts(String groupId, {bool? forceSimplify}) {
    final group = getGroup(groupId);
    if (group == null) return [];

    final groupExpenses = _expenses.where((e) => e.groupId == groupId).toList();
    final shouldSimplify = forceSimplify ?? group.simplifyByDefault;

    if (shouldSimplify) {
      final net = DebtSimplifier.computeNetBalances(
        expenses: groupExpenses,
        memberIds: group.memberIds,
      );
      return DebtSimplifier.simplifyDebts(net);
    } else {
      return DebtSimplifier.computePairwiseDebts(groupExpenses);
    }
  }

  void addExpense({
    String? groupId,
    required String description,
    required double cost,
    required String paidByUserId,
    required Map<String, double> splitShares,
    String category = 'General',
    String? notes,
    DateTime? date,
  }) {
    final participants = <String>{paidByUserId, ...splitShares.keys}.toList();
    final newExpense = Expense(
      id: _uuid.v4(),
      groupId: groupId,
      description: description,
      cost: cost,
      date: date ?? DateTime.now(),
      paidByUserId: paidByUserId,
      category: category,
      splitShares: splitShares,
      participantIds: participants,
      notes: notes,
    );

    _expenses.insert(0, newExpense);

    final payer = getUser(paidByUserId)?.name ?? 'Someone';
    final group = groupId != null ? getGroup(groupId) : null;
    final context = group != null ? 'in "${group.name}"' : '';

    final audienceIds = group != null
        ? List<String>.from(group.memberIds)
        : List<String>.from(participants);

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      type: 'expense_added',
      title: '$payer added "$description"',
      subtitle: '$context • $_currency${cost.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      actorId: paidByUserId,
      actorName: payer,
      expenseId: newExpense.id,
      groupId: groupId,
      groupName: group?.name,
      amount: cost,
      audienceUserIds: audienceIds,
    );
    _activities.insert(0, activityItem);

    final newNotifs = <AppNotification>[];
    for (final recipientId in audienceIds) {
      final recipient = getUser(recipientId);
      if (recipient == null) continue;
      final isActor = recipientId == paidByUserId;
      final share = splitShares[recipientId] ?? 0.0;

      final title = isActor
          ? 'You added an expense in ${group?.name ?? "expenses"}'
          : '$payer added an expense in ${group?.name ?? "expenses"}';

      final body = isActor
          ? 'You added "$description" for $_currency${cost.toStringAsFixed(2)}.'
          : '$payer added "$description" ($_currency${cost.toStringAsFixed(2)}). Your share is $_currency${share.toStringAsFixed(2)}.';

      final notif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: recipient.id,
        recipientName: recipient.name,
        recipientEmail: recipient.email,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        groupId: groupId,
        groupName: group?.name,
        type: 'expense_added',
      );
      if (isActor) {
        _notifications.insert(0, notif);
      }
      newNotifs.add(notif);
    }

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(firestore.collection('expenses').doc(newExpense.id), newExpense.toJson());
      batch.set(firestore.collection('activities').doc(activityItem.id), activityItem.toJson());
      for (final n in newNotifs) {
        batch.set(firestore.collection('notifications').doc(n.id), n.toJson());
      }
      batch.commit().catchError((e) => debugPrint('Firestore addExpense error: $e'));
    } catch (e) {
      debugPrint('Firestore addExpense exception: $e');
    }
  }

  void settleUp({
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? groupId,
  }) {
    final fromUser = getUser(fromUserId)?.name ?? 'User';
    final toUser = getUser(toUserId)?.name ?? 'User';

    final paymentExpense = Expense(
      id: _uuid.v4(),
      groupId: groupId,
      description: '$fromUser paid $toUser',
      cost: amount,
      date: DateTime.now(),
      paidByUserId: fromUserId,
      category: 'Payment',
      splitShares: {
        toUserId: amount,
      },
      participantIds: [fromUserId, toUserId],
      isPayment: true,
      notes: 'Settled payment',
    );

    _expenses.insert(0, paymentExpense);

    final group = groupId != null ? getGroup(groupId) : null;
    final audienceIds = group != null
        ? List<String>.from(group.memberIds)
        : [fromUserId, toUserId];

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      type: 'payment_settled',
      title: '$fromUser settled with $toUser',
      subtitle: 'Payment of $_currency${amount.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      actorId: fromUserId,
      actorName: fromUser,
      expenseId: paymentExpense.id,
      groupId: groupId,
      groupName: group?.name,
      amount: amount,
      audienceUserIds: audienceIds,
    );
    _activities.insert(0, activityItem);

    final newNotifs = <AppNotification>[];
    for (final recipientId in audienceIds) {
      final recipient = getUser(recipientId);
      if (recipient == null) continue;
      final isPayer = recipientId == fromUserId;
      final isReceiver = recipientId == toUserId;

      final title = isPayer
          ? 'Payment sent to $toUser'
          : (isReceiver
              ? 'Payment received from $fromUser'
              : 'Payment recorded in ${group?.name ?? "expenses"}');

      final body =
          '$fromUser paid $toUser $_currency${amount.toStringAsFixed(2)} to settle up.';

      final notif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: recipient.id,
        recipientName: recipient.name,
        recipientEmail: recipient.email,
        title: title,
        body: body,
        timestamp: DateTime.now(),
        groupId: groupId,
        groupName: group?.name,
        type: 'payment_settled',
      );
      if (recipientId == _currentUser?.id) {
        _notifications.insert(0, notif);
      }
      newNotifs.add(notif);
    }

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(firestore.collection('expenses').doc(paymentExpense.id), paymentExpense.toJson());
      batch.set(firestore.collection('activities').doc(activityItem.id), activityItem.toJson());
      for (final n in newNotifs) {
        batch.set(firestore.collection('notifications').doc(n.id), n.toJson());
      }
      batch.commit().catchError((e) => debugPrint('Firestore settleUp error: $e'));
    } catch (e) {
      debugPrint('Firestore settleUp exception: $e');
    }
  }

  void deleteExpense(String expenseId) {
    final exp = _expenses.firstWhere((e) => e.id == expenseId, orElse: () => _expenses.first);
    _expenses.removeWhere((e) => e.id == expenseId);

    final deleteActivity = ActivityItem(
      id: _uuid.v4(),
      type: 'expense_deleted',
      title: 'Deleted expense "${exp.description}"',
      subtitle: 'Amount: $_currency${exp.cost.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      actorId: _currentUser?.id,
      actorName: _currentUser?.name,
      groupId: exp.groupId,
      audienceUserIds: exp.participantIds,
    );
    _activities.insert(0, deleteActivity);

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      firestore.collection('expenses').doc(expenseId).delete().catchError((e) => debugPrint('Firestore delete error: $e'));
      firestore.collection('activities').doc(deleteActivity.id).set(deleteActivity.toJson()).catchError((e) => debugPrint('Firestore deleteActivity error: $e'));
    } catch (e) {
      debugPrint('Firestore delete exception: $e');
    }
  }

  void toggleGroupSimplifyDebts(String groupId) {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      final g = _groups[index];
      final newSimplified = !g.simplifyByDefault;
      _groups[index] = g.copyWith(simplifyByDefault: newSimplified);
      notifyListeners();

      try {
        FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({'simplifyByDefault': newSimplified})
            .catchError((e) => debugPrint('Firestore toggleSimplifyDebts error: $e'));
      } catch (e) {
        debugPrint('Firestore toggleSimplifyDebts exception: $e');
      }
    }
  }

  void createGroup({
    required String name,
    required String groupType,
    required List<String> memberIds,
    bool simplifyByDefault = true,
  }) {
    final myId = _currentUser?.id ?? '';
    final allMembers = {...memberIds, if (myId.isNotEmpty) myId}.toList();
    final newGroup = Group(
      id: _uuid.v4(),
      name: name,
      groupType: groupType,
      memberIds: allMembers,
      createdByUserId: myId,
      simplifyByDefault: simplifyByDefault,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _groups.add(newGroup);

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      type: 'group_created',
      title: 'Created group "${newGroup.name}"',
      subtitle: '${allMembers.length} members',
      timestamp: DateTime.now(),
      actorId: myId,
      actorName: _currentUser?.name ?? 'You',
      groupId: newGroup.id,
      groupName: newGroup.name,
      audienceUserIds: allMembers,
    );
    _activities.insert(0, activityItem);

    final newNotifs = <AppNotification>[];
    for (final memberId in allMembers) {
      final member = getUser(memberId);
      if (member == null) continue;
      final isCreator = memberId == myId;

      final notif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: member.id,
        recipientName: member.name,
        recipientEmail: member.email,
        title: isCreator
            ? 'You created group "$name"'
            : 'You were added to group "$name"',
        body: '${allMembers.length} members in $name ($groupType).',
        timestamp: DateTime.now(),
        groupId: newGroup.id,
        groupName: newGroup.name,
        type: 'group_created',
      );
      if (isCreator) {
        _notifications.insert(0, notif);
      }
      newNotifs.add(notif);
    }

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(firestore.collection('groups').doc(newGroup.id), newGroup.toJson());
      batch.set(firestore.collection('activities').doc(activityItem.id), activityItem.toJson());
      for (final n in newNotifs) {
        batch.set(firestore.collection('notifications').doc(n.id), n.toJson());
      }
      batch.commit().catchError((e) => debugPrint('Firestore createGroup error: $e'));
    } catch (e) {
      debugPrint('Firestore createGroup exception: $e');
    }
  }

  // EXIT GROUP / LEAVE GROUP (e.g. Added Unintentionally)
  Future<String?> exitGroup({
    required String groupId,
    required String userId,
  }) async {
    final group = getGroup(groupId);
    if (group == null) return 'Group not found';

    final user = getUser(userId) ?? _currentUser;
    final userName = user?.name ?? 'Member';

    try {
      final firestore = FirebaseFirestore.instance;
      final updatedMembers = List<String>.from(group.memberIds)..remove(userId);

      final batch = firestore.batch();

      if (updatedMembers.isEmpty) {
        batch.delete(firestore.collection('groups').doc(groupId));
        _groups.removeWhere((g) => g.id == groupId);
      } else {
        batch.update(firestore.collection('groups').doc(groupId), {
          'memberIds': updatedMembers,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        final idx = _groups.indexWhere((g) => g.id == groupId);
        if (idx != -1) {
          _groups[idx] = group.copyWith(memberIds: updatedMembers);
        }
      }

      final act = ActivityItem(
        id: _uuid.v4(),
        type: 'member_left',
        title: '$userName left group "${group.name}"',
        subtitle: '${updatedMembers.length} members remaining',
        timestamp: DateTime.now(),
        actorId: userId,
        actorName: userName,
        groupId: group.id,
        groupName: group.name,
        audienceUserIds: group.memberIds,
      );
      batch.set(firestore.collection('activities').doc(act.id), act.toJson());
      _activities.insert(0, act);

      for (final remId in updatedMembers) {
        final remUser = getUser(remId);
        if (remUser == null) continue;
        final notif = AppNotification(
          id: _uuid.v4(),
          recipientUserId: remId,
          recipientName: remUser.name,
          recipientEmail: remUser.email,
          title: '$userName left "${group.name}"',
          body: '$userName has exited the group.',
          timestamp: DateTime.now(),
          groupId: groupId,
          groupName: group.name,
          type: 'member_left',
        );
        batch.set(firestore.collection('notifications').doc(notif.id), notif.toJson());
        if (remId == _currentUser?.id) {
          _notifications.insert(0, notif);
        }
      }

      await batch.commit();
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('exitGroup error: $e');
      return 'Failed to exit group: $e';
    }
  }

  // Remove a member (e.g. creator removing unintentional member)
  Future<String?> removeMemberFromGroup({
    required String groupId,
    required String memberId,
  }) async {
    return exitGroup(groupId: groupId, userId: memberId);
  }

  // ==========================================
  // SEARCH FUNCTIONALITY (SPLITWISE OMNI-SEARCH)
  // ==========================================

  List<Group> searchGroups(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return groups.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.groupType.toLowerCase().contains(q);
    }).toList();
  }

  List<User> searchUsers(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final myId = _currentUser?.id ?? '';
    return _users.where((u) {
      return u.id != myId &&
          (u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q));
    }).toList();
  }

  List<Expense> searchExpenses(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return _expenses.where((e) {
      final payer = getUser(e.paidByUserId)?.name ?? '';
      return e.description.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          (e.notes?.toLowerCase().contains(q) ?? false) ||
          payer.toLowerCase().contains(q) ||
          e.cost.toString().contains(q);
    }).toList();
  }

  // ==========================================
  // NOTIFICATIONS & FRIENDS
  // ==========================================

  void markAllNotificationsAsRead() {
    final myId = _currentUser?.id ?? '';
    final myNotifs = _notifications
        .where((n) => myId.isEmpty || n.recipientUserId == myId)
        .toList();
    for (final n in myNotifs) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      for (final n in myNotifs) {
        batch.update(firestore.collection('notifications').doc(n.id), {'isRead': true});
      }
      batch.commit().catchError((e) => debugPrint('Firestore markAllNotificationsAsRead error: $e'));
    } catch (e) {
      debugPrint('Firestore markAllNotificationsAsRead exception: $e');
    }
  }

  void markNotificationAsRead(String notificationId) {
    final n = _notifications.where((item) => item.id == notificationId).firstOrNull;
    if (n != null) {
      n.isRead = true;
      notifyListeners();
    }

    try {
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true})
          .catchError((e) => debugPrint('Firestore markNotificationAsRead error: $e'));
    } catch (e) {
      debugPrint('Firestore markNotificationAsRead exception: $e');
    }
  }

  void clearNotifications() {
    final myId = _currentUser?.id ?? '';
    final toDelete = _notifications
        .where((n) => myId.isEmpty || n.recipientUserId == myId)
        .toList();
    _notifications
        .removeWhere((n) => myId.isEmpty || n.recipientUserId == myId);
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      for (final n in toDelete) {
        batch.delete(firestore.collection('notifications').doc(n.id));
      }
      batch.commit().catchError((e) => debugPrint('Firestore clearNotifications error: $e'));
    } catch (e) {
      debugPrint('Firestore clearNotifications exception: $e');
    }
  }

  /// Search all registered users (excluding self and already-friends) by name/email.
  List<User> searchRegisteredUsers(String query) {
    final myId = _currentUser?.id ?? '';
    final myFriendIds = _currentUser?.friendIds ?? const [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _users.where((u) {
      return u.id != myId &&
          !myFriendIds.contains(u.id) &&
          (u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q));
    }).toList();
  }

  /// Add a friend by email or phone — links to an existing registered user if found,
  /// otherwise creates an invite placeholder. Never auto-creates ghost duplicates.
  Future<String?> addFriend({
    required String name,
    required String email,
    String? phoneNumber,
  }) async {
    if (_currentUser == null) return 'Not logged in.';
    final cleanInput = email.trim();
    final isEmail = cleanInput.contains('@');
    final cleanEmail = isEmail ? cleanInput.toLowerCase() : '';
    final cleanPhone = phoneNumber?.trim() ??
        (!isEmail ? cleanInput.replaceAll(RegExp(r'[\s\-().]'), '') : '');
    final myId = _currentUser!.id;
    final myFriendIds = List<String>.from(_currentUser!.friendIds);

    // Prevent adding yourself
    if (cleanEmail.isNotEmpty && cleanEmail == _currentUser!.email.toLowerCase()) {
      return 'You cannot add yourself as a friend.';
    }
    final myPhoneClean = _currentUser!.phoneNumber?.replaceAll(RegExp(r'[\s\-().]'), '') ?? '';
    if (cleanPhone.isNotEmpty && cleanPhone == myPhoneClean) {
      return 'You cannot add yourself as a friend.';
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Check if this email or phone belongs to a registered user
      User? targetUser = _users.where((u) {
        if (cleanEmail.isNotEmpty && u.email.toLowerCase() == cleanEmail) {
          return true;
        }
        if (cleanPhone.isNotEmpty) {
          final uPhone = u.phoneNumber?.replaceAll(RegExp(r'[\s\-().]'), '') ?? '';
          if (uPhone.isNotEmpty && uPhone == cleanPhone) return true;
        }
        return false;
      }).firstOrNull;

      if (targetUser == null) {
        // Try Firestore lookup by email
        if (cleanEmail.isNotEmpty) {
          final snap = await firestore
              .collection('users')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            targetUser = User.fromJson(snap.docs.first.data());
          }
        }
        // Try Firestore lookup by phone
        if (targetUser == null && cleanPhone.isNotEmpty) {
          final phoneSnap = await firestore
              .collection('users')
              .where('phoneNumber', isEqualTo: cleanPhone)
              .limit(1)
              .get();
          if (phoneSnap.docs.isNotEmpty) {
            targetUser = User.fromJson(phoneSnap.docs.first.data());
          }
        }
        if (targetUser != null && !_users.any((u) => u.id == targetUser!.id)) {
          _users.add(targetUser);
        }
      }

      if (targetUser == null) {
        // User not registered: create an invite placeholder
        final placeholder = User(
          id: _uuid.v4(),
          name: name.trim().isNotEmpty
              ? name.trim()
              : (cleanEmail.isNotEmpty
                  ? cleanEmail.split('@').first
                  : (cleanPhone.isNotEmpty ? cleanPhone : 'Friend')),
          email: cleanEmail.isNotEmpty ? cleanEmail : '$cleanPhone@splitit.app',
          phoneNumber: cleanPhone.isNotEmpty ? cleanPhone : null,
          createdAt: DateTime.now(),
          isEmailVerified: false,
          isPhoneVerified: false,
        );
        await firestore
            .collection('users')
            .doc(placeholder.id)
            .set(placeholder.toJson());
        _users.add(placeholder);
        targetUser = placeholder;
      }

      // Already a friend?
      if (myFriendIds.contains(targetUser.id)) {
        return 'You are already friends with ${targetUser.name}.';
      }

      // Add friend to currentUser's friendIds and targetUser's friendIds (bidirectional sync)
      myFriendIds.add(targetUser.id);
      _currentUser = _currentUser!.copyWith(friendIds: myFriendIds);
      final myIdx = _users.indexWhere((u) => u.id == myId);
      if (myIdx != -1) _users[myIdx] = _currentUser!;

      final targetFriendIds = List<String>.from(targetUser.friendIds);
      if (!targetFriendIds.contains(myId)) {
        targetFriendIds.add(myId);
        targetUser = targetUser.copyWith(friendIds: targetFriendIds);
        final tIdx = _users.indexWhere((u) => u.id == targetUser!.id);
        if (tIdx != -1) _users[tIdx] = targetUser;
      }

      final activityItem = ActivityItem(
        id: _uuid.v4(),
        type: 'friend_added',
        title: 'Connected with "${targetUser.name}"',
        subtitle: targetUser.email,
        timestamp: DateTime.now(),
        actorId: myId,
        actorName: _currentUser?.name,
        audienceUserIds: [myId, targetUser.id],
      );
      _activities.insert(0, activityItem);

      // Notification for target user
      final notif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: targetUser.id,
        recipientName: targetUser.name,
        recipientEmail: targetUser.email,
        title: '${_currentUser!.name} added you as a friend',
        body: 'You are now connected on SplitIt.',
        timestamp: DateTime.now(),
        type: 'friend_added',
      );

      notifyListeners();

      final batch = firestore.batch();
      batch.update(firestore.collection('users').doc(myId), {
        'friendIds': myFriendIds,
      });
      batch.update(firestore.collection('users').doc(targetUser.id), {
        'friendIds': targetFriendIds,
      });
      batch.set(firestore.collection('activities').doc(activityItem.id), activityItem.toJson());
      batch.set(firestore.collection('notifications').doc(notif.id), notif.toJson());
      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('addFriend exception: $e');
      return 'Failed to add friend: $e';
    }
  }

  /// Add an existing registered user to an existing group.
  Future<String?> addMemberToGroup({
    required String groupId,
    required String userId,
  }) async {
    final group = getGroup(groupId);
    if (group == null) return 'Group not found.';

    final user = getUser(userId);
    if (user == null) return 'User not found.';

    if (group.memberIds.contains(userId)) {
      return '${user.name} is already a member of this group.';
    }

    final updatedMembers = [...group.memberIds, userId];
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      _groups[idx] = group.copyWith(memberIds: updatedMembers);
    }

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      type: 'member_added',
      title: '${user.name} added to "${group.name}"',
      subtitle: 'Added by ${_currentUser?.name ?? "someone"}',
      timestamp: DateTime.now(),
      actorId: _currentUser?.id,
      actorName: _currentUser?.name,
      groupId: groupId,
      groupName: group.name,
      audienceUserIds: updatedMembers,
    );
    _activities.insert(0, activityItem);

    // Notify the added member
    final addedNotif = AppNotification(
      id: _uuid.v4(),
      recipientUserId: user.id,
      recipientName: user.name,
      recipientEmail: user.email,
      title: 'You were added to "${group.name}"',
      body: '${_currentUser?.name ?? "Someone"} added you to the group "${group.name}".',
      timestamp: DateTime.now(),
      groupId: groupId,
      groupName: group.name,
      type: 'member_added',
    );
    if (user.id == _currentUser?.id) {
      _notifications.insert(0, addedNotif);
    }

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection('groups').doc(groupId), {
        'memberIds': updatedMembers,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      batch.set(firestore.collection('activities').doc(activityItem.id), activityItem.toJson());
      batch.set(firestore.collection('notifications').doc(addedNotif.id), addedNotif.toJson());
      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('addMemberToGroup error: $e');
      return 'Failed to add member: $e';
    }
  }

  @override
  void dispose() {
    _cancelUserStreams();
    super.dispose();
  }
}

class ContactFriendResult {
  final bool permissionDenied;
  final List<User> friends;
  final int contactsCount;
  final String? error;

  ContactFriendResult({
    required this.permissionDenied,
    required this.friends,
    required this.contactsCount,
    this.error,
  });
}
