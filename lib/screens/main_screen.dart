import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/balance_banner.dart';
import '../widgets/notification_drawer.dart';
import 'add_expense_screen.dart';
import 'group_detail_screen.dart';
import 'friend_detail_screen.dart';
import 'search_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final unreadCount = provider.unreadNotificationCount;

    final pages = [
      _buildGroupsTab(context, provider),
      _buildFriendsTab(context, provider),
      _buildActivityTab(context, provider),
      _buildAccountTab(context, provider),
    ];

    return Scaffold(
      endDrawer: const NotificationDrawer(),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.teal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.call_split, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SplitIt',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search groups, friends, expenses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: _currentIndex == 0 ? 'Create Group' : 'Add Friend',
            onPressed: () {
              if (_currentIndex == 0) {
                _showCreateGroupDialog(context, provider);
              } else {
                _showAddFriendDialog(context, provider);
              }
            },
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
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppTheme.tealLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group, color: AppTheme.tealDark),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.tealDark),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppTheme.tealDark),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle, color: AppTheme.tealDark),
            label: 'Account',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teal,
        icon: const Icon(Icons.receipt_long, color: Colors.white),
        label: const Text(
          'Add Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()),
          );
        },
      ),
    );
  }

  // 1. GROUPS TAB
  Widget _buildGroupsTab(BuildContext context, SplitwiseProvider provider) {
    return ListView(
      children: [
        const BalanceBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR GROUPS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Group'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.teal),
                onPressed: () => _showCreateGroupDialog(context, provider),
              ),
            ],
          ),
        ),
        if (provider.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No groups yet. Tap + to create one!')),
          )
        else
          ...provider.groups.map((group) {
            final expenses = provider.getExpensesForGroup(group.id);
            final debts = provider.getGroupDebts(group.id);
            IconData icon = Icons.group_outlined;
            if (group.groupType == 'home') icon = Icons.home_outlined;
            if (group.groupType == 'trip') icon = Icons.flight_takeoff_outlined;
            if (group.groupType == 'couple') icon = Icons.favorite_border;

            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.tealLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.tealDark),
                ),
                title: Text(
                  group.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                subtitle: Text(
                  '${group.memberIds.length} members • ${expenses.length} expenses • ${debts.length} pending',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (group.simplifyByDefault)
                      const Tooltip(
                        message: 'Simplify Debts ON',
                        child: Icon(Icons.auto_fix_high, size: 16, color: AppTheme.teal),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
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
        const SizedBox(height: 80),
      ],
    );
  }

  // 2. FRIENDS TAB
  Widget _buildFriendsTab(BuildContext context, SplitwiseProvider provider) {
    final currency = provider.currency;
    return ListView(
      children: [
        const BalanceBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR FRIENDS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt, size: 16),
                label: const Text('Add Friend'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.teal),
                onPressed: () => _showAddFriendDialog(context, provider),
              ),
            ],
          ),
        ),
        if (provider.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No friends added yet.')),
          )
        else
          ...provider.friends.map((friend) {
            final balance = provider.getBalanceWithFriend(friend.id);
            final isOwed = balance > 0.01;
            final isSettled = balance.abs() <= 0.01;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSettled
                      ? Colors.grey.shade200
                      : (isOwed ? AppTheme.tealLight : const Color(0xFFFFECE5)),
                  foregroundColor: isSettled
                      ? AppTheme.charcoal
                      : (isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange),
                  child: Text(friend.name[0].toUpperCase()),
                ),
                title: Text(
                  friend.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                subtitle: Text(
                  friend.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSettled
                          ? 'settled up'
                          : (isOwed ? 'owes you' : 'you owe'),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isOwed ? AppTheme.positiveGreen : AppTheme.negativeOrange,
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => FriendDetailScreen(friendId: friend.id),
                    ),
                  );
                },
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  // 3. ACTIVITY TAB
  Widget _buildActivityTab(BuildContext context, SplitwiseProvider provider) {
    final activities = provider.activities;
    if (activities.isEmpty) {
      return const Center(child: Text('No recent activity'));
    }
    final dateFormat = DateFormat('MMM d, h:mm a');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: activities.length,
      itemBuilder: (ctx, idx) {
        final item = activities[idx];
        return Card(
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_outlined, color: AppTheme.tealDark),
            ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${item.subtitle} • ${dateFormat.format(item.timestamp)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        );
      },
    );
  }

  // 4. ACCOUNT TAB
  Widget _buildAccountTab(BuildContext context, SplitwiseProvider provider) {
    final user = provider.currentUser;
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    final memberSince = user.createdAt != null
        ? DateFormat('MMMM yyyy').format(user.createdAt!)
        : 'Active';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.teal,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : 'SplitIt Member',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since $memberSince',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Device Installed & Registered Users Directory
        Card(
          child: ListTile(
            leading: const Icon(Icons.devices, color: AppTheme.teal),
            title: const Text('Registered App Users'),
            subtitle: Text('${provider.users.length} device user(s) synced in Firestore'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAllUsersDialog(context, provider),
          ),
        ),

        // Currency Setting
        Card(
          child: ListTile(
            leading: const Icon(Icons.currency_exchange, color: AppTheme.teal),
            title: const Text('Default Currency'),
            trailing: DropdownButton<String>(
              value: provider.currency,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '₹', child: Text('INR (₹)')),
                DropdownMenuItem(value: '\$', child: Text('USD (\$)')),
                DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                DropdownMenuItem(value: '£', child: Text('GBP (£)')),
              ],
              onChanged: (val) {
                if (val != null) provider.setCurrency(val);
              },
            ),
          ),
        ),

        // Switch User (For testing multi-device perspective)
        if (provider.users.length > 1)
          Card(
            child: ListTile(
              leading: const Icon(Icons.switch_account_outlined, color: AppTheme.teal),
              title: const Text('Switch Active User'),
              subtitle: const Text('Preview app from another registered device/user'),
              trailing: DropdownButton<String>(
                value: provider.currentUser.id.isNotEmpty &&
                        provider.users.any((u) => u.id == provider.currentUser.id)
                    ? provider.currentUser.id
                    : null,
                underline: const SizedBox(),
                items: provider.users.map((u) {
                  return DropdownMenuItem(
                    value: u.id,
                    child: Text(u.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) provider.switchCurrentUser(val);
                },
              ),
            ),
          ),

        // Purge Testing Data Tool
        Card(
          child: ListTile(
            leading: const Icon(Icons.cleaning_services_outlined, color: AppTheme.negativeOrange),
            title: const Text('Clean Testing Data'),
            subtitle: const Text('Purge remnant demo records from Firestore'),
            trailing: TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.negativeOrange),
              onPressed: () => _showPurgeDataDialog(context, provider),
              child: const Text('Clean'),
            ),
          ),
        ),

        // Architecture Card
        Card(
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, color: AppTheme.teal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'SplitIt Engine (REA Reconstructed)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '• Real-time multi-device cloud synchronization\n'
                  '• Greedy Min-Cash-Flow Debt Simplifier algorithm\n'
                  '• Instant omni-search across friends, groups & expenses\n'
                  '• Safe group exit & member removal mechanism',
                  style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Log Out Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out of SplitIt', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () => _confirmLogout(context, provider),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showAllUsersDialog(BuildContext context, SplitwiseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.devices, color: AppTheme.teal),
            const SizedBox(width: 8),
            Text('Registered Users (${provider.users.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: provider.users.isEmpty
              ? const Text('No other users registered yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.users.length,
                  itemBuilder: (ctx, idx) {
                    final u = provider.users[idx];
                    final isMe = u.id == provider.currentUser.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMe ? AppTheme.teal : Colors.grey.shade200,
                        foregroundColor: isMe ? Colors.white : AppTheme.charcoal,
                        child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(u.name),
                      subtitle: Text(u.email),
                      trailing: isMe
                          ? const Chip(label: Text('You', style: TextStyle(fontSize: 11)))
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPurgeDataDialog(BuildContext context, SplitwiseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clean Testing Data?'),
        content: const Text(
          'This will purge any remnant legacy mock records (e.g. Rahul, Priya, Apartment 402, etc.) from Firestore so your app stays clean.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.negativeOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.purgeLegacyTestData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testing data purged successfully.')),
                );
              }
            },
            child: const Text('Purge Data'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, SplitwiseProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('Are you sure you want to log out of SplitIt?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, SplitwiseProvider provider) {
    final nameCtrl = TextEditingController();
    String groupType = 'trip';
    final selectedFriendIds = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create a Group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    hintText: 'e.g. Goa Trip, Flat 402',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: ['home', 'trip', 'couple', 'other'].map((type) {
                    final isSel = groupType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSel,
                      onSelected: (s) {
                        if (s) setDialogState(() => groupType = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Add Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ...provider.friends.map((friend) {
                  final checked = selectedFriendIds.contains(friend.id);
                  return CheckboxListTile(
                    dense: true,
                    title: Text(friend.name),
                    value: checked,
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          selectedFriendIds.add(friend.id);
                        } else {
                          selectedFriendIds.remove(friend.id);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal, foregroundColor: Colors.white),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                provider.createGroup(
                  name: name,
                  groupType: groupType,
                  memberIds: selectedFriendIds.toList(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, SplitwiseProvider provider) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a Friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Friend Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.teal, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              if (name.isEmpty) return;
              provider.addFriend(name: name, email: email.isEmpty ? '$name@example.com' : email);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
