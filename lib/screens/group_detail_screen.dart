import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../models/group.dart';
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
      builder: (ctx) => AlertDialog(
        title: Text('${group.name} Members'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: group.memberIds.map((id) {
              final user = provider.getUser(id);
              final isMe = id == provider.currentUser.id;
              return ListTile(
                leading: CircleAvatar(child: Text(user?.name[0] ?? '?')),
                title: Text(user?.name ?? id),
                subtitle: Text(user?.email ?? ''),
                trailing: isMe
                    ? const Chip(label: Text('You', style: TextStyle(fontSize: 11)))
                    : null,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
