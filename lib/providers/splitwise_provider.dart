import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/notification_model.dart';
import '../services/debt_simplifier.dart';

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

  // Firestore Subscriptions
  StreamSubscription? _usersSub;
  StreamSubscription? _groupsSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _activitiesSub;
  StreamSubscription? _notificationsSub;

  // Legacy test data IDs to filter and purge
  static const Set<String> _legacyMockUserIds = {
    'usr_me',
    'usr_rahul',
    'usr_priya',
    'usr_amit',
    'usr_sneha',
  };
  static const Set<String> _legacyMockGroupIds = {
    'grp_apt',
    'grp_goa',
  };
  static const Set<String> _legacyMockExpenseIds = {
    'exp_1',
    'exp_2',
    'exp_3',
    'exp_4',
  };
  static const Set<String> _legacyMockNotifIds = {
    'notif_1',
    'notif_2',
    'notif_3',
    'notif_4',
  };
  static const Set<String> _legacyMockActivityIds = {
    'act_1',
    'act_2',
  };

  SplitwiseProvider() {
    _initAuth();
    _initFirestoreSync();
  }

  // Getters
  bool get isAuthLoading => _isAuthLoading;
  bool get isAuthenticated => _currentUser != null;
  User get currentUser =>
      _currentUser ?? const User(id: '', name: 'Guest', email: '');
  List<User> get users => List.unmodifiable(_users);
  List<User> get friends =>
      _users.where((u) => u.id != (_currentUser?.id ?? '')).toList();
  List<Group> get groups => List.unmodifiable(_groups);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<ActivityItem> get activities =>
      List.unmodifiable(_activities..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  int get unreadNotificationCount => _notifications
      .where((n) => !n.isRead && n.recipientUserId == (_currentUser?.id ?? ''))
      .length;
  int get totalUnreadAllMembersCount =>
      _notifications.where((n) => !n.isRead).length;
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
      notifyListeners();
    }
  }

  User? getUser(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
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
        } else {
          final user = _users.where((u) => u.id == savedUserId).firstOrNull;
          if (user != null) _currentUser = user;
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
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) return 'Please enter your full name.';
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final existing = await firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return 'An account with this email already exists. Please log in.';
      }

      final newUser = User(
        id: _uuid.v4(),
        name: cleanName,
        email: cleanEmail,
        password: password,
        createdAt: DateTime.now(),
      );

      await firestore
          .collection('users')
          .doc(newUser.id)
          .set(newUser.toJson());

      // Welcome activity
      final welcomeAct = ActivityItem(
        id: _uuid.v4(),
        title: 'Welcome to SplitIt, $cleanName!',
        subtitle: 'Account created. You can now create groups, add friends & split bills.',
        timestamp: DateTime.now(),
      );
      firestore
          .collection('activities')
          .doc(welcomeAct.id)
          .set(welcomeAct.toJson())
          .catchError((_) {});

      _currentUser = newUser;
      if (!_users.any((u) => u.id == newUser.id)) {
        _users.add(newUser);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_user_id', newUser.id);

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Registration exception: $e');
      return 'Registration failed: $e';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (password.isEmpty) {
      return 'Please enter your password.';
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snap = await firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        final inMem = _users
            .where((u) => u.email.toLowerCase() == cleanEmail)
            .firstOrNull;
        if (inMem == null) {
          return 'No account found with this email. Please register.';
        }
        if (inMem.password != null && inMem.password != password) {
          return 'Incorrect password. Please try again.';
        }
        _currentUser = inMem;
      } else {
        final userData = snap.docs.first.data();
        final user = User.fromJson(userData);
        if (user.password != null && user.password != password) {
          return 'Incorrect password. Please try again.';
        }
        _currentUser = user;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_user_id', _currentUser!.id);

      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Login exception: $e');
      return 'Login failed: $e';
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_user_id');
    notifyListeners();
  }

  // ==========================================
  // PURGE LEGACY TESTING DATA
  // ==========================================

  Future<void> purgeLegacyTestData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final id in _legacyMockUserIds) {
        batch.delete(firestore.collection('users').doc(id));
      }
      for (final id in _legacyMockGroupIds) {
        batch.delete(firestore.collection('groups').doc(id));
      }
      for (final id in _legacyMockExpenseIds) {
        batch.delete(firestore.collection('expenses').doc(id));
      }
      for (final id in _legacyMockActivityIds) {
        batch.delete(firestore.collection('activities').doc(id));
      }
      for (final id in _legacyMockNotifIds) {
        batch.delete(firestore.collection('notifications').doc(id));
      }

      await batch.commit();
      debugPrint('Legacy testing data successfully purged from Firestore.');
    } catch (e) {
      debugPrint('Error purging legacy test data: $e');
    }

    _users.removeWhere((u) => _legacyMockUserIds.contains(u.id));
    _groups.removeWhere((g) => _legacyMockGroupIds.contains(g.id));
    _expenses.removeWhere((e) => _legacyMockExpenseIds.contains(e.id));
    _activities.removeWhere((a) => _legacyMockActivityIds.contains(a.id));
    _notifications.removeWhere((n) => _legacyMockNotifIds.contains(n.id));
    notifyListeners();
  }

  // ==========================================
  // FIRESTORE SYNC & STREAMS
  // ==========================================

  void _initFirestoreSync() {
    try {
      final firestore = FirebaseFirestore.instance;

      purgeLegacyTestData();

      _usersSub = firestore.collection('users').snapshots().listen((snap) {
        final newUsers = snap.docs
            .map((d) => User.fromJson(d.data()))
            .where((u) => !_legacyMockUserIds.contains(u.id))
            .toList();
        _users.clear();
        _users.addAll(newUsers);

        if (_currentUser != null) {
          final matched = _users.where((u) => u.id == _currentUser!.id).firstOrNull;
          if (matched != null) {
            _currentUser = matched;
          }
        }
        notifyListeners();
      }, onError: (e) => debugPrint('Users stream error: $e'));

      _groupsSub = firestore.collection('groups').snapshots().listen((snap) {
        final newGroups = snap.docs
            .map((d) => Group.fromJson(d.data()))
            .where((g) => !_legacyMockGroupIds.contains(g.id))
            .toList();
        _groups.clear();
        _groups.addAll(newGroups);
        notifyListeners();
      }, onError: (e) => debugPrint('Groups stream error: $e'));

      _expensesSub = firestore.collection('expenses').snapshots().listen((snap) {
        final newExpenses = snap.docs
            .map((d) => Expense.fromJson(d.data()))
            .where((e) => !_legacyMockExpenseIds.contains(e.id))
            .toList();
        _expenses.clear();
        _expenses.addAll(newExpenses);
        notifyListeners();
      }, onError: (e) => debugPrint('Expenses stream error: $e'));

      _activitiesSub = firestore.collection('activities').snapshots().listen((snap) {
        final newActivities = snap.docs
            .map((d) => ActivityItem.fromJson(d.data()))
            .where((a) => !_legacyMockActivityIds.contains(a.id))
            .toList();
        _activities.clear();
        _activities.addAll(newActivities);
        notifyListeners();
      }, onError: (e) => debugPrint('Activities stream error: $e'));

      _notificationsSub = firestore.collection('notifications').snapshots().listen((snap) {
        final newNotifs = snap.docs
            .map((d) => AppNotification.fromJson(d.data()))
            .where((n) => !_legacyMockNotifIds.contains(n.id))
            .toList();
        _notifications.clear();
        _notifications.addAll(newNotifs);
        notifyListeners();
      }, onError: (e) => debugPrint('Notifications stream error: $e'));
    } catch (e) {
      debugPrint('Firestore initialization error: $e');
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
      final isPayer = e.paidByUserId == friendId || e.paidByUserId == myId;
      final isParticipant =
          e.splitShares.containsKey(friendId) && e.splitShares.containsKey(myId);
      return isPayer && (isParticipant || e.paidByUserId != myId);
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
    final newExpense = Expense(
      id: _uuid.v4(),
      groupId: groupId,
      description: description,
      cost: cost,
      date: date ?? DateTime.now(),
      paidByUserId: paidByUserId,
      category: category,
      splitShares: splitShares,
      notes: notes,
    );

    _expenses.add(newExpense);

    final payer = getUser(paidByUserId)?.name ?? 'Someone';
    final group = groupId != null ? getGroup(groupId) : null;
    final context = group != null ? 'in "${group.name}"' : '';

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      title: '$payer added "$description"',
      subtitle: '$context • $_currency${cost.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      expenseId: newExpense.id,
    );
    _activities.add(activityItem);

    final recipients = <String>{};
    if (group != null) {
      recipients.addAll(group.memberIds);
    } else {
      recipients.addAll(splitShares.keys);
      recipients.add(paidByUserId);
    }

    final newNotifs = <AppNotification>[];
    for (final recipientId in recipients) {
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
      _notifications.add(notif);
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
      isPayment: true,
      notes: 'Settled payment',
    );

    _expenses.add(paymentExpense);

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      title: '$fromUser settled with $toUser',
      subtitle: 'Payment of $_currency${amount.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      expenseId: paymentExpense.id,
    );
    _activities.add(activityItem);

    final group = groupId != null ? getGroup(groupId) : null;
    final recipients = <String>{fromUserId, toUserId};
    if (group != null) {
      recipients.addAll(group.memberIds);
    }

    final newNotifs = <AppNotification>[];
    for (final recipientId in recipients) {
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
      _notifications.add(notif);
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
      title: 'Deleted expense "${exp.description}"',
      subtitle: 'Amount: $_currency${exp.cost.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
    );
    _activities.add(deleteActivity);

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
      simplifyByDefault: simplifyByDefault,
    );

    _groups.add(newGroup);

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      title: 'Created group "${newGroup.name}"',
      subtitle: '${allMembers.length} members',
      timestamp: DateTime.now(),
    );
    _activities.add(activityItem);

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
      _notifications.add(notif);
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
        });
        final idx = _groups.indexWhere((g) => g.id == groupId);
        if (idx != -1) {
          _groups[idx] = group.copyWith(memberIds: updatedMembers);
        }
      }

      final act = ActivityItem(
        id: _uuid.v4(),
        title: '$userName left group "${group.name}"',
        subtitle: '${updatedMembers.length} members remaining',
        timestamp: DateTime.now(),
      );
      batch.set(firestore.collection('activities').doc(act.id), act.toJson());
      _activities.add(act);

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
        _notifications.add(notif);
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
    return _groups.where((g) {
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
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      for (final n in _notifications) {
        batch.update(firestore.collection('notifications').doc(n.id), {'isRead': true});
      }
      batch.commit().catchError((e) => debugPrint('Firestore markAllNotificationsAsRead error: $e'));
    } catch (e) {
      debugPrint('Firestore markAllNotificationsAsRead exception: $e');
    }
  }

  void markNotificationAsRead(String notificationId) {
    final n = _notifications.firstWhere(
      (item) => item.id == notificationId,
      orElse: () => _notifications.first,
    );
    n.isRead = true;
    notifyListeners();

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
    final toDelete = List<AppNotification>.from(_notifications);
    _notifications.clear();
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

  void addFriend({required String name, required String email}) {
    final newFriend = User(
      id: _uuid.v4(),
      name: name,
      email: email.trim().toLowerCase(),
      createdAt: DateTime.now(),
    );
    _users.add(newFriend);

    final activityItem = ActivityItem(
      id: _uuid.v4(),
      title: 'Added friend "$name"',
      subtitle: email,
      timestamp: DateTime.now(),
    );
    _activities.add(activityItem);

    notifyListeners();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.set(firestore.collection('users').doc(newFriend.id), newFriend.toJson());
      batch.set(firestore.collection('activities').doc(activityItem.id), activityItem.toJson());
      batch.commit().catchError((e) => debugPrint('Firestore addFriend error: $e'));
    } catch (e) {
      debugPrint('Firestore addFriend exception: $e');
    }
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _groupsSub?.cancel();
    _expensesSub?.cancel();
    _activitiesSub?.cancel();
    _notificationsSub?.cancel();
    super.dispose();
  }
}
