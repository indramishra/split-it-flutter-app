import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/notification_model.dart';
import '../services/debt_simplifier.dart';

class SplitwiseProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  // Current Logged In User
  late User _currentUser;

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
  bool _isSeeding = false;

  SplitwiseProvider() {
    _initDemoData();
    _initFirestoreSync();
  }

  User get currentUser => _currentUser;
  List<User> get users => List.unmodifiable(_users);
  List<User> get friends =>
      _users.where((u) => u.id != _currentUser.id).toList();
  List<Group> get groups => List.unmodifiable(_groups);
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<ActivityItem> get activities =>
      List.unmodifiable(_activities..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead && n.recipientUserId == _currentUser.id).length;
  int get totalUnreadAllMembersCount =>
      _notifications.where((n) => !n.isRead).length;
  String get currency => _currency;

  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    notifyListeners();
  }

  void switchCurrentUser(String userId) {
    final user = _users.firstWhere((u) => u.id == userId, orElse: () => _currentUser);
    _currentUser = user;
    notifyListeners();
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

  List<Expense> getExpensesForGroup(String groupId) {
    final list = _expenses.where((e) => e.groupId == groupId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<Expense> getExpensesWithFriend(String friendId) {
    final list = _expenses.where((e) {
      final isPayer = e.paidByUserId == friendId || e.paidByUserId == _currentUser.id;
      final isParticipant = e.splitShares.containsKey(friendId) &&
          e.splitShares.containsKey(_currentUser.id);
      return isPayer && (isParticipant || e.paidByUserId != _currentUser.id);
    }).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // Calculate overall balance for a user: { 'owed': 450.0, 'owe': 120.0, 'net': 330.0 }
  Map<String, double> getUserOverallBalance(String userId) {
    final net = DebtSimplifier.computeNetBalances(expenses: _expenses);
    final userNet = net[userId] ?? 0.0;

    // Direct debts involving this user across all friends
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

  // Get net balance between current user and a specific friend
  double getBalanceWithFriend(String friendId) {
    final debts = DebtSimplifier.computePairwiseDebts(_expenses);
    double balance = 0.0;
    for (final d in debts) {
      if (d.toUserId == _currentUser.id && d.fromUserId == friendId) {
        balance += d.amount; // friend owes you
      } else if (d.fromUserId == _currentUser.id && d.toUserId == friendId) {
        balance -= d.amount; // you owe friend
      }
    }
    return double.parse(balance.toStringAsFixed(2));
  }

  // Get group debts (either simplified or pairwise)
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

  // Real-time Firestore sync setup
  void _initFirestoreSync() {
    try {
      final firestore = FirebaseFirestore.instance;

      firestore.collection('users').get().then((snapshot) {
        if (snapshot.docs.isEmpty && !_isSeeding) {
          _isSeeding = true;
          _seedInitialFirestoreData(firestore);
        }
      }).catchError((e) {
        debugPrint('Firestore seed check error: $e');
      });

      _usersSub = firestore.collection('users').snapshots().listen((snap) {
        if (snap.docs.isNotEmpty) {
          final newUsers = snap.docs.map((d) => User.fromJson(d.data())).toList();
          _users.clear();
          _users.addAll(newUsers);
          try {
            _currentUser = _users.firstWhere((u) => u.id == _currentUser.id);
          } catch (_) {
            if (_users.isNotEmpty) _currentUser = _users.first;
          }
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Users stream error: $e'));

      _groupsSub = firestore.collection('groups').snapshots().listen((snap) {
        if (snap.docs.isNotEmpty) {
          _groups.clear();
          _groups.addAll(snap.docs.map((d) => Group.fromJson(d.data())));
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Groups stream error: $e'));

      _expensesSub = firestore.collection('expenses').snapshots().listen((snap) {
        if (snap.docs.isNotEmpty) {
          _expenses.clear();
          _expenses.addAll(snap.docs.map((d) => Expense.fromJson(d.data())));
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Expenses stream error: $e'));

      _activitiesSub = firestore.collection('activities').snapshots().listen((snap) {
        if (snap.docs.isNotEmpty) {
          _activities.clear();
          _activities.addAll(snap.docs.map((d) => ActivityItem.fromJson(d.data())));
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Activities stream error: $e'));

      _notificationsSub = firestore.collection('notifications').snapshots().listen((snap) {
        if (snap.docs.isNotEmpty) {
          _notifications.clear();
          _notifications.addAll(snap.docs.map((d) => AppNotification.fromJson(d.data())));
          notifyListeners();
        }
      }, onError: (e) => debugPrint('Notifications stream error: $e'));
    } catch (e) {
      debugPrint('Firestore initialization error: $e');
    }
  }

  Future<void> _seedInitialFirestoreData(FirebaseFirestore firestore) async {
    final batch = firestore.batch();
    for (final u in _users) {
      batch.set(firestore.collection('users').doc(u.id), u.toJson());
    }
    for (final g in _groups) {
      batch.set(firestore.collection('groups').doc(g.id), g.toJson());
    }
    for (final e in _expenses) {
      batch.set(firestore.collection('expenses').doc(e.id), e.toJson());
    }
    for (final a in _activities) {
      batch.set(firestore.collection('activities').doc(a.id), a.toJson());
    }
    for (final n in _notifications) {
      batch.set(firestore.collection('notifications').doc(n.id), n.toJson());
    }
    try {
      await batch.commit();
      debugPrint('Firestore successfully seeded with initial data.');
    } catch (e) {
      debugPrint('Firestore seed batch commit failed: $e');
    }
  }

  // Add new expense
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

    // Dispatch notification to ALL group members (or split participants)
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

    // Sync to Firestore
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

  // Settle up payment between two users
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

    // Dispatch notification to ALL group members
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

    // Sync to Firestore
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
    final allMembers = {...memberIds, _currentUser.id}.toList();
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

    // Dispatch notification to ALL members added to the group
    final newNotifs = <AppNotification>[];
    for (final memberId in allMembers) {
      final member = getUser(memberId);
      if (member == null) continue;
      final isCreator = memberId == _currentUser.id;

      final notif = AppNotification(
        id: _uuid.v4(),
        recipientUserId: member.id,
        recipientName: member.name,
        recipientEmail: member.email,
        title: isCreator
            ? 'You created group "$name"'
            : 'You were added to group "$name"',
        body: '${allMembers.length} members were added to $name ($groupType).',
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
      email: email,
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

  void _initDemoData() {
    _currentUser = const User(
      id: 'usr_me',
      name: 'You',
      email: 'you@splitwise.clone',
    );

    final u1 = const User(
      id: 'usr_rahul',
      name: 'Rahul Sharma',
      email: 'rahul@example.com',
    );
    final u2 = const User(
      id: 'usr_priya',
      name: 'Priya Patel',
      email: 'priya@example.com',
    );
    final u3 = const User(
      id: 'usr_amit',
      name: 'Amit Verma',
      email: 'amit@example.com',
    );
    final u4 = const User(
      id: 'usr_sneha',
      name: 'Sneha Rao',
      email: 'sneha@example.com',
    );

    _users.addAll([_currentUser, u1, u2, u3, u4]);

    final g1 = Group(
      id: 'grp_apt',
      name: 'Apartment 402',
      groupType: 'home',
      memberIds: [_currentUser.id, u1.id, u2.id],
      simplifyByDefault: true,
    );

    final g2 = Group(
      id: 'grp_goa',
      name: 'Goa Trip 2026',
      groupType: 'trip',
      memberIds: [_currentUser.id, u1.id, u2.id, u3.id, u4.id],
      simplifyByDefault: true,
    );

    _groups.addAll([g1, g2]);

    // Initial expenses
    _expenses.addAll([
      Expense(
        id: 'exp_1',
        groupId: g1.id,
        description: 'WiFi & Fiber Internet',
        cost: 1500.0,
        date: DateTime.now().subtract(const Duration(days: 4)),
        paidByUserId: _currentUser.id,
        category: 'Utilities',
        splitShares: {
          _currentUser.id: 500.0,
          u1.id: 500.0,
          u2.id: 500.0,
        },
      ),
      Expense(
        id: 'exp_2',
        groupId: g1.id,
        description: 'Groceries & Milk',
        cost: 900.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
        paidByUserId: u1.id,
        category: 'Groceries',
        splitShares: {
          _currentUser.id: 300.0,
          u1.id: 300.0,
          u2.id: 300.0,
        },
      ),
      Expense(
        id: 'exp_3',
        groupId: g2.id,
        description: 'Resort Booking Deposit',
        cost: 10000.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        paidByUserId: _currentUser.id,
        category: 'Travel',
        splitShares: {
          _currentUser.id: 2000.0,
          u1.id: 2000.0,
          u2.id: 2000.0,
          u3.id: 2000.0,
          u4.id: 2000.0,
        },
      ),
      Expense(
        id: 'exp_4',
        groupId: g2.id,
        description: 'Beach Shack Seafood Dinner',
        cost: 4500.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        paidByUserId: u3.id,
        category: 'Food & Drink',
        splitShares: {
          _currentUser.id: 900.0,
          u1.id: 900.0,
          u2.id: 900.0,
          u3.id: 900.0,
          u4.id: 900.0,
        },
      ),
    ]);

    _activities.addAll([
      ActivityItem(
        id: 'act_1',
        title: 'You added "Resort Booking Deposit"',
        subtitle: 'Goa Trip 2026 • ₹10,000.00',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ActivityItem(
        id: 'act_2',
        title: 'Amit Verma added "Beach Shack Seafood Dinner"',
        subtitle: 'Goa Trip 2026 • ₹4,500.00',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);

    // Initial group notification broadcasts
    _notifications.addAll([
      AppNotification(
        id: 'notif_1',
        recipientUserId: _currentUser.id,
        recipientName: _currentUser.name,
        recipientEmail: _currentUser.email,
        title: 'Amit Verma added an expense in "Goa Trip 2026"',
        body: 'Amit Verma added "Beach Shack Seafood Dinner" (₹4,500.00). Your share is ₹900.00.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        groupId: g2.id,
        groupName: g2.name,
        type: 'expense_added',
        isRead: false,
      ),
      AppNotification(
        id: 'notif_2',
        recipientUserId: u1.id,
        recipientName: u1.name,
        recipientEmail: u1.email,
        title: 'Amit Verma added an expense in "Goa Trip 2026"',
        body: 'Amit Verma added "Beach Shack Seafood Dinner" (₹4,500.00). Your share is ₹900.00.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        groupId: g2.id,
        groupName: g2.name,
        type: 'expense_added',
        isRead: false,
      ),
      AppNotification(
        id: 'notif_3',
        recipientUserId: u2.id,
        recipientName: u2.name,
        recipientEmail: u2.email,
        title: 'Amit Verma added an expense in "Goa Trip 2026"',
        body: 'Amit Verma added "Beach Shack Seafood Dinner" (₹4,500.00). Your share is ₹900.00.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        groupId: g2.id,
        groupName: g2.name,
        type: 'expense_added',
        isRead: false,
      ),
      AppNotification(
        id: 'notif_4',
        recipientUserId: _currentUser.id,
        recipientName: _currentUser.name,
        recipientEmail: _currentUser.email,
        title: 'Rahul Sharma paid you',
        body: 'Rahul Sharma recorded a payment of ₹300.00 to settle up in "Apartment 402".',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        groupId: g1.id,
        groupName: g1.name,
        type: 'payment_settled',
        isRead: true,
      ),
    ]);
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
