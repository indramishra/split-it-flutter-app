import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:google_sign_in/google_sign_in.dart';
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
  final _auth = FirebaseAuth.instance;

  // Current Logged In User
  User? _currentUser;
  bool _isAuthLoading = true;

  // Phone auth state
  String? _verificationId;
  int? _resendToken;

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

  bool _googleSignInInitialized = false;

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
      // First, try to restore session from Firebase Auth (covers email, Google OAuth)
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          _currentUser = User.fromJson(doc.data()!);
          if (!_users.any((u) => u.id == _currentUser!.id)) {
            _users.add(_currentUser!);
          }
          _bindUserStreams();
          return;
        }
      }

      // Fallback: restore from SharedPreferences (covers phone/password-only users)
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

      // NOTE: We do NOT pre-check Firestore for email uniqueness here.
      // Doing so causes a false "already exists" error when a Firestore doc exists
      // from a previous Google Sign-In but no email+password Firebase Auth account
      // was ever created — the user then cannot register OR log in with email+password.
      // Firebase Auth's createUserWithEmailAndPassword is the authoritative duplicate
      // check and handles all providers correctly.

      // Check phone uniqueness in Firestore (no Firebase Auth equivalent for phone+password)
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

      // Create user in Firebase Auth if email provided
      UserCredential? authCredential;
      if (cleanEmail.isNotEmpty) {
        try {
          authCredential = await _auth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          // Send email verification link
          await authCredential.user?.sendEmailVerification();
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Attempt auto-login if the password matches the existing account
            try {
              final loginCred = await _auth.signInWithEmailAndPassword(
                email: cleanEmail,
                password: password,
              );
              if (loginCred.user != null) {
                final uid = loginCred.user!.uid;
                final snap = await firestore.collection('users').doc(uid).get();
                User appUser;
                if (snap.exists && snap.data() != null) {
                  appUser = User.fromJson(snap.data()!);
                } else {
                  appUser = User(
                    id: uid,
                    name: cleanName,
                    email: cleanEmail,
                    isEmailVerified: loginCred.user!.emailVerified,
                    createdAt: DateTime.now(),
                    phoneNumber: cleanPhone,
                    isPhoneVerified: false,
                  );
                  await firestore.collection('users').doc(uid).set(appUser.toJson());
                }
                _currentUser = appUser;
                if (!_users.any((u) => u.id == appUser.id)) _users.add(appUser);
                _bindUserStreams();
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('active_user_id', appUser.id);
                } catch (_) {}
                notifyListeners();
                return null; // Seamless login!
              }
            } catch (_) {
              // Sign-in with this password failed (wrong password or Google user)
            }
            return 'An account with this email already exists. If you signed up with Google, tap "Continue with Google". Otherwise, switch to the Log In tab.';
          }
          return 'Registration failed: ${e.message}';
        }
      }

      // Check if there is an existing placeholder user doc (e.g. from addFriend) to preserve friend connections
      List<String> existingFriendIds = [];
      if (cleanEmail.isNotEmpty) {
        final existingSnap = await firestore
            .collection('users')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (existingSnap.docs.isNotEmpty) {
          final existingDoc = existingSnap.docs.first;
          final existingData = existingDoc.data();
          if (existingData['friendIds'] != null) {
            existingFriendIds = (existingData['friendIds'] as List<dynamic>).cast<String>();
          }
          final newUid = authCredential?.user?.uid;
          if (newUid != null && existingDoc.id != newUid) {
            await firestore.collection('users').doc(existingDoc.id).delete().catchError((_) {});
          }
        }
      }

      // Create user document in Firestore
      final userId = authCredential?.user?.uid ?? _uuid.v4();
      final newUser = User(
        id: userId,
        name: cleanName,
        email: cleanEmail,
        password: cleanEmail.isNotEmpty ? null : password, // Don't store password if using Firebase Auth
        isEmailVerified: cleanEmail.isEmpty, // Skip if no email
        createdAt: DateTime.now(),
        phoneNumber: cleanPhone,
        isPhoneVerified: false,
        friendIds: existingFriendIds,
      );

      await firestore
          .collection('users')
          .doc(newUser.id)
          .set(newUser.toJson());

      // Welcome activity
      final welcomeAct = ActivityItem(
        id: _uuid.v4(),
        title: 'Welcome to SplitIt, $cleanName!',
        subtitle: cleanEmail.isNotEmpty 
            ? 'Account created. Check your email for verification link.'
            : 'Account created. Verify your phone number.',
        timestamp: DateTime.now(),
        userId: newUser.id,
      );
      firestore
          .collection('activities')
          .doc(welcomeAct.id)
          .set(welcomeAct.toJson())
          .catchError((_) {});

      _currentUser = newUser;

      // Send phone verification if phone provided
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        await sendPhoneVerificationCode(phoneNumber: cleanPhone);
      }

      // If email provided, verification email was sent via Firebase Auth
      if (cleanEmail.isNotEmpty) {
        await NotificationService().showNotification(
          id: 9990,
          title: 'Verify your email',
          body: 'We\'ve sent a verification link to $cleanEmail. Please check your inbox.',
        );
      }

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
    String? password,
    String? smsCode,
  }) async {
    // Phone + SMS code login (passwordless)
    if (phoneNumber != null && phoneNumber.isNotEmpty && smsCode != null && smsCode.isNotEmpty) {
      return await _loginWithPhone(phoneNumber, smsCode);
    }

    // Email + password login
    if (email == null || email.isEmpty) {
      if (phoneNumber == null || phoneNumber.isEmpty) {
        return 'Please enter your email or phone number.';
      }
    }
    if (password == null || password.isEmpty) {
      return 'Please enter your password.';
    }

    final isEmail = email != null && email.isNotEmpty;
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final cleanPhone = phoneNumber?.trim();

    try {
      final firestore = FirebaseFirestore.instance;
      User? user;

      if (isEmail) {
        // Sign in with Firebase Auth
        try {
          final authCredential = await _auth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );

          // Get user data from Firestore by Firebase Auth UID
          final snap = await firestore
              .collection('users')
              .doc(authCredential.user!.uid)
              .get();

          if (snap.exists && snap.data() != null) {
            user = User.fromJson(snap.data()!);
          } else {
            // Check if user exists by email (e.g. from an addFriend placeholder with a UUID)
            final emailSnap = await firestore
                .collection('users')
                .where('email', isEqualTo: cleanEmail)
                .limit(1)
                .get();
            if (emailSnap.docs.isNotEmpty) {
              final oldDoc = emailSnap.docs.first;
              final oldData = oldDoc.data();
              final migratedUser = User.fromJson({
                ...oldData,
                'id': authCredential.user!.uid,
                'isEmailVerified': authCredential.user!.emailVerified,
              });
              await firestore
                  .collection('users')
                  .doc(authCredential.user!.uid)
                  .set(migratedUser.toJson());
              if (oldDoc.id != authCredential.user!.uid) {
                await firestore.collection('users').doc(oldDoc.id).delete().catchError((_) {});
              }
              user = migratedUser;
            } else {
              // Rebuild the document from Firebase Auth profile
              final fbUser = authCredential.user!;
              final recoveredUser = User(
                id: fbUser.uid,
                name: fbUser.displayName ?? cleanEmail.split('@').first,
                email: cleanEmail,
                isEmailVerified: fbUser.emailVerified,
                createdAt: DateTime.now(),
              );
              await firestore
                  .collection('users')
                  .doc(fbUser.uid)
                  .set(recoveredUser.toJson());
              user = recoveredUser;
            }
          }
        } on FirebaseAuthException catch (e) {
          debugPrint('login FirebaseAuthException: ${e.code} - ${e.message}');
          // Check Firestore to see if this user exists with a custom password (from reset password or phone)
          final firestoreSnap = await firestore
              .collection('users')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();

          if (firestoreSnap.docs.isNotEmpty) {
            final docData = firestoreSnap.docs.first.data();
            final storedPassword = docData['password'] as String?;
            if (storedPassword != null && storedPassword == password) {
              // Password matches Firestore stored password!
              user = User.fromJson(docData);
            } else if (storedPassword == null) {
              return 'This email is registered with Google. Please tap "Continue with Google" below.';
            } else {
              return 'Incorrect password. Please try again or tap "Forgot Password?".';
            }
          }

          if (user == null) {
            if (e.code == 'wrong-password') {
              return 'Incorrect password. Please try again or tap "Forgot Password?".';
            }
            if (e.code == 'user-not-found') {
              return 'No account found with this email. Please switch to Sign Up.';
            }
            if (e.code == 'user-disabled') {
              return 'This account has been disabled.';
            }
            if (e.code == 'invalid-credential') {
              return 'Incorrect email or password. If you signed up with Google, please tap "Continue with Google".';
            }
            return 'Login failed: ${e.message}';
          }
        }
      } else {
        // Phone + password login (find user by phone, then verify password)
        final snap = await firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          user = User.fromJson(snap.docs.first.data());
        } else {
          // Try with stripped phone digits
          final stripped = cleanPhone?.replaceAll(RegExp(r'[\s\-().]'), '') ?? '';
          final snapDigits = await firestore
              .collection('users')
              .where('phoneNumber', isEqualTo: stripped)
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

      // Verify password for phone+password login (if not using Firebase Auth)
      if (!isEmail && user.password != null && user.password != password) {
        return 'Incorrect password. Please try again.';
      }

      _currentUser = user;

      if (!_users.any((u) => u.id == user!.id)) {
        _users.add(user);
      }

      _bindUserStreams();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_id', _currentUser!.id);
      } catch (prefErr) {
        debugPrint('Failed to save session to SharedPreferences: $prefErr');
      }

      // Sync email verification status from Firebase Auth
      if (isEmail && _auth.currentUser != null) {
        await _auth.currentUser!.reload();
        final isVerifiedInFirebase = _auth.currentUser!.emailVerified;
        if (isVerifiedInFirebase && !_currentUser!.isEmailVerified) {
          // Update local + Firestore if Firebase shows it's verified but our DB doesn't
          _currentUser = _currentUser!.copyWith(isEmailVerified: true);
          FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.id)
              .update({'isEmailVerified': true})
              .catchError((_) {});
        } else if (!isVerifiedInFirebase) {
          // Only send verification if not already verified
          sendEmailVerificationCode();
        }
      }

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Login exception: $e');
      return 'Login failed: $e';
    }
  }

  /// Passwordless login with phone + SMS code
  Future<String?> _loginWithPhone(String phoneNumber, String smsCode) async {
    final cleanPhone = phoneNumber.trim();

    try {
      final firestore = FirebaseFirestore.instance;
      User? user;

      // Find user by phone number
      final snap = await firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: cleanPhone)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        user = User.fromJson(snap.docs.first.data());
      } else {
        // Try with stripped phone digits
        final stripped = cleanPhone.replaceAll(RegExp(r'[\s\-().]'), '');
        final snapDigits = await firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: stripped)
            .limit(1)
            .get();
        if (snapDigits.docs.isNotEmpty) {
          user = User.fromJson(snapDigits.docs.first.data());
        }
      }

      if (user == null) {
        return 'No account found with this phone number. Please register.';
      }

      _currentUser = user;

      // Send SMS code if not already sent
      if (_verificationId == null) {
        final sendError = await sendPhoneVerificationCode(phoneNumber: cleanPhone);
        if (sendError != null) return sendError;
      }

      // Verify the SMS code
      final verifyError = await verifyPhone(smsCode);
      if (verifyError != null) return verifyError;

      // Save session
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_id', _currentUser!.id);
      } catch (prefErr) {
        debugPrint('Failed to save session to SharedPreferences: $prefErr');
      }

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Phone login exception: $e');
      return 'Phone login failed: $e';
    }
  }

  Future<void> logout() async {
    _cancelUserStreams();
    _currentUser = null;
    _groups.clear();
    _expenses.clear();
    _activities.clear();
    _notifications.clear();
    // Sign out from Firebase Auth (covers email and Google OAuth sessions)
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase sign-out error: $e');
    }
    // Sign out from Google Sign-In if it was initialized
    if (_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Google sign-out error: $e');
      }
      // Reset flag so the next signInWithGoogle() call re-initializes cleanly.
      _googleSignInInitialized = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_user_id');
    } catch (prefErr) {
      debugPrint('Failed to clear session in SharedPreferences: $prefErr');
    }
    notifyListeners();
  }

  // ==========================================
  // GOOGLE SIGN-IN
  // ==========================================

  Future<String?> signInWithGoogle() async {
    try {
      const webClientId = '236349691458-bom1i04b9f5fl6pdm28i1vckcdkprl1h.apps.googleusercontent.com';

      // Initialize Google Sign-In with serverClientId for Android / Web
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: webClientId,
        );
        _googleSignInInitialized = true;
      }

      // Sign out first to clear any stale/expired cached session.
      // google_sign_in v7 caches the last account and tries a silent re-auth on
      // the next authenticate() call. If that silent re-auth fails (token expired,
      // account state changed, etc.) it throws GoogleSignInException with code
      // `canceled` and description "[16] Account reauth failed." — which is not a
      // real user cancellation. Signing out first forces the account-picker UI to
      // always appear and avoids the stale-session reauth path entirely.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore sign-out errors; proceed with fresh authentication.
      }

      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('Google Sign-In: ID token is null from authenticate()');
        return 'Google sign-in failed: could not retrieve ID token. Please check that Google Sign-In is enabled in Firebase Console.';
      }

      final AuthCredential credential = GoogleAuthProvider.credential(idToken: idToken);

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        return 'Failed to sign in with Google.';
      }

      final firestore = FirebaseFirestore.instance;
      final uid = userCredential.user!.uid;
      final cleanEmail = account.email.trim().toLowerCase();

      // Check if user document exists
      final userDoc = await firestore.collection('users').doc(uid).get();
      User appUser;

      if (userDoc.exists && userDoc.data() != null) {
        // Existing user - update profile info from Google if changed
        appUser = User.fromJson(userDoc.data()!);
        final needsUpdate = appUser.name != (account.displayName ?? appUser.name) ||
            appUser.email != cleanEmail ||
            appUser.avatarUrl != account.photoUrl ||
            !appUser.isEmailVerified;
        if (needsUpdate) {
          appUser = appUser.copyWith(
            name: account.displayName ?? appUser.name,
            email: cleanEmail,
            avatarUrl: account.photoUrl,
            isEmailVerified: true, // Google emails are pre-verified
          );
          await firestore.collection('users').doc(uid).set(appUser.toJson());
        }
      } else {
        // Check if there is an existing placeholder/legacy document by email
        List<String> existingFriendIds = [];
        final existingByEmail = await firestore
            .collection('users')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (existingByEmail.docs.isNotEmpty) {
          final existingDoc = existingByEmail.docs.first;
          final existingData = existingDoc.data();
          if (existingData['friendIds'] != null) {
            existingFriendIds = (existingData['friendIds'] as List<dynamic>).cast<String>();
          }
          if (existingDoc.id != uid) {
            await firestore.collection('users').doc(existingDoc.id).delete().catchError((_) {});
          }
        }

        // New user - create document
        appUser = User(
          id: uid,
          name: account.displayName ?? 'Google User',
          email: cleanEmail,
          isEmailVerified: true, // Google emails are pre-verified
          createdAt: DateTime.now(),
          avatarUrl: account.photoUrl,
          friendIds: existingFriendIds,
        );
        await firestore.collection('users').doc(uid).set(appUser.toJson());

        // Welcome activity
        final welcomeAct = ActivityItem(
          id: _uuid.v4(),
          title: 'Welcome to SplitIt, ${appUser.name}!',
          subtitle: 'Account created with Google.',
          timestamp: DateTime.now(),
          userId: appUser.id,
        );
        firestore
            .collection('activities')
            .doc(welcomeAct.id)
            .set(welcomeAct.toJson())
            .catchError((_) {});
      }

      _currentUser = appUser;

      if (!_users.any((u) => u.id == appUser.id)) {
        _users.add(appUser);
      }

      _bindUserStreams();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_user_id', appUser.id);
      } catch (prefErr) {
        debugPrint('Failed to save session to SharedPreferences: $prefErr');
      }

      notifyListeners();
      return null;
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in error: ${e.code} - ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // Error code [16] means a silent reauth attempt failed internally — this
        // is NOT a real user cancellation. Show a friendly retry message instead
        // of exposing the raw "[16] Account reauth failed" technical string.
        final desc = e.description ?? '';
        if (desc.contains('[16]') || desc.contains('reauth')) {
          return 'Google sign-in failed. Please try again.';
        }
        // Empty or whitespace description = genuine user dismissal (back button).
        if (desc.trim().isEmpty) {
          return null; // Treat as no-op — user simply closed the picker.
        }
        return 'Google sign-in was cancelled.';
      }
      return 'Google sign-in failed: ${e.description ?? e.code.name}';
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in Firebase error: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        return 'An account already exists with this email. Please sign in with your password.';
      }
      return 'Google sign-in failed: ${e.message}';
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return 'Google sign-in failed: $e';
    }
  }

  // ==========================================
  // NOTIFICATION PERMISSIONS & EMAIL VERIFICATION
  // ==========================================

  Future<bool> requestNotificationPermission() async {
    return await NotificationService().requestPermissions();
  }

  Future<String?> sendEmailVerificationCode() async {
    if (_auth.currentUser == null) return 'No user is currently signed in.';
    
    try {
      await _auth.currentUser!.sendEmailVerification();
      
      await NotificationService().showNotification(
        id: 9990,
        title: 'Verification email sent',
        body: 'We\'ve sent a verification link to ${_auth.currentUser!.email}. Please check your inbox.',
      );
      return null;
    } catch (e) {
      debugPrint('Error sending email verification: $e');
      return 'Failed to send verification email: $e';
    }
  }

  /// Checks if email is verified via Firebase Auth and updates user state
  Future<bool> checkEmailVerified() async {
    if (_auth.currentUser == null || _currentUser == null) return false;
    try {
      await _auth.currentUser!.reload();
      final isVerified = _auth.currentUser!.emailVerified;
      if (isVerified && !_currentUser!.isEmailVerified) {
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

        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();
        batch.update(firestore.collection('users').doc(updatedUser.id), {
          'isEmailVerified': true,
        });
        batch.set(firestore.collection('activities').doc(verifyAct.id), verifyAct.toJson());
        await batch.commit();

        await NotificationService().showNotification(
          id: 9992,
          title: 'Email Verified 🎉',
          body: 'Your email is now verified on SplitIt!',
        );

        notifyListeners();
      }
      return isVerified;
    } catch (e) {
      debugPrint('Error in checkEmailVerified: $e');
      return false;
    }
  }

  /// Verifies email by checking Firebase Auth status
  Future<String?> verifyEmail(String code) async {
    // Firebase uses link-based verification, not code-based
    // This method checks if email is now verified
    if (_currentUser == null) return 'No user is currently signed in.';
    
    try {
      await _auth.currentUser?.reload();
      final isVerified = _auth.currentUser?.emailVerified ?? false;
      
      if (isVerified) {
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

        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();
        batch.update(firestore.collection('users').doc(updatedUser.id), {
          'isEmailVerified': true,
        });
        batch.set(firestore.collection('activities').doc(verifyAct.id), verifyAct.toJson());
        await batch.commit();

        await NotificationService().showNotification(
          id: 9992,
          title: 'Email Verified',
          body: 'Your email is now verified on SplitIt!',
        );
        return null;
      } else {
        return 'Email not verified yet. Please check your inbox and click the verification link.';
      }
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return 'Failed to verify email: $e';
    }
  }

  // ==========================================
  // PHONE VERIFICATION (Firebase Phone Auth)
  // ==========================================

  /// Sends a real SMS verification code using Firebase Phone Auth.
  /// Uses a Completer so we properly await codeSent/verificationFailed.
  Future<String?> sendPhoneVerificationCode({String? phoneNumber}) async {
    final targetPhone = phoneNumber ?? _currentUser?.phoneNumber;
    if (targetPhone == null || targetPhone.isEmpty) {
      return 'No phone number provided.';
    }

    final completer = Completer<String?>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: targetPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android (SMS retrieval API)
          await _linkPhoneCredential(credential);
          if (!completer.isCompleted) completer.complete(null);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Phone verification failed: ${e.code} - ${e.message}');
          if (!completer.isCompleted) {
            String msg;
            switch (e.code) {
              case 'invalid-phone-number':
                msg = 'Invalid phone number format. Please use international format (e.g. +91xxxxxxxxxx).';
                break;
              case 'quota-exceeded':
                msg = 'SMS quota exceeded. Please try again later.';
                break;
              case 'too-many-requests':
                msg = 'Too many SMS requests. Please wait a moment before trying again.';
                break;
              case 'billing-not-enabled':
                msg = 'SMS sending is not enabled. Please contact support.';
                break;
              default:
                msg = 'Failed to send SMS: ${e.message ?? e.code}';
            }
            completer.complete(msg);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          debugPrint('SMS code sent to $targetPhone (verificationId: $verificationId)');
          if (!completer.isCompleted) completer.complete(null);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete(null);
        },
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
      );
      // Wait for codeSent or verificationFailed callback
      return await completer.future;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return 'Failed to send SMS: $e';
    }
  }

  /// Verifies the SMS code and links phone to user account
  Future<String?> verifyPhone(String code) async {
    if (_verificationId == null) {
      return 'No pending verification. Please request a new code.';
    }
    if (_currentUser == null) return 'No user is currently signed in.';

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code.trim(),
      );

      // Link phone to current user
      await _linkPhoneCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return 'Invalid verification code. Please try again.';
      }
      if (e.code == 'session-expired') {
        return 'Verification code expired. Please request a new one.';
      }
      return 'Verification failed: ${e.message}';
    } catch (e) {
      debugPrint('Error verifying phone: $e');
      return 'Verification failed: $e';
    }
  }

  Future<void> _linkPhoneCredential(PhoneAuthCredential credential) async {
    if (_currentUser == null) return;

    try {
      // Link the phone credential to the current user
      await _auth.currentUser?.linkWithCredential(credential);

      // Update local user model
      final updatedUser = _currentUser!.copyWith(
        isPhoneVerified: true,
        clearPhoneVerificationCode: true,
      );
      _currentUser = updatedUser;

      // Clear verification state
      _verificationId = null;
      _resendToken = null;

      // Update Firestore
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final verifyAct = ActivityItem(
        id: _uuid.v4(),
        title: 'Phone verified',
        subtitle: '${updatedUser.phoneNumber} was confirmed',
        timestamp: DateTime.now(),
        userId: updatedUser.id,
      );

      batch.update(firestore.collection('users').doc(updatedUser.id), {
        'isPhoneVerified': true,
        'phoneVerificationCode': FieldValue.delete(),
      });
      batch.set(firestore.collection('activities').doc(verifyAct.id), verifyAct.toJson());
      await batch.commit();

      _activities.add(verifyAct);
      notifyListeners();

      await NotificationService().showNotification(
        id: 9995,
        title: 'Phone Verified',
        body: 'Your phone number is now verified on SplitIt!',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        // Phone already linked, just mark as verified
        final updatedUser = _currentUser!.copyWith(
          isPhoneVerified: true,
          clearPhoneVerificationCode: true,
        );
        _currentUser = updatedUser;
        notifyListeners();
      } else {
        debugPrint('Error linking phone: $e');
        rethrow;
      }
    }
  }

  /// Resend SMS code
  Future<String?> resendPhoneVerificationCode() async {
    return sendPhoneVerificationCode(phoneNumber: _currentUser?.phoneNumber);
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
