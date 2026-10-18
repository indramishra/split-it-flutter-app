import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? preselectedGroupId;
  final String? preselectedFriendId;

  const AddExpenseScreen({
    super.key,
    this.preselectedGroupId,
    this.preselectedFriendId,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController();
  String? _selectedGroupId;
  late String _paidByUserId;
  String _category = 'Food & Drink';
  bool _splitEqually = true;

  // Custom shares when not splitting equally: userId -> share amount
  final Map<String, TextEditingController> _customShareControllers = {};

  final List<String> _categories = [
    'Food & Drink',
    'Groceries',
    'Travel',
    'Rent',
    'Utilities',
    'Entertainment',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<SplitwiseProvider>();
    _selectedGroupId = widget.preselectedGroupId;
    _paidByUserId = provider.currentUser.id;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _costController.dispose();
    for (final c in _customShareControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _getInvolvedUserIds(SplitwiseProvider provider) {
    if (_selectedGroupId != null) {
      final grp = provider.getGroup(_selectedGroupId!);
      if (grp != null) return grp.memberIds;
    }
    if (widget.preselectedFriendId != null) {
      return [provider.currentUser.id, widget.preselectedFriendId!];
    }
    // Default: all friends + current user
    return provider.users.map((u) => u.id).toList();
  }

  void _syncCustomShareControllers(List<String> involvedIds, double totalCost) {
    if (involvedIds.isEmpty) return;
    final equalShare = involvedIds.isNotEmpty
        ? (totalCost / involvedIds.length).toStringAsFixed(2)
        : '0.00';

    for (final id in involvedIds) {
      if (!_customShareControllers.containsKey(id)) {
        _customShareControllers[id] = TextEditingController(text: equalShare);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final currency = provider.currency;
    final involvedIds = _getInvolvedUserIds(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add an expense'),
        actions: [
          TextButton(
            onPressed: _saveExpense,
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.teal,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Group Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedGroupId,
                  isExpanded: true,
                  hint: const Text('With you and: Select Group'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Personal / Non-group expense'),
                    ),
                    ...provider.groups.map((g) {
                      return DropdownMenuItem(
                        value: g.id,
                        child: Row(
                          children: [
                            const Icon(Icons.group, size: 18, color: AppTheme.teal),
                            const SizedBox(width: 8),
                            Text(g.name),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGroupId = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description and Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.tealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.teal, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _descriptionController,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Enter a description',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    currency,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.charcoal,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: UnderlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 0.0;
                      _syncCustomShareControllers(involvedIds, parsed);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category selector chip row
            const Text(
              'Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _category == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppTheme.tealLight,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.tealDark : AppTheme.textDark,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _category = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Paid by & Split logic
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Paid by',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      DropdownButton<String>(
                        value: _paidByUserId,
                        underline: const SizedBox(),
                        items: involvedIds.map((id) {
                          final user = provider.getUser(id);
                          return DropdownMenuItem(
                            value: id,
                            child: Text(
                              user?.name ?? id,
                              style: const TextStyle(
                                color: AppTheme.teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _paidByUserId = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Split method',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Equally'),
                            selected: _splitEqually,
                            onSelected: (s) {
                              setState(() => _splitEqually = true);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Exact amounts'),
                            selected: !_splitEqually,
                            onSelected: (s) {
                              final total = double.tryParse(_costController.text) ?? 0.0;
                              _syncCustomShareControllers(involvedIds, total);
                              setState(() => _splitEqually = false);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  // If exact amounts, list each participant's share input
                  if (!_splitEqually) ...[
                    const SizedBox(height: 16),
                    ...involvedIds.map((id) {
                      final u = provider.getUser(id);
                      final ctrl = _customShareControllers.putIfAbsent(
                        id,
                        () => TextEditingController(text: '0.00'),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                u?.name ?? id,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: ctrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  prefixText: '$currency ',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveExpense,
              child: const Text(
                'Save Expense',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveExpense() {
    final description = _descriptionController.text.trim();
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }
    if (cost <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense cost')),
      );
      return;
    }

    final provider = context.read<SplitwiseProvider>();
    final involvedIds = _getInvolvedUserIds(provider);

    final splitShares = <String, double>{};

    if (_splitEqually) {
      final share = double.parse((cost / involvedIds.length).toStringAsFixed(2));
      for (final id in involvedIds) {
        splitShares[id] = share;
      }
      // Reconcile rounding cent difference
      final totalAllocated = share * involvedIds.length;
      final diff = double.parse((cost - totalAllocated).toStringAsFixed(2));
      if (diff.abs() > 0.001) {
        splitShares[involvedIds.first] =
            double.parse((splitShares[involvedIds.first]! + diff).toStringAsFixed(2));
      }
    } else {
      double totalEntered = 0.0;
      for (final id in involvedIds) {
        final amt = double.tryParse(_customShareControllers[id]?.text ?? '0') ?? 0.0;
        splitShares[id] = amt;
        totalEntered += amt;
      }

      if ((totalEntered - cost).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'The sum of shares (${provider.currency}${totalEntered.toStringAsFixed(2)}) does not match the total expense (${provider.currency}${cost.toStringAsFixed(2)})',
            ),
          ),
        );
        return;
      }
    }

    provider.addExpense(
      groupId: _selectedGroupId,
      description: description,
      cost: cost,
      paidByUserId: _paidByUserId,
      splitShares: splitShares,
      category: _category,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mark_email_read, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added "$description"! Mail notifications sent to ${involvedIds.length} members.',
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.tealDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
