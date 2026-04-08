import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<_NotifyItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uri = Uri.parse(
      '${AppApi.notifications}/',
    ).replace(queryParameters: {'username': AppSession.username});
    final res = await http.get(uri);
    if (!mounted) return;
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _NotifyItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = list;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _readAll() async {
    await http.post(
      Uri.parse('${AppApi.notifications}/read-all/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    _load();
  }

  Future<void> _markRead(_NotifyItem item) async {
    await http.post(
      Uri.parse('${AppApi.notifications}/${item.id}/read/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    setState(() => item.isRead = true);
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
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = _items[index];
                return ListTile(
                  leading: Icon(
                    item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                  ),
                  title: Text(item.content),
                  trailing: item.isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () => _markRead(item),
                );
              },
            ),
    );
  }
}

class _NotifyItem {
  _NotifyItem(this.id, this.content, this.isRead);

  final int id;
  final String content;
  bool isRead;

  factory _NotifyItem.fromJson(Map<String, dynamic> json) {
    return _NotifyItem(
      (json['id'] as num?)?.toInt() ?? 0,
      (json['content'] ?? '').toString(),
      json['is_read'] == true,
    );
  }
}
