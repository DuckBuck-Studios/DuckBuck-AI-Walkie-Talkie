import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';

/// Screen for displaying and managing friends
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with WidgetsBindingObserver {
  late final FirebaseAnalyticsService _analyticsService;
  bool _isLoading = true;
  List<FriendModel> _friendsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();
    _analyticsService.logScreenView(
      screenName: 'friends_screen',
      screenClass: 'FriendsScreen',
    );
    
    // Simulate loading friends data
    _loadFriends();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Get the appropriate icon based on platform
  Widget _getPlatformIcon(IconData materialIcon, IconData cupertinoIcon, {Color? color}) {
    final bool isIOS = Platform.isIOS;
    return Icon(
      isIOS ? cupertinoIcon : materialIcon,
      color: color,
      size: 20,
    );
  }

  // Simulate loading friends from a database
  Future<void> _loadFriends() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if the widget is still in the tree before updating state
    if (!mounted) return;
    
    // Demo data
    setState(() {
      _friendsList = [
        FriendModel(
          id: '1',
          name: 'Alex Johnson',
          avatarUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
          status: FriendStatus.online,
        ),
        FriendModel(
          id: '2',
          name: 'Taylor Swift',
          avatarUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
          status: FriendStatus.offline,
          lastActive: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        FriendModel(
          id: '3',
          name: 'Morgan Freeman',
          avatarUrl: 'https://randomuser.me/api/portraits/men/22.jpg',
          status: FriendStatus.online,
        ),
        FriendModel(
          id: '4',
          name: 'Emma Watson',
          avatarUrl: 'https://randomuser.me/api/portraits/women/66.jpg',
          status: FriendStatus.offline,
          lastActive: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildFriendsListView(),
    );
  }

  Widget _buildFriendsListView() {
    if (_friendsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _getPlatformIcon(
              Icons.people_outline,
              CupertinoIcons.person_2,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends to see them here',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _friendsList.length,
      itemBuilder: (context, index) {
        final friend = _friendsList[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(friend.avatarUrl),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: friend.status == FriendStatus.online
                          ? Colors.green
                          : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(friend.name),
            subtitle: Text(
              friend.status == FriendStatus.online
                  ? 'Online'
                  : 'Last seen ${_formatLastSeen(friend.lastActive)}',
            ),
            trailing: IconButton(
              icon: _getPlatformIcon(
                Icons.message_outlined,
                CupertinoIcons.chat_bubble,
                color: Colors.blue,
              ),
              onPressed: () {
                // Simulate message action
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Message ${friend.name}')),
                );
              },
            ),
            onTap: () {
              // Simulate friend profile view
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('View ${friend.name}\'s profile')),
              );
            },
          ),
        );
      },
    );
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'a while ago';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

enum FriendStatus { online, offline }

class FriendModel {
  final String id;
  final String name;
  final String avatarUrl;
  final FriendStatus status;
  final DateTime? lastActive;

  FriendModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.status,
    this.lastActive,
  });
}
