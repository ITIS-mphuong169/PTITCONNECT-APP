import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _loading = true;
  List<_Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final uri = Uri.parse(
      '${AppApi.chat}/',
    ).replace(queryParameters: {'username': AppSession.username});
    final res = await http.get(uri);
    if (!mounted) return;
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _conversations = list;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _openConversationPrompt() async {
    final controller = TextEditingController();
    final users = await _fetchUsers();
    if (!mounted) return;
    List<String> filtered = List.from(users);
    final username = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nhắn tin mới'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  onChanged: (value) {
                    final q = value.trim().toLowerCase();
                    setDialogState(() {
                      filtered = users
                          .where((u) => u.toLowerCase().contains(q))
                          .toList();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Tìm username có sẵn',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: filtered.isEmpty
                      ? const Center(child: Text('Không tìm thấy user'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            title: Text(filtered[i]),
                            onTap: () => Navigator.pop(context, filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim().toLowerCase()),
              child: const Text('Mở chat'),
            ),
          ],
        ),
      ),
    );
    if (username == null || username.isEmpty) return;
    final res = await http.post(
      Uri.parse('${AppApi.chat}/open/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': AppSession.username,
        'peer_username': username,
      }),
    );
    if (res.statusCode == 201) {
      await _loadConversations();
    } else {
      if (!mounted) return;
      final msg = _parseError(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'User không tồn tại' : msg)),
      );
    }
  }

  Future<List<String>> _fetchUsers() async {
    final uri = Uri.parse(
      '${AppApi.users}/search/',
    ).replace(queryParameters: {'username': AppSession.username});
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['results'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
  }

  String _parseError(String raw) {
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      return (obj['detail'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openConversationPrompt,
        child: const Icon(Icons.chat),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (_, index) {
                final item = _conversations[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(item.name),
                  subtitle: Text(item.messages.last),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ChatDetailScreen(conversation: item),
                      ),
                    );
                    _loadConversations();
                  },
                );
              },
            ),
    );
  }
}

class _ChatDetailScreen extends StatefulWidget {
  const _ChatDetailScreen({required this.conversation});

  final _Conversation conversation;

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  List<_ChatMessage> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    final uri = Uri.parse(
      '${AppApi.chat}/${widget.conversation.id}/messages/',
    ).replace(queryParameters: {'username': AppSession.username});
    final res = await http.get(uri);
    if (!mounted) return;
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _messages = list;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final res = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/messages/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username, 'content': text}),
    );
    if (res.statusCode == 201) {
      _controller.clear();
      _loadMessages(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation.name)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final msg = _messages[index];
                      final mine = msg.sender == AppSession.username;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFFF33B6D)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msg.content,
                            style: TextStyle(
                              color: mine ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Conversation {
  _Conversation({required this.id, required this.name, required this.messages});

  final int id;
  final String name;
  final List<String> messages;

  factory _Conversation.fromJson(Map<String, dynamic> json) {
    return _Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['peer_username'] ?? '').toString(),
      messages: [(json['last_message'] ?? '').toString()],
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.sender, required this.content});

  final String sender;
  final String content;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      sender: (json['sender_name'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
    );
  }
}
