import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/avatar_utils.dart';
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
  Timer? _timer;
  WebSocketChannel? _userChannel;
  StreamSubscription? _userSub;
  bool _openedInitialConversation = false;
  bool _openedInitialConversationId = false;

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

    final query = _searchController.text.trim();
    final uri = Uri.parse('${AppApi.chat}/').replace(
      queryParameters: {
        'username': AppSession.username,
        if (query.isNotEmpty) 'q': query,
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _Conversation.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _conversations = list;
          _loading = false;
        });

        if (!_openedInitialConversationId && widget.openConversationId != null) {
          final matches = list.where((e) => e.id == widget.openConversationId);
          if (matches.isNotEmpty) {
            _openedInitialConversationId = true;
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
                              leading: _avatarSmall(fallbackText: u.fullName),
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

  Future<void> _pushChat(
    _Conversation item, {
    String initialSearchQuery = '',
  }) async {
    final result = await Navigator.push<_ChatActionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatDetailScreen(
          conversation: item,
          initialSearchQuery: initialSearchQuery,
        ),
      ),
    );

    if (!mounted) return;

    if (result?.action == 'delete') {
      setState(() {
        _conversations.removeWhere((e) => e.id == item.id);
      });
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

  bool _isPeerNameMatch(_Conversation item, String q) {
    if (q.isEmpty) return false;
    final s = q.toLowerCase();
    return item.peer.fullName.toLowerCase().contains(s) ||
        item.peer.studentId.toLowerCase().contains(s) ||
        item.peer.username.toLowerCase().contains(s);
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

  static Widget _avatarSmall({required String fallbackText}) {
    return initialsAvatar(fallbackText, radius: 20, fontSize: 12);
  }

  static String _initials(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || text.trim().isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Widget _buildSearchResults(String query) {
    final friendMatches = _conversations
        .where((e) => _isPeerNameMatch(e, query))
        .toList();
    final messageMatches = _conversations.where((e) => e.matchedCount > 0).toList();

    if (friendMatches.isEmpty && messageMatches.isEmpty) {
      return const Center(child: Text('Không tìm thấy kết quả phù hợp'));
    }

    return ListView(
      children: [
        if (friendMatches.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Text(
              'Bạn bè',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...friendMatches.map(
            (item) => ListTile(
              leading: _avatarSmall(fallbackText: item.peer.fullName),
              title: Text(item.peer.fullName),
              subtitle: Text(item.peer.studentId),
              onTap: () => _pushChat(item, initialSearchQuery: query),
            ),
          ),
          const Divider(height: 16),
        ],
        if (messageMatches.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              'Tin nhắn',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...messageMatches.map(
            (item) => ListTile(
              leading: _avatarSmall(fallbackText: item.peer.fullName),
              title: Text(item.peer.fullName),
              subtitle: Text(
                '${item.matchedCount} tin nhắn khớp',
                style: const TextStyle(color: Color(0xFF4E81FF)),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _pushChat(item, initialSearchQuery: query),
            ),
          ),
        ],
      ],
    );
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
                : _searchController.text.trim().isNotEmpty
                ? _buildSearchResults(_searchController.text.trim())
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
                        leading: _avatarSmall(fallbackText: item.peer.fullName),
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
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Xóa'),
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
  const _ChatDetailScreen({
    required this.conversation,
    this.initialSearchQuery = '',
  });

  final _Conversation conversation;
  final String initialSearchQuery;

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  bool _loading = true;
  bool _showSearch = false;
  List<_ChatMessage> _messages = [];
  final List<int> _searchMatchIndexes = [];
  int _activeSearchMatchPointer = -1;
  final Map<int, GlobalKey> _messageRowKeys = {};
  Timer? _pollTimer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _typingTimer;
  bool _peerTyping = false;
  bool _isNearBottom = true;
  bool _showJumpToLatest = false;
  int? _lastMessageId;
  bool _forceScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery.trim().isNotEmpty) {
      _showSearch = true;
      _searchController.text = widget.initialSearchQuery.trim();
    }
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadMessages(silent: true);
    });
    _connectSocket();
    _messagesScrollController.addListener(_onMessagesScroll);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _searchController.dispose();
    _messagesScrollController.dispose();
    _wsSub?.cancel();
    _channel?.sink.close();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onMessagesScroll() {
    if (!_messagesScrollController.hasClients) return;
    final pos = _messagesScrollController.position;
    final nearBottom = (pos.maxScrollExtent - pos.pixels) < 80;
    if (_isNearBottom != nearBottom) {
      _isNearBottom = nearBottom;
      if (nearBottom && _showJumpToLatest && mounted) {
        setState(() => _showJumpToLatest = false);
      }
    }
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    if (!_messagesScrollController.hasClients) return;
    final target = _messagesScrollController.position.maxScrollExtent;
    final current = _messagesScrollController.position.pixels;
    final distance = (target - current).abs();
    if (distance < 6) return;
    if (animated) {
      final durationMs = distance.clamp(140, 420).toInt();
      await _messagesScrollController.animateTo(
        target,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _messagesScrollController.jumpTo(target);
    }
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
          },
        );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final previousLastId = _lastMessageId;
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        final nextLastId = list.isNotEmpty ? list.last.id : null;
        final hasNewIncoming = previousLastId != null &&
            nextLastId != null &&
            nextLastId != previousLastId;
        setState(() {
          _messages = list;
          _lastMessageId = nextLastId;
          _messageRowKeys.clear();
          _recomputeSearchMatches();
          _loading = false;
        });
        if (_searchController.text.trim().isNotEmpty &&
            _searchMatchIndexes.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _jumpSearchMatch(0);
          });
        } else {
          final shouldAutoScroll = _forceScrollToBottom ||
              previousLastId == null ||
              (_isNearBottom && hasNewIncoming);
          if (shouldAutoScroll) {
            _forceScrollToBottom = false;
            if (_showJumpToLatest && mounted) {
              setState(() => _showJumpToLatest = false);
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          } else if (hasNewIncoming && mounted) {
            setState(() => _showJumpToLatest = true);
          }
        }
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _recomputeSearchMatches() {
    final q = _searchController.text.trim().toLowerCase();
    _searchMatchIndexes.clear();
    if (q.isEmpty) {
      _activeSearchMatchPointer = -1;
      return;
    }
    for (var i = 0; i < _messages.length; i++) {
      if (_messages[i].content.toLowerCase().contains(q)) {
        _searchMatchIndexes.add(i);
      }
    }
    if (_searchMatchIndexes.isEmpty) {
      _activeSearchMatchPointer = -1;
      return;
    }
    if (_activeSearchMatchPointer < 0 ||
        _activeSearchMatchPointer >= _searchMatchIndexes.length) {
      _activeSearchMatchPointer = 0;
    }
  }

  Future<void> _jumpSearchMatch(int delta) async {
    if (_searchMatchIndexes.isEmpty) return;
    setState(() {
      _activeSearchMatchPointer =
          (_activeSearchMatchPointer + delta) % _searchMatchIndexes.length;
      if (_activeSearchMatchPointer < 0) {
        _activeSearchMatchPointer = _searchMatchIndexes.length - 1;
      }
    });

    final messageIndex = _searchMatchIndexes[_activeSearchMatchPointer];
    final key = _messageRowKeys[messageIndex];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        alignment: 0.35,
      );
      return;
    }
    if (_messagesScrollController.hasClients && _messages.length > 1) {
      final ratio = messageIndex / (_messages.length - 1);
      final roughOffset =
          _messagesScrollController.position.maxScrollExtent * ratio;
      await _messagesScrollController.animateTo(
        roughOffset.clamp(
          0,
          _messagesScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
      );
    }
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
      _forceScrollToBottom = true;
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

  List<TextSpan> _buildMessageSpans(
    String content,
    bool mine,
    bool isActiveMatch,
  ) {
    final query = _searchController.text.trim();
    final baseStyle = TextStyle(
      color: mine ? Colors.white : const Color(0xFF1C1C1C),
      fontSize: 15,
    );
    if (query.isEmpty) {
      return [TextSpan(text: content, style: baseStyle)];
    }

    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lowerContent.indexOf(lowerQuery, start);
      if (idx < 0) {
        if (start < content.length) {
          spans.add(TextSpan(text: content.substring(start), style: baseStyle));
        }
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: content.substring(start, idx), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: content.substring(idx, idx + query.length),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w800,
            backgroundColor: isActiveMatch
                ? const Color(0xFFFFD54F)
                : const Color(0x66FFF59D),
            color: mine ? const Color(0xFF0D1B2A) : const Color(0xFF0D1B2A),
          ),
        ),
      );
      start = idx + query.length;
    }
    return spans;
  }

  Widget _buildMessageBubble(_ChatMessage msg, bool mine, {required int index}) {
    final isActiveMatch = _searchMatchIndexes.isNotEmpty &&
        _activeSearchMatchPointer >= 0 &&
        _activeSearchMatchPointer < _searchMatchIndexes.length &&
        _searchMatchIndexes[_activeSearchMatchPointer] == index;
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
          RichText(
            text: TextSpan(
              children: _buildMessageSpans(msg.content, mine, isActiveMatch),
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
        child: _buildMessageBubble(msg, true, index: index),
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
                    backgroundColor: const Color(0xFFF8D5E0),
                    child: Text(
                      _MessagesScreenState._initials(
                        widget.conversation.peer.fullName,
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Flexible(child: _buildMessageBubble(msg, false, index: index)),
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
          _recomputeSearchMatches();
          _loadMessages(silent: true);
        }
      });
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
            initialsAvatar(peer.fullName, radius: 18, fontSize: 12),
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
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {
                        _recomputeSearchMatches();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Tìm trong cuộc trò chuyện',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _recomputeSearchMatches();
                          _loadMessages(silent: true);
                        },
                        icon: const Icon(Icons.close),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _searchMatchIndexes.isEmpty
                            ? '0 kết quả'
                            : '${_activeSearchMatchPointer + 1}/${_searchMatchIndexes.length} kết quả',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _searchMatchIndexes.isEmpty
                            ? null
                            : () => _jumpSearchMatch(-1),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        onPressed: _searchMatchIndexes.isEmpty
                            ? null
                            : () => _jumpSearchMatch(1),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                ],
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
                      controller: _messagesScrollController,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        final key = _messageRowKeys.putIfAbsent(
                          index,
                          () => GlobalKey(),
                        );
                        return KeyedSubtree(
                          key: key,
                          child: _buildMessageRow(index),
                        );
                      },
                    ),
            ),
          ),
          if (_showJumpToLatest)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OutlinedButton.icon(
                onPressed: () {
                  _forceScrollToBottom = true;
                  setState(() => _showJumpToLatest = false);
                  _scrollToBottom();
                },
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: const Text('Tin nhắn mới'),
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
    required this.matchedCount,
    required this.unreadCount,
    required this.lastMessageTime,
  });

  final int id;
  final _ProfileMini peer;
  final String lastMessage;
  final String matchedMessage;
  final int matchedCount;
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
      matchedCount: (json['matched_count'] as num?)?.toInt() ?? 0,
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
