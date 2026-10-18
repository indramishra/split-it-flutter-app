import '../models/expense.dart';
import '../models/user.dart';

class DebtSimplifier {
  /// Computes net balances for all members in the group or overall.
  /// Positive value means the user is owed money (creditor).
  /// Negative value means the user owes money (debtor).
  static Map<String, double> computeNetBalances({
    required List<Expense> expenses,
    List<String>? memberIds,
  }) {
    final net = <String, double>{};

    if (memberIds != null) {
      for (final id in memberIds) {
        net[id] = 0.0;
      }
    }

    for (final exp in expenses) {
      // The payer gets credited the total cost
      net[exp.paidByUserId] = (net[exp.paidByUserId] ?? 0.0) + exp.cost;

      // Each split participant gets debited their share
      for (final entry in exp.splitShares.entries) {
        final userId = entry.key;
        final share = entry.value;
        net[userId] = (net[userId] ?? 0.0) - share;
      }
    }

    // Clean up rounding errors within 1 cent (0.005)
    final cleaned = <String, double>{};
    for (final entry in net.entries) {
      if (entry.value.abs() > 0.009) {
        cleaned[entry.key] = double.parse(entry.value.toStringAsFixed(2));
      } else {
        cleaned[entry.key] = 0.0;
      }
    }
    return cleaned;
  }

  /// Calculates simplified debts (minimum cash flow settlement)
  /// Guarantee: At most N - 1 transactions, removes circular and chained debts.
  static List<Debt> simplifyDebts(Map<String, double> netBalances) {
    final debtors = <_UserBalance>[];
    final creditors = <_UserBalance>[];

    for (final entry in netBalances.entries) {
      final bal = double.parse(entry.value.toStringAsFixed(2));
      if (bal < -0.01) {
        debtors.add(_UserBalance(userId: entry.key, amount: -bal));
      } else if (bal > 0.01) {
        creditors.add(_UserBalance(userId: entry.key, amount: bal));
      }
    }

    final simplified = <Debt>[];

    while (debtors.isNotEmpty && creditors.isNotEmpty) {
      // Sort to settle largest amounts first
      debtors.sort((a, b) => b.amount.compareTo(a.amount));
      creditors.sort((a, b) => b.amount.compareTo(a.amount));

      final debtor = debtors.first;
      final creditor = creditors.first;

      final settleAmount = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      final rounded = double.parse(settleAmount.toStringAsFixed(2));
      if (rounded > 0.009) {
        simplified.add(Debt(
          fromUserId: debtor.userId,
          toUserId: creditor.userId,
          amount: rounded,
        ));
      }

      debtor.amount -= settleAmount;
      creditor.amount -= settleAmount;

      if (debtor.amount <= 0.009) {
        debtors.removeAt(0);
      }
      if (creditor.amount <= 0.009) {
        creditors.removeAt(0);
      }
    }

    return simplified;
  }

  /// Calculates direct (pairwise) unsimplified debts from all expenses
  static List<Debt> computePairwiseDebts(List<Expense> expenses) {
    // pairKey: "from:to" -> amount
    final pairwise = <String, double>{};

    for (final exp in expenses) {
      final payer = exp.paidByUserId;
      for (final entry in exp.splitShares.entries) {
        final borrower = entry.key;
        final share = entry.value;

        if (borrower == payer || share <= 0.009) continue;

        // borrower owes payer 'share'
        final keyForward = '$borrower:$payer';
        final keyBackward = '$payer:$borrower';

        if (pairwise.containsKey(keyBackward)) {
          final existing = pairwise[keyBackward]!;
          if (existing >= share) {
            pairwise[keyBackward] = existing - share;
          } else {
            pairwise.remove(keyBackward);
            pairwise[keyForward] = share - existing;
          }
        } else {
          pairwise[keyForward] = (pairwise[keyForward] ?? 0.0) + share;
        }
      }
    }

    final result = <Debt>[];
    for (final entry in pairwise.entries) {
      final parts = entry.key.split(':');
      final amount = double.parse(entry.value.toStringAsFixed(2));
      if (amount > 0.009) {
        result.add(Debt(
          fromUserId: parts[0],
          toUserId: parts[1],
          amount: amount,
        ));
      }
    }
    return result;
  }
}

class _UserBalance {
  final String userId;
  double amount;

  _UserBalance({required this.userId, required this.amount});
}
