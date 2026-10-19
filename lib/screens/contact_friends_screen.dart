import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../providers/splitwise_provider.dart';
import '../theme/app_theme.dart';
import 'friend_detail_screen.dart';

class ContactFriendsScreen extends StatefulWidget {
  const ContactFriendsScreen({super.key});

  @override
  State<ContactFriendsScreen> createState() => _ContactFriendsScreenState();
}

class _ContactFriendsScreenState extends State<ContactFriendsScreen> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  String? _errorMessage;
  int _contactsCount = 0;
  List<User> _matchedFriends = [];
  final Set<String> _addingFriendIds = {};

  @override
  void initState() {
    super.initState();
    _scanContacts();
  }

  Future<void> _scanContacts() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
      _errorMessage = null;
    });

    final provider = context.read<SplitwiseProvider>();
    final result = await provider.searchContactFriends();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _permissionDenied = result.permissionDenied;
      _contactsCount = result.contactsCount;
      _matchedFriends = result.friends;
      _errorMessage = result.error;
    });
  }

  Future<void> _handleAddFriend(User targetUser) async {
    setState(() => _addingFriendIds.add(targetUser.id));
    final provider = context.read<SplitwiseProvider>();
    final err = await provider.addFriend(
      name: targetUser.name,
      email: targetUser.email,
    );

    if (mounted) {
      setState(() => _addingFriendIds.remove(targetUser.id));
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppTheme.negativeOrange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${targetUser.name} added as a friend!'),
            backgroundColor: AppTheme.teal,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final friendIds = provider.friends.map((f) => f.id).toSet();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Contacts on SplitIt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan contacts',
            onPressed: _isLoading ? null : _scanContacts,
          ),
        ],
      ),
      body: _buildBody(context, provider, friendIds),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SplitwiseProvider provider,
    Set<String> friendIds,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.teal),
            const SizedBox(height: 16),
            const Text(
              'Scanning your contacts...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Matching phone numbers and emails with SplitIt accounts',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.contacts_outlined,
                  size: 56,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Contacts Permission Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'To find which of your friends are already using SplitIt, please grant contact access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Allow Contacts Access'),
                onPressed: _scanContacts,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Device Settings'),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to read contacts: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _scanContacts,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_matchedFriends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.tealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  size: 54,
                  color: AppTheme.tealDark,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Registered Friends Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.charcoal,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Scanned $_contactsCount device contacts, but none currently have an account registered with their matching phone or email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Rescan Contacts'),
                onPressed: _scanContacts,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top summary banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.tealLight,
          child: Row(
            children: [
              const Icon(Icons.contact_phone_outlined,
                  color: AppTheme.tealDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Found ${_matchedFriends.length} friends on SplitIt from $_contactsCount contacts',
                  style: const TextStyle(
                    color: AppTheme.tealDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of found friends
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _matchedFriends.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = _matchedFriends[index];
              final isAlreadyFriend = friendIds.contains(user.id);
              final isAdding = _addingFriendIds.contains(user.id);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.teal,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (user.phoneNumber != null &&
                                user.phoneNumber!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.phone,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.phoneNumber!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isAlreadyFriend)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FriendDetailScreen(friendId: user.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Friends',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: isAdding
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add, size: 16),
                          label: const Text(
                            'Add Friend',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: isAdding
                              ? null
                              : () => _handleAddFriend(user),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
