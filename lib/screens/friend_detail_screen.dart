import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/settle_up_sheet.dart';
import 'add_expense_screen.dart';

class FriendDetailScreen extends StatelessWidget {
  final String friendId;

  const FriendDetailScreen({super.key, required this.friendId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final friend = provider.getUser(friendId);

    if (friend == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friend')),
        body: const Center(child: Text('Friend not found')),
      );
    }

    final currency = provider.currency;
    final balance = provider.getBalanceWithFriend(friend.id);
    final isOwed = balance > 0.01;
    final isOwe = balance < -0.01;
    final isSettled = balance.abs() <= 0.01;
    final expenses = provider.getExpensesWithFriend(friend.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(friend.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Balance Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.tealLight,
                  child: Text(
                    friend.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.tealDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  friend.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  friend.email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSettled
                        ? Colors.grey.shade100
                        : (isOwed ? AppTheme.tealLight : const Color(0xFFFFECE5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isSettled
                            ? 'You are settled up'
                            : (isOwed ? '${friend.name} owes you' : 'You owe ${friend.name}'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSettled
                              ? Colors.grey.shade700
                              : (isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$currency ${balance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isSettled
                              ? AppTheme.charcoal
                              : (isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Settle Up'),
                        onPressed: () {
                          SettleUpSheet.show(
                            context,
                            initialPayerId: isOwe ? provider.currentUser.id : friend.id,
                            initialReceiverId: isOwe ? friend.id : provider.currentUser.id,
                            initialAmount: balance.abs() > 0 ? balance.abs() : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.teal,
                          side: const BorderSide(color: AppTheme.teal),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Expense'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => AddExpenseScreen(
                                preselectedFriendId: friend.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Shared Expenses List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Shared Expenses (${expenses.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No shared expenses yet',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ...expenses.map((exp) {
              final dateFormat = DateFormat('MMM d, yyyy');
              final isPayerMe = exp.paidByUserId == provider.currentUser.id;
              final myShare = exp.splitShares[provider.currentUser.id] ?? 0.0;

              return Card(
                child: ListTile(
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    dateFormat.format(exp.date),
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
                            color: isPayerMe
                                ? AppTheme.positiveGreen
                                : AppTheme.negativeOrange,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
