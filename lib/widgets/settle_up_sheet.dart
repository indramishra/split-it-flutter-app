import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';

class SettleUpSheet extends StatefulWidget {
  final String? initialPayerId;
  final String? initialReceiverId;
  final double? initialAmount;
  final String? initialGroupId;

  const SettleUpSheet({
    super.key,
    this.initialPayerId,
    this.initialReceiverId,
    this.initialAmount,
    this.initialGroupId,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPayerId,
    String? initialReceiverId,
    double? initialAmount,
    String? initialGroupId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettleUpSheet(
        initialPayerId: initialPayerId,
        initialReceiverId: initialReceiverId,
        initialAmount: initialAmount,
        initialGroupId: initialGroupId,
      ),
    );
  }

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  late String _payerId;
  late String _receiverId;
  late TextEditingController _amountController;
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SplitwiseProvider>();
    _payerId = widget.initialPayerId ?? provider.currentUser.id;
    _receiverId = widget.initialReceiverId ??
        (provider.friends.isNotEmpty ? provider.friends.first.id : '');
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toStringAsFixed(2)
          : '',
    );
    _selectedGroupId = widget.initialGroupId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final currency = provider.currency;
    final allUsers = provider.users;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Record a payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.charcoal,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Payer to Receiver selector
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _payerId,
                        isExpanded: true,
                        items: allUsers.map((u) {
                          return DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              u.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _payerId = val);
                        },
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: AppTheme.teal, size: 20),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _receiverId,
                        isExpanded: true,
                        items: allUsers.map((u) {
                          return DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              u.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _receiverId = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Amount input
            Center(
              child: SizedBox(
                width: 220,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.charcoal,
                  ),
                  decoration: InputDecoration(
                    prefixText: '$currency ',
                    prefixStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.teal,
                    ),
                    hintText: '0.00',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Group selector (optional)
            DropdownButtonFormField<String?>(
              initialValue: _selectedGroupId,
              decoration: InputDecoration(
                labelText: 'Group (Optional)',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No group (Direct settle)'),
                ),
                ...provider.groups.map((g) {
                  return DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedGroupId = val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
                if (amt <= 0.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }
                if (_payerId == _receiverId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payer and receiver cannot be the same user')),
                  );
                  return;
                }

                provider.settleUp(
                  fromUserId: _payerId,
                  toUserId: _receiverId,
                  amount: amt,
                  groupId: _selectedGroupId,
                );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment successfully recorded!')),
                );
              },
              child: const Text(
                'Save Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
