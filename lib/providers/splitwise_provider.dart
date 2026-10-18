import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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

  SplitwiseProvider() {
    _initDemoData();
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

    _activities.add(ActivityItem(
      id: _uuid.v4(),
      title: '$payer added "$description"',
      subtitle: '$context • $_currency${cost.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      expenseId: newExpense.id,
    ));

    // Dispatch notification to ALL group members (or split participants)
    final recipients = <String>{};
    if (group != null) {
      recipients.addAll(group.memberIds);
    } else {
      recipients.addAll(splitShares.keys);
      recipients.add(paidByUserId);
    }

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

      _notifications.add(AppNotification(
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
      ));
    }

    notifyListeners();
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

    _activities.add(ActivityItem(
      id: _uuid.v4(),
      title: '$fromUser settled with $toUser',
      subtitle: 'Payment of $_currency${amount.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
      expenseId: paymentExpense.id,
    ));

    // Dispatch notification to ALL group members
    final group = groupId != null ? getGroup(groupId) : null;
    final recipients = <String>{fromUserId, toUserId};
    if (group != null) {
      recipients.addAll(group.memberIds);
    }

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

      _notifications.add(AppNotification(
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
      ));
    }

    notifyListeners();
  }

  void deleteExpense(String expenseId) {
    final exp = _expenses.firstWhere((e) => e.id == expenseId, orElse: () => _expenses.first);
    _expenses.removeWhere((e) => e.id == expenseId);

    _activities.add(ActivityItem(
      id: _uuid.v4(),
      title: 'Deleted expense "${exp.description}"',
      subtitle: 'Amount: $_currency${exp.cost.toStringAsFixed(2)}',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  void toggleGroupSimplifyDebts(String groupId) {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      final g = _groups[index];
      _groups[index] = g.copyWith(simplifyByDefault: !g.simplifyByDefault);
      notifyListeners();
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

    _activities.add(ActivityItem(
      id: _uuid.v4(),
      title: 'Created group "${newGroup.name}"',
      subtitle: '${allMembers.length} members',
      timestamp: DateTime.now(),
    ));

    // Dispatch notification to ALL members added to the group
    for (final memberId in allMembers) {
      final member = getUser(memberId);
      if (member == null) continue;
      final isCreator = memberId == _currentUser.id;

      _notifications.add(AppNotification(
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
      ));
    }

    notifyListeners();
  }

  void markAllNotificationsAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markNotificationAsRead(String notificationId) {
    final n = _notifications.firstWhere(
      (item) => item.id == notificationId,
      orElse: () => _notifications.first,
    );
    n.isRead = true;
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  void addFriend({required String name, required String email}) {
    final newFriend = User(
      id: _uuid.v4(),
      name: name,
      email: email,
    );
    _users.add(newFriend);

    _activities.add(ActivityItem(
      id: _uuid.v4(),
      title: 'Added friend "$name"',
      subtitle: email,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
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
}
