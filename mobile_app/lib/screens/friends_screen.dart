import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _loading = true;
  List<_RequestItem> _requests = [];
  List<String> _friends = [];
  final _suggestions = <String>[
    'hongnhung',
    'quanta',
    'ngannguyen',
    'baohoang',
    'quanbui',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inboxUri = Uri.parse(
      '${AppApi.users}/friends/requests/inbox/',
    ).replace(queryParameters: {'username': AppSession.username});
    final friendUri = Uri.parse(
      '${AppApi.users}/friends/',
    ).replace(queryParameters: {'username': AppSession.username});
    final inboxRes = await http.get(inboxUri);
    final friendRes = await http.get(friendUri);
    if (!mounted) return;
    if (inboxRes.statusCode == 200 && friendRes.statusCode == 200) {
      final reqList = (jsonDecode(inboxRes.body) as List<dynamic>)
          .map((e) => _RequestItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final friendsData =
          (jsonDecode(friendRes.body) as Map<String, dynamic>)['friends']
              as List<dynamic>? ??
          [];
      setState(() {
        _requests = reqList;
        _friends = friendsData.map((e) => e.toString()).toList();
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _decide(_RequestItem item, String action) async {
    await http.post(
      Uri.parse('${AppApi.users}/friends/requests/${item.id}/decide/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username, 'action': action}),
    );
    _load();
  }

  Future<void> _sendRequest(String targetUsername) async {
    if (targetUsername == AppSession.username) return;
    await http.post(
      Uri.parse('${AppApi.users}/friends/requests/send/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': AppSession.username,
        'to_username': targetUsername,
      }),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã gửi lời mời tới @$targetUsername')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Hồ sơ',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const Text(
                  'Lời mời kết bạn',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_requests.isEmpty) const Text('Không có lời mời mới'),
                ..._requests.map(
                  (item) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(item.fromUsername),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () => _decide(item, 'accept'),
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _decide(item, 'reject'),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Gợi ý kết bạn',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ..._suggestions.map(
                  (name) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text('@$name'),
                      trailing: ElevatedButton(
                        onPressed: _friends.contains(name)
                            ? null
                            : () => _sendRequest(name),
                        child: const Text('Kết bạn'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bạn bè (${_friends.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ..._friends.map(
                  (name) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(name),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RequestItem {
  _RequestItem({required this.id, required this.fromUsername});

  final int id;
  final String fromUsername;

  factory _RequestItem.fromJson(Map<String, dynamic> json) {
    return _RequestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fromUsername: (json['from_username'] ?? '').toString(),
    );
  }
}
