import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/community_screen.dart';
import 'package:mobile_app/screens/friends_screen.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<_NotifyItem> _items = [];
  final Set<String> _mutedTypes = <String>{};
  Timer? _timer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _load(silent: true),
    );
    _connectSocket();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppApi.wsHost}/ws/notifications/${AppSession.username}/'),
    );
    _wsSub = _channel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString();
          if (type == 'notification' ||
              type == 'notification_read' ||
              type == 'notification_deleted' ||
              type == 'notification_read_all') {
            _load(silent: true);
          }
        } catch (_) {}
      },
      onError: (_) {},
      onDone: () {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _connectSocket();
        });
      },
    );
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final uri = Uri.parse(
      '${AppApi.notifications}/',
    ).replace(queryParameters: {'username': AppSession.username});
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _NotifyItem.fromJson(e as Map<String, dynamic>))
            .where((e) => !_mutedTypes.contains(e.notificationType))
            .toList();
        setState(() {
          _items = list;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _readAll() async {
    await http.post(
      Uri.parse('${AppApi.notifications}/read-all/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    _load(silent: true);
  }

  Future<void> _markRead(_NotifyItem item) async {
    await http.post(
      Uri.parse('${AppApi.notifications}/${item.id}/read/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    item.isRead = true;
  }

  Future<void> _deleteNotification(_NotifyItem item) async {
    await http.delete(
      Uri.parse(
        '${AppApi.notifications}/${item.id}/delete/',
      ).replace(queryParameters: {'username': AppSession.username}),
    );
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
  }

  Future<void> _muteType(_NotifyItem item) async {
    setState(() {
      _mutedTypes.add(item.notificationType);
      _items.removeWhere((e) => e.notificationType == item.notificationType);
    });
  }

  Future<void> _openTarget(_NotifyItem item) async {
    await _markRead(item);
    if (!mounted) return;
    switch (item.notificationType) {
      case 'message':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessagesScreen(
              openConversationId: item.conversationId,
              openPeerUsername: item.targetUsername,
            ),
          ),
        );
        break;
      case 'friend_request':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 1)),
        );
        break;
      case 'friend_accept':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen(initialTab: 0)),
        );
        break;
      case 'post_like':
      case 'post_comment':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CommunityScreen()),
        );
        break;
      default:
        break;
    }
    setState(() {});
  }

  String _fmt(String value) {
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(onPressed: _readAll, child: const Text('Đọc hết')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = _items[index];
                return ListTile(
                  leading: Icon(
                    item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                  ),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.content),
                      const SizedBox(height: 4),
                      Text(
                        _fmt(item.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteNotification(item);
                          } else if (value == 'mute') {
                            _muteType(item);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          PopupMenuItem(
                            value: 'mute',
                            child: Text('Tắt thông báo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _openTarget(item),
                );
              },
            ),
    );
  }
}

class _NotifyItem {
  _NotifyItem({
    required this.id,
    required this.title,
    required this.content,
    required this.notificationType,
    required this.targetUsername,
    required this.isRead,
    required this.createdAt,
    this.conversationId,
  });

  final int id;
  final String title;
  final String content;
  final String notificationType;
  final String targetUsername;
  final String createdAt;
  final int? conversationId;
  bool isRead;

  factory _NotifyItem.fromJson(Map<String, dynamic> json) {
    return _NotifyItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      notificationType: (json['notification_type'] ?? 'system').toString(),
      targetUsername: (json['target_username'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      conversationId: (json['conversation_id'] as num?)?.toInt(),
      isRead: json['is_read'] == true,
    );
  }
}
