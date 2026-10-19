import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../models/expense.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';
import 'group_detail_screen.dart';
import 'friend_detail_screen.dart';
import 'contact_friends_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All'; // 'All', 'Groups', 'Friends', 'Expenses'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final query = _searchController.text.trim();

    final matchedGroups = query.isEmpty ? <Group>[] : provider.searchGroups(query);
    final matchedUsers = query.isEmpty ? <User>[] : provider.searchUsers(query);
    final matchedExpenses = query.isEmpty ? <Expense>[] : provider.searchExpenses(query);

    final totalResults = (_filter == 'All' || _filter == 'Groups' ? matchedGroups.length : 0) +
        (_filter == 'All' || _filter == 'Friends' ? matchedUsers.length : 0) +
        (_filter == 'All' || _filter == 'Expenses' ? matchedExpenses.length : 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search groups, friends, expenses...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Groups', 'Friends', 'Expenses'].map((f) {
                final isSelected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    selectedColor: AppTheme.tealLight,
                    checkmarkColor: AppTheme.tealDark,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.tealDark : AppTheme.charcoal,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _filter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Search Results
          Expanded(
            child: query.isEmpty
                ? _buildEmptyPrompt()
                : (totalResults == 0
                    ? _buildNoResults(query)
                    : _buildSearchResults(
                        context,
                        provider,
                        matchedGroups,
                        matchedUsers,
                        matchedExpenses,
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Search SplitIt',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find any group, friend, or past expense by name or amount',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.tealDark,
              side: const BorderSide(color: AppTheme.teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.contacts, size: 16),
            label: const Text('Find Friends from Contacts'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactFriendsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No results for "$query"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try checking for typos or searching a different term',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    SplitwiseProvider provider,
    List<Group> groups,
    List<User> users,
    List<Expense> expenses,
  ) {
    final currency = provider.currency;
    final showGroups = (_filter == 'All' || _filter == 'Groups') && groups.isNotEmpty;
    final showUsers = (_filter == 'All' || _filter == 'Friends') && users.isNotEmpty;
    final showExpenses = (_filter == 'All' || _filter == 'Expenses') && expenses.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // GROUPS SECTION
        if (showGroups) ...[
          _buildSectionHeader('GROUPS (${groups.length})'),
          ...groups.map((group) {
            final groupExpenses = provider.getExpensesForGroup(group.id);
            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.tealLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_outlined, color: AppTheme.tealDark),
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  '${group.memberIds.length} members • ${groupExpenses.length} expenses',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => GroupDetailScreen(groupId: group.id),
                    ),
                  );
                },
              ),
            );
          }),
        ],

        // FRIENDS & USERS SECTION
        if (showUsers) ...[
          _buildSectionHeader('FRIENDS & USERS (${users.length})'),
          ...users.map((user) {
            final balance = provider.getBalanceWithFriend(user.id);
            final isOwed = balance > 0.01;
            final isSettled = balance.abs() <= 0.01;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.tealLight,
                  foregroundColor: AppTheme.tealDark,
                  child: Text(user.name[0].toUpperCase()),
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSettled ? 'settled' : (isOwed ? 'owes you' : 'you owe'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSettled
                            ? Colors.grey
                            : (isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange),
                      ),
                    ),
                    if (!isSettled)
                      Text(
                        '$currency ${balance.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange,
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => FriendDetailScreen(friendId: user.id),
                    ),
                  );
                },
              ),
            );
          }),
        ],

        // EXPENSES SECTION
        if (showExpenses) ...[
          _buildSectionHeader('EXPENSES (${expenses.length})'),
          ...expenses.map((expense) {
            final payer = provider.getUser(expense.paidByUserId)?.name ?? 'Someone';
            final dateStr = DateFormat('MMM d, y').format(expense.date);
            final group = expense.groupId != null ? provider.getGroup(expense.groupId!) : null;

            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_outlined, color: AppTheme.charcoal),
                ),
                title: Text(
                  expense.description,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  'Paid by $payer ${group != null ? "in ${group.name}" : ""} • $dateStr',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                trailing: Text(
                  '$currency ${expense.cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
