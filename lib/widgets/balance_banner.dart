import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';

class BalanceBanner extends StatelessWidget {
  const BalanceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final balances = provider.getUserOverallBalance(provider.currentUser.id);
    final net = balances['net'] ?? 0.0;
    final youAreOwed = balances['totalYouAreOwed'] ?? 0.0;
    final youOwe = balances['totalYouOwe'] ?? 0.0;
    final currency = provider.currency;

    final isSettled = net.abs() < 0.01;
    final isOwed = net > 0.01;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSettled
                      ? Colors.grey.shade100
                      : (isOwed ? AppTheme.tealLight : const Color(0xFFFFECE5)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSettled
                      ? Icons.check_circle_outline
                      : (isOwed ? Icons.arrow_downward : Icons.arrow_upward),
                  color: isSettled
                      ? Colors.grey
                      : (isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSettled
                          ? 'You are all settled up!'
                          : (isOwed
                              ? 'Overall, you are owed'
                              : 'Overall, you owe'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSettled
                          ? '$currency 0.00'
                          : '$currency ${net.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isSettled
                            ? AppTheme.charcoal
                            : (isOwed
                                ? AppTheme.positiveGreen
                                : AppTheme.negativeOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isSettled) ...[
            const Divider(height: 24, thickness: 0.8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are owed',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      Text(
                        '$currency ${youAreOwed.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.positiveGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You owe',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      Text(
                        '$currency ${youOwe.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.negativeOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
