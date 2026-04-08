import 'package:mobile_app/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/screens/feed_screen.dart';
import 'package:mobile_app/screens/friends_screen.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:mobile_app/screens/notifications_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;

  late final List<Widget> _tabs = const [
    FeedScreen(),
    CommunityScreen(),
    MessagesScreen(),
    NotificationsScreen(),
    FriendsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Cộng đồng',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Tin nhắn',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            label: 'Bạn bè',
          ),
        ],
      ),
    );
  }
}
