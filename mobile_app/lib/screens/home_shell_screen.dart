import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/community_screen.dart';
import 'package:mobile_app/screens/feed_screen.dart';
import 'package:mobile_app/screens/friends_screen.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:mobile_app/screens/notifications_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _currentIndex = 0;
  int _messageBadge = 0;
  int _notificationBadge = 0;
  int _friendBadge = 0;
  Timer? _timer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  late final List<Widget> _tabs = const [
    FeedScreen(),
    CommunityScreen(),
    MessagesScreen(),
    NotificationsScreen(),
    FriendsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadBadges();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadBadges());
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppApi.wsHost}/ws/notifications/${AppSession.username}/'),
    );
    _wsSub = _channel!.stream.listen(
      (_) => _loadBadges(),
      onError: (_) {},
      onDone: () {},
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    final params = {'username': AppSession.username};
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${AppApi.chat}/').replace(queryParameters: params)),
        http.get(
          Uri.parse(
            '${AppApi.notifications}/',
          ).replace(queryParameters: params),
        ),
        http.get(
          Uri.parse(
            '${AppApi.users}/friends/requests/inbox/',
          ).replace(queryParameters: params),
        ),
      ]).timeout(const Duration(seconds: 8));
      final convs = (jsonDecode(results[0].body) as List<dynamic>?) ?? [];
      final notices = (jsonDecode(results[1].body) as List<dynamic>?) ?? [];
      final reqs = (jsonDecode(results[2].body) as List<dynamic>?) ?? [];
      final msgCount = convs.fold<int>(
        0,
        (sum, e) =>
            sum +
            (((e as Map<String, dynamic>)['unread_count'] as num?)?.toInt() ??
                0),
      );
      final noticeCount = notices
          .where((e) => (e as Map<String, dynamic>)['is_read'] != true)
          .length;
      if (!mounted) return;
      setState(() {
        _messageBadge = msgCount;
        _notificationBadge = noticeCount;
        _friendBadge = reqs.length;
      });
    } catch (_) {}
  }

  Widget _iconWithBadge(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Cộng đồng',
          ),
          NavigationDestination(
            icon: _iconWithBadge(Icons.chat_bubble_outline, _messageBadge),
            label: 'Tin nhắn',
          ),
          NavigationDestination(
            icon: _iconWithBadge(Icons.notifications_none, _notificationBadge),
            label: 'Thông báo',
          ),
          NavigationDestination(
            icon: _iconWithBadge(Icons.group_outlined, _friendBadge),
            label: 'Bạn bè',
          ),
        ],
      ),
    );
  }
}
