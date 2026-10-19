import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/settle_up_sheet.dart';
import '../widgets/notification_drawer.dart';
import 'add_expense_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getGroupIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'trip':
        return Icons.flight_takeoff_outlined;
      case 'couple':
        return Icons.favorite_border;
      default:
        return Icons.group_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final group = provider.getGroup(widget.groupId);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group')),
        body: const Center(child: Text('Group not found')),
      );
    }

    final currency = provider.currency;
    final expenses = provider.getExpensesForGroup(group.id);
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.cost);
    final debts = provider.getGroupDebts(group.id);
    final unreadCount = provider.unreadNotificationCount;

    return Scaffold(
      endDrawer: const NotificationDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_getGroupIcon(group.groupType), size: 20, color: AppTheme.teal),
            const SizedBox(width: 8),
            Text(group.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Group Members',
            onPressed: () => _showMembersDialog(context, group),
          ),
          Builder(
            builder: (ctx) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Group Notifications & Mail',
                  onPressed: () {
                    Scaffold.of(ctx).openEndDrawer();
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.negativeOrange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'members') {
                _showMembersDialog(context, group);
              } else if (val == 'exit') {
                _showExitGroupDialog(context, group);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'members',
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Group Members'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'exit',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: AppTheme.negativeOrange, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Leave Group',
                      style: TextStyle(color: AppTheme.negativeOrange),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.teal,
          indicatorColor: AppTheme.teal,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances & Debts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Expenses List
          _buildExpensesTab(provider, expenses, totalSpent, currency),

          // Tab 2: Balances & Debts with Simplification Toggle
          _buildDebtsTab(provider, group, debts, currency),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => AddExpenseScreen(preselectedGroupId: group.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpensesTab(SplitwiseProvider provider, List expenses,
      double totalSpent, String currency) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No expenses yet in this group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "+ Add Expense" to split your first bill.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Total Group Spending card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Group Spending',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${totalSpent.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights, color: AppTheme.teal),
              ),
            ],
          ),
        ),

        ...expenses.map((exp) {
          final payer = provider.getUser(exp.paidByUserId)?.name ?? 'Someone';
          final dateFormat = DateFormat('MMM d, yyyy');
          final isPayerMe = exp.paidByUserId == provider.currentUser.id;
          final myShare = exp.splitShares[provider.currentUser.id] ?? 0.0;

          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: exp.isPayment ? const Color(0xFFE8F5E9) : AppTheme.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  exp.isPayment ? Icons.payments_outlined : Icons.receipt_outlined,
                  color: exp.isPayment ? AppTheme.positiveGreen : AppTheme.teal,
                ),
              ),
              title: Text(
                exp.description,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              subtitle: Text(
                'Paid by $payer • ${dateFormat.format(exp.date)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency ${exp.cost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.charcoal,
                    ),
                  ),
                  if (!exp.isPayment)
                    Text(
                      isPayerMe
                          ? 'you lent $currency${(exp.cost - myShare).toStringAsFixed(2)}'
                          : 'you borrowed $currency${myShare.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPayerMe ? AppTheme.positiveGreen : AppTheme.negativeOrange,
                      ),
                    ),
                ],
              ),
              onLongPress: () {
                _confirmDeleteExpense(context, provider, exp.id, exp.description);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDebtsTab(
      SplitwiseProvider provider, Group group, List debts, String currency) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Simplify Debts Switch Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high, size: 18, color: AppTheme.teal),
                        const SizedBox(width: 8),
                        const Text(
                          'Simplify Debts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.charcoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.simplifyByDefault
                          ? 'Debt restructuring is ON: Transactions minimized by cancelling circular payments.'
                          : 'Direct pairwise debts shown (Simplification is OFF).',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Switch(
                value: group.simplifyByDefault,
                activeTrackColor: AppTheme.teal,
                onChanged: (_) {
                  provider.toggleGroupSimplifyDebts(group.id);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (debts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, size: 56, color: AppTheme.positiveGreen),
                  const SizedBox(height: 12),
                  const Text(
                    'All settled up in this group!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
        else ...[
          const Text(
            'Suggested Settlements',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          ...debts.map((debt) {
            final fromUser = provider.getUser(debt.fromUserId)?.name ?? 'Someone';
            final toUser = provider.getUser(debt.toUserId)?.name ?? 'Someone';
            final isFromMe = debt.fromUserId == provider.currentUser.id;
            final isToMe = debt.toUserId == provider.currentUser.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isFromMe ? AppTheme.negativeOrange : AppTheme.tealLight,
                      foregroundColor: isFromMe ? Colors.white : AppTheme.tealDark,
                      child: Text(fromUser[0].toUpperCase()),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14, color: AppTheme.charcoal),
                              children: [
                                TextSpan(
                                  text: isFromMe ? 'You' : fromUser,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(text: ' owes '),
                                TextSpan(
                                  text: isToMe ? 'You' : toUser,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currency ${debt.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isFromMe
                                  ? AppTheme.negativeOrange
                                  : (isToMe ? AppTheme.positiveGreen : AppTheme.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        SettleUpSheet.show(
                          context,
                          initialPayerId: debt.fromUserId,
                          initialReceiverId: debt.toUserId,
                          initialAmount: debt.amount,
                          initialGroupId: group.id,
                        );
                      },
                      child: const Text('Settle'),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showMembersDialog(BuildContext context, Group group) {
    final provider = context.read<SplitwiseProvider>();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${group.name} Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: group.memberIds.map((id) {
                final user = provider.getUser(id);
                final isMe = id == provider.currentUser.id;
                final initial = user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMe ? AppTheme.tealLight : Colors.grey.shade200,
                    foregroundColor: isMe ? AppTheme.tealDark : AppTheme.charcoal,
                    child: Text(initial),
                  ),
                  title: Text(user?.name ?? id),
                  subtitle: Text(user?.email ?? ''),
                  trailing: isMe
                      ? const Chip(
                          label: Text('You', style: TextStyle(fontSize: 11)),
                          backgroundColor: AppTheme.tealLight,
                        )
                      : IconButton(
                          icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 20),
                          tooltip: 'Remove from group',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmRemoveMember(context, group, id, user?.name ?? 'Member');
                          },
                        ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('Add Member'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.teal),
              onPressed: () {
                Navigator.pop(ctx);
                _showAddMemberToGroupDialog(context, group);
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.negativeOrange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.exit_to_app, size: 16),
              label: const Text('Leave Group'),
              onPressed: () {
                Navigator.pop(ctx);
                _showExitGroupDialog(context, group);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberToGroupDialog(BuildContext context, Group group) {
    final provider = context.read<SplitwiseProvider>();
    final searchCtrl = TextEditingController();
    String query = '';

    // Friends not already in the group
    List<User> candidates() {
      final q = query.trim().toLowerCase();
      final myId = provider.currentUser.id;
      final pool = provider.friends.isNotEmpty ? provider.friends : provider.users;
      return pool.where((u) {
        return u.id != myId &&
            !group.memberIds.contains(u.id) &&
            (q.isEmpty ||
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q));
      }).toList();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add_alt_1, color: AppTheme.teal),
              const SizedBox(width: 8),
              Expanded(child: Text('Add to "${group.name}"')),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (val) => setDialogState(() => query = val),
                ),
                const SizedBox(height: 8),
                if (candidates().isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      provider.friends.isEmpty
                          ? 'No friends available to add.\nAdd friends first from the Friends tab or Contacts!'
                          : 'No matching friends. All your friends may already be in this group.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView(
                      shrinkWrap: true,
                      children: candidates().map((u) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: AppTheme.charcoal,
                            child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?'),
                          ),
                          title: Text(u.name),
                          subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final err = await provider.addMemberToGroup(
                                groupId: group.id,
                                userId: u.id,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err ?? '${u.name} added to "${group.name}"!'),
                                    backgroundColor: err != null ? Colors.red : AppTheme.teal,
                                  ),
                                );
                              }
                            },
                            child: const Text('Add', style: TextStyle(fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(
      BuildContext context, Group group, String memberId, String memberName) {
    final provider = context.read<SplitwiseProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove "$memberName" from "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.removeMemberFromGroup(groupId: group.id, memberId: memberId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed "$memberName" from group.')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showExitGroupDialog(BuildContext context, Group group) {
    final provider = context.read<SplitwiseProvider>();
    final myId = provider.currentUser.id;

    final debts = provider.getGroupDebts(group.id);
    double userOwes = 0.0;
    double userIsOwed = 0.0;
    for (final d in debts) {
      if (d.fromUserId == myId) userOwes += d.amount;
      if (d.toUserId == myId) userIsOwed += d.amount;
    }
    final net = userIsOwed - userOwes;
    final hasUnsettled = net.abs() > 0.01;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: AppTheme.negativeOrange),
            SizedBox(width: 8),
            Text('Leave Group'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to leave "${group.name}"?'),
            if (hasUnsettled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.negativeOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        net > 0
                            ? 'You are owed ${provider.currency}${net.toStringAsFixed(2)} in this group.'
                            : 'You owe ${provider.currency}${net.abs().toStringAsFixed(2)} in this group.',
                        style: const TextStyle(
                          color: AppTheme.negativeOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If you were added unintentionally, you can exit anyway.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (hasUnsettled)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(1);
              },
              child: const Text('Settle Up'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negativeOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await provider.exitGroup(
                groupId: group.id,
                userId: myId,
              );
              if (context.mounted) {
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err)),
                  );
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You left "${group.name}".')),
                  );
                }
              }
            },
            child: const Text('Exit Group'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(
      BuildContext context, SplitwiseProvider provider, String id, String desc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to remove "$desc"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteExpense(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
