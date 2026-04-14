import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.openConversationId,
    this.openPeerUsername,
  });

  final int? openConversationId;
  final String? openPeerUsername;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _searchController = TextEditingController();
  bool _loading = true;
  List<_Conversation> _conversations = [];
  final Set<int> _mutedConversationIds = <int>{};
  Timer? _timer;
  WebSocketChannel? _userChannel;
  StreamSubscription? _userSub;
  bool _openedInitialConversation = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadConversations(silent: true),
    );
    _connectUserSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_openedInitialConversation) return;
      _openedInitialConversation = true;
      if (widget.openPeerUsername != null &&
          widget.openPeerUsername!.isNotEmpty) {
        final conv = await _openConversation(widget.openPeerUsername!);
        if (conv != null && mounted) {
          _pushChat(conv);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _userSub?.cancel();
    _userChannel?.sink.close();
    super.dispose();
  }

  void _connectUserSocket() {
    _userChannel = WebSocketChannel.connect(
      Uri.parse('${AppApi.wsHost}/ws/notifications/${AppSession.username}/'),
    );
    _userSub = _userChannel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString();
          if (type == 'conversation_refresh' || type == 'notification') {
            _loadConversations(silent: true);
          }
        } catch (_) {}
      },
      onDone: () {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _connectUserSocket();
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final uri = Uri.parse('${AppApi.chat}/').replace(
      queryParameters: {
        'username': AppSession.username,
        if (_searchController.text.trim().isNotEmpty)
          'q': _searchController.text.trim(),
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _Conversation.fromJson(e as Map<String, dynamic>))
            .where((e) => !_mutedConversationIds.contains(e.id))
            .toList();

        setState(() {
          _conversations = list;
          _loading = false;
        });

        if (widget.openConversationId != null) {
          final matches = list.where((e) => e.id == widget.openConversationId);
          if (matches.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _pushChat(matches.first),
            );
          }
        }
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<List<_ProfileMini>> _fetchUsers([String q = '']) async {
    final uri = Uri.parse('${AppApi.users}/search/').replace(
      queryParameters: {
        'username': AppSession.username,
        if (q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['results'] as List<dynamic>? ?? [])
        .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<_Conversation?> _openConversation(String username) async {
    final res = await http.post(
      Uri.parse('${AppApi.chat}/open/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': AppSession.username,
        'peer_username': username,
      }),
    );
    if (res.statusCode == 201) {
      final conv = _Conversation.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      await _loadConversations(silent: true);
      return conv;
    }
    if (mounted) {
      final msg = _parseError(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Chỉ có thể nhắn với bạn bè' : msg),
        ),
      );
    }
    return null;
  }

  Future<void> _openConversationPrompt() async {
    final controller = TextEditingController();
    List<_ProfileMini> users = await _fetchUsers();

    if (!mounted) return;

    final picked = await showDialog<_ProfileMini>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nhắn tin mới'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  onChanged: (value) async {
                    users = await _fetchUsers(value);
                    if (context.mounted) setDialogState(() {});
                  },
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo mã SV hoặc tên',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: users.isEmpty
                      ? const Center(child: Text('Không tìm thấy sinh viên'))
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final u = users[i];
                            return ListTile(
                              dense: true,
                              leading: _avatarSmall(
                                avatarUrl: u.avatar,
                                fallbackText: u.fullName,
                              ),
                              title: Text(u.fullName),
                              subtitle: Text('${u.studentId} • ${u.username}'),
                              onTap: () => Navigator.pop(context, u),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked == null) return;
    final conv = await _openConversation(picked.username);
    if (conv != null && mounted) _pushChat(conv);
  }

  Future<void> _pushChat(_Conversation item) async {
    final result = await Navigator.push<_ChatActionResult>(
      context,
      MaterialPageRoute(builder: (_) => _ChatDetailScreen(conversation: item)),
    );

    if (!mounted) return;

    if (result?.action == 'delete') {
      setState(() {
        _conversations.removeWhere((e) => e.id == item.id);
      });
    } else if (result?.action == 'mute') {
      setState(() {
        _mutedConversationIds.add(item.id);
        _conversations.removeWhere((e) => e.id == item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tắt thông báo cuộc trò chuyện')),
      );
    } else {
      _loadConversations();
    }
  }

  String _conversationSubtitle(_Conversation item) {
    final q = _searchController.text.trim();
    final preview = q.isNotEmpty && item.matchedMessage.isNotEmpty
        ? item.matchedMessage
        : item.lastMessage;
    return '${item.peer.studentId} • $preview';
  }

  Future<void> _deleteConversation(_Conversation item) async {
    await http.delete(
      Uri.parse(
        '${AppApi.chat}/${item.id}/delete/',
      ).replace(queryParameters: {'username': AppSession.username}),
    );
    if (!mounted) return;
    setState(() => _conversations.removeWhere((e) => e.id == item.id));
  }

  void _muteConversation(_Conversation item) {
    setState(() {
      _mutedConversationIds.add(item.id);
      _conversations.removeWhere((e) => e.id == item.id);
    });
  }

  String _parseError(String raw) {
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      return (obj['detail'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  String _fmt(String value) {
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static Widget _avatarSmall({
    required String avatarUrl,
    required String fallbackText,
  }) {
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(avatarUrl));
    }
    return CircleAvatar(
      child: Text(
        _initials(fallbackText),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  static String _initials(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || text.trim().isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openConversationPrompt,
        child: const Icon(Icons.chat),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, mã SV hoặc nội dung tin nhắn',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadConversations,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => _loadConversations(silent: true),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _conversations.isEmpty
                ? const Center(child: Text('Chưa có cuộc trò chuyện nào'))
                : ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _conversations[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: _avatarSmall(
                          avatarUrl: item.peer.avatar,
                          fallbackText: item.peer.fullName,
                        ),
                        title: Text(
                          item.peer.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              _conversationSubtitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmt(item.lastMessageTime),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 86,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (item.unreadCount > 0)
                                CircleAvatar(
                                  radius: 11,
                                  child: Text(
                                    '${item.unreadCount}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteConversation(item);
                                  } else if (value == 'mute') {
                                    _muteConversation(item);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Xóa'),
                                  ),
                                  PopupMenuItem(
                                    value: 'mute',
                                    child: Text('Tắt thông báo'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _pushChat(item),
                        onLongPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                targetUsername: item.peer.username,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
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
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _showSearch = false;
  List<_ChatMessage> _messages = [];
  Timer? _pollTimer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _typingTimer;
  bool _peerTyping = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadMessages(silent: true);
    });
    _connectSocket();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _searchController.dispose();
    _wsSub?.cancel();
    _channel?.sink.close();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _connectSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppApi.wsHost}/ws/chat/${widget.conversation.id}/'),
    );
    _wsSub = _channel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString();
          if (type == 'message') {
            _loadMessages(silent: true);
          } else if (type == 'typing' &&
              (data['username'] ?? '') != AppSession.username) {
            setState(() => _peerTyping = true);
            _typingTimer?.cancel();
            _typingTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _peerTyping = false);
            });
          }
        } catch (_) {}
      },
      onDone: () {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _connectSocket();
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final uri = Uri.parse('${AppApi.chat}/${widget.conversation.id}/messages/')
        .replace(
          queryParameters: {
            'username': AppSession.username,
            if (_searchController.text.trim().isNotEmpty)
              'q': _searchController.text.trim(),
          },
        );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
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
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
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

  Future<void> _deleteConversationFromDetail() async {
    await http.delete(
      Uri.parse(
        '${AppApi.chat}/${widget.conversation.id}/delete/',
      ).replace(queryParameters: {'username': AppSession.username}),
    );
    if (!mounted) return;
    Navigator.pop(context, const _ChatActionResult(action: 'delete'));
  }

  void _muteConversationFromDetail() {
    if (!mounted) return;
    Navigator.pop(context, const _ChatActionResult(action: 'mute'));
  }

  void _sendTyping() {
    try {
      _channel?.sink.add(
        jsonEncode({'type': 'typing', 'username': AppSession.username}),
      );
    } catch (_) {}
  }

  String _fmt(String value) {
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $suffix';
  }

  bool _shouldShowAvatar(int index) {
    final msg = _messages[index];
    final mine = msg.sender == AppSession.username;
    if (mine) return false;
    if (index == _messages.length - 1) return true;
    final next = _messages[index + 1];
    return next.sender != msg.sender;
  }

  Widget _buildMessageBubble(_ChatMessage msg, bool mine) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF4E81FF) : const Color(0xFFD8E3F2),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(mine ? 12 : 4),
          bottomRight: Radius.circular(mine ? 4 : 12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            msg.content,
            style: TextStyle(
              color: mine ? Colors.white : const Color(0xFF1C1C1C),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmt(msg.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: mine ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(int index) {
    final msg = _messages[index];
    final mine = msg.sender == AppSession.username;

    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: _buildMessageBubble(msg, true),
      );
    }

    final showAvatar = _shouldShowAvatar(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 34,
            child: showAvatar
                ? CircleAvatar(
                    radius: 14,
                    backgroundImage: widget.conversation.peer.avatar.isNotEmpty
                        ? NetworkImage(widget.conversation.peer.avatar)
                        : null,
                    child: widget.conversation.peer.avatar.isEmpty
                        ? Text(
                            _MessagesScreenState._initials(
                              widget.conversation.peer.fullName,
                            ),
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Flexible(child: _buildMessageBubble(msg, false)),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'search') {
      setState(() {
        _showSearch = !_showSearch;
        if (!_showSearch) {
          _searchController.clear();
          _loadMessages(silent: true);
        }
      });
      return;
    }

    if (value == 'mute') {
      _muteConversationFromDetail();
      return;
    }

    if (value == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Xóa cuộc trò chuyện'),
          content: const Text(
            'Bạn có chắc muốn xóa toàn bộ cuộc trò chuyện này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _deleteConversationFromDetail();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.conversation.peer;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: peer.avatar.isNotEmpty
                  ? NetworkImage(peer.avatar)
                  : null,
              child: peer.avatar.isEmpty
                  ? Text(
                      _MessagesScreenState._initials(peer.fullName),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_peerTyping)
                    const Text(
                      'đang nhập...',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('Tìm kiếm nội dung')),
              PopupMenuItem(value: 'mute', child: Text('Tắt thông báo')),
              PopupMenuItem(value: 'delete', child: Text('Xóa tin nhắn')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _loadMessages(silent: true),
                decoration: InputDecoration(
                  hintText: 'Tìm trong cuộc trò chuyện',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _loadMessages(silent: true);
                    },
                    icon: const Icon(Icons.close),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              color: const Color(0xFFF7F7F7),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(child: Text('Chưa có tin nhắn nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) => _buildMessageRow(index),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Color(0x14000000),
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: (_) => _sendTyping(),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4E6A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
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
  _Conversation({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.matchedMessage,
    required this.unreadCount,
    required this.lastMessageTime,
  });

  final int id;
  final _ProfileMini peer;
  final String lastMessage;
  final String matchedMessage;
  final int unreadCount;
  final String lastMessageTime;

  factory _Conversation.fromJson(Map<String, dynamic> json) {
    return _Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      peer: _ProfileMini.fromJson(
        (json['peer_profile'] as Map<String, dynamic>? ?? {}),
      ),
      lastMessage: (json['last_message'] ?? '').toString(),
      matchedMessage: (json['matched_message'] ?? '').toString(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageTime: (json['last_message_time'] ?? json['updated_at'] ?? '')
          .toString(),
    );
  }
}

class _ProfileMini {
  _ProfileMini({
    required this.username,
    required this.fullName,
    required this.studentId,
    required this.avatar,
  });

  final String username;
  final String fullName;
  final String studentId;
  final String avatar;

  factory _ProfileMini.fromJson(Map<String, dynamic> json) {
    return _ProfileMini(
      username: (json['username'] ?? '').toString(),
      fullName: ((json['full_name'] ?? '').toString().isEmpty
          ? (json['username'] ?? '').toString()
          : (json['full_name'] ?? '').toString()),
      studentId: (json['student_id'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String content;
  final String createdAt;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: (json['sender_name'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class _ChatActionResult {
  const _ChatActionResult({required this.action});

  final String action;
}
