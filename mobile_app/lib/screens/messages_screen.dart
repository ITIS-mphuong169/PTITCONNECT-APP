import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/screens/create_group_chat_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:mobile_app/screens/video_call_screen.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
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
      Uri.parse(AppApi.wsNotifications(AppSession.username)),
    );

    _userSub = _userChannel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString();
          if (type == 'conversation_refresh' ||
              type == 'notification' ||
              type == 'call_status') {
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
    final uri = Uri.parse(
      '${AppApi.chat}/',
    ).replace(queryParameters: {if (query.isNotEmpty) 'q': query});

    try {
      final res = await http
          .get(uri, headers: AppSession.authHeaders())
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _Conversation.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _conversations = list;
          _loading = false;
        });

        if (!_openedInitialConversationId &&
            widget.openConversationId != null) {
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
    final uri = Uri.parse(
      '${AppApi.users}/search/',
    ).replace(queryParameters: {if (q.trim().isNotEmpty) 'q': q.trim()});

    final res = await http
        .get(uri, headers: AppSession.authHeaders())
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['results'] as List<dynamic>? ?? [])
        .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<_Conversation?> _openConversation(String username) async {
    final res = await http.post(
      Uri.parse('${AppApi.chat}/open/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'peer_username': username}),
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

  Future<void> _showNewMessageActions() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Tin nhắn mới'),
              onTap: () {
                Navigator.pop(context);
                _openConversationPrompt();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Nhóm chat'),
              onTap: () async {
                Navigator.pop(context);

                final created = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupChatScreen(),
                  ),
                );

                if (created == null || !mounted) return;

                final conv = _Conversation.fromJson(created);
                await _loadConversations(silent: true);

                if (!mounted) return;
                _pushChat(conv);
              },
            ),
          ],
        ),
      ),
    );
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

    if (result?.action == 'delete' || result?.action == 'removed') {
      setState(() {
        _conversations.removeWhere((e) => e.id == item.id);
      });
    } else {
      _loadConversations();
    }
  }

  String _conversationSubtitle(_Conversation item) {
    final preview = item.lastMessage;

    if (item.isGroup) {
      return '${item.memberCount} thành viên • $preview';
    }

    final member = item.firstMemberOrNull;
    if (member == null) return preview;
    return '${member.studentId} • $preview';
  }

  Future<void> _deleteConversation(_Conversation item) async {
    await http.delete(
      Uri.parse('${AppApi.chat}/${item.id}/delete/'),
      headers: AppSession.authHeaders(),
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

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();

    final filtered = q.isEmpty
        ? _conversations
        : _conversations.where((e) {
            return e.displayName.toLowerCase().contains(q) ||
                e.lastMessage.toLowerCase().contains(q) ||
                e.memberProfiles.any(
                  (m) =>
                      m.fullName.toLowerCase().contains(q) ||
                      m.studentId.toLowerCase().contains(q) ||
                      m.username.toLowerCase().contains(q),
                );
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageActions,
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
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? const Center(child: Text('Chưa có cuộc trò chuyện nào'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            item.isGroup ? Icons.group : Icons.person,
                          ),
                        ),
                        title: Text(
                          item.displayName,
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
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    '${item.unreadCount}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteConversation(item);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (!item.isGroup)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Xóa'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _pushChat(item),
                        onLongPress: item.isGroup
                            ? null
                            : () {
                                final peer = item.firstMemberOrNull;
                                if (peer == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                      targetUsername: peer.username,
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
  bool _peerTyping = false;
  bool _sending = false;

  List<_ChatMessage> _messages = [];
  List<_Member> _members = [];
  List<_CallLog> _callLogs = [];

  Timer? _pollTimer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _typingTimer;

  Uint8List? _pendingImageBytes;
  PlatformFile? _pendingFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery.trim().isNotEmpty) {
      _showSearch = true;
      _searchController.text = widget.initialSearchQuery.trim();
    }
    _loadMessages();
    _loadCallHistory();
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
    _messagesScrollController.dispose();
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
            _loadCallHistory();
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

    final uri = Uri.parse('${AppApi.chat}/${widget.conversation.id}/messages/');

    try {
      final res = await http
          .get(uri, headers: AppSession.authHeaders())
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _messages = list;
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_messagesScrollController.hasClients) {
            _messagesScrollController.jumpTo(
              _messagesScrollController.position.maxScrollExtent,
            );
          }
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCallHistory() async {
    try {
      final res = await http.get(
        Uri.parse('${AppApi.chat}/${widget.conversation.id}/call-logs/'),
        headers: AppSession.authHeaders(),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List<dynamic>)
            .map((e) => _CallLog.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _callLogs = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      final res = await http.post(
        Uri.parse('${AppApi.chat}/${widget.conversation.id}/messages/'),
        headers: AppSession.authHeaders(
          extra: const {'Content-Type': 'application/json'},
        ),
        body: jsonEncode({'content': text, 'message_type': 'text'}),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        setState(() {
          _controller.clear();
        });
        _loadMessages(silent: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_pendingImageBytes == null) return;

    setState(() => _sending = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppApi.chat}/${widget.conversation.id}/messages/'),
      );

      request.headers.addAll(AppSession.authHeaders());
      request.fields['content'] = _controller.text.trim();
      request.fields['message_type'] = 'image';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _pendingImageBytes!,
          filename: 'image.jpg',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() {
          _controller.clear();
          _pendingImageBytes = null;
        });
        _loadMessages(silent: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendFile() async {
    if (_pendingFile == null || _pendingFile!.bytes == null) return;

    setState(() => _sending = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppApi.chat}/${widget.conversation.id}/messages/'),
      );

      request.headers.addAll(AppSession.authHeaders());
      request.fields['content'] = _controller.text.trim();
      request.fields['message_type'] = 'file';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _pendingFile!.bytes!,
          filename: _pendingFile!.name,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() {
          _controller.clear();
          _pendingFile = null;
        });
        _loadMessages(silent: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    if (_pendingImageBytes != null) {
      return _sendImage();
    }
    if (_pendingFile != null) {
      return _sendFile();
    }
    return _sendText();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _pendingFile = result.files.first;
      _pendingImageBytes = null;
    });
  }

  Future<void> _pickAndAttachImage(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera trên web có thể không hoạt động ổn định. Hãy thử trên Android/iPhone.',
          ),
        ),
      );
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, imageQuality: 72);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pendingImageBytes = bytes;
        _pendingFile = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Không thể mở camera trên môi trường hiện tại'
                : 'Không thể chọn ảnh',
          ),
        ),
      );
    }
  }

  void _sendTyping() {
    try {
      _channel?.sink.add(
        jsonEncode({'type': 'typing', 'username': AppSession.username}),
      );
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    final res = await http.get(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/members/'),
      headers: AppSession.authHeaders(),
    );

    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _Member.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() => _members = list);
      }
    }
  }

  Future<void> _showMembers() async {
    await _loadMembers();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: _members.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(child: Text('Chưa có thành viên')),
              )
            : ListView(
                shrinkWrap: true,
                children: _members.map((m) {
                  return ListTile(
                    leading: initialsAvatar(
                      m.fullName,
                      radius: 18,
                      fontSize: 11,
                    ),
                    title: Text(m.fullName),
                    subtitle: Text('${m.role} • ${m.status}'),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Future<void> _showCallHistory() async {
    await _loadCallHistory();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: _callLogs.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(child: Text('Chưa có lịch sử cuộc gọi')),
              )
            : ListView(
                shrinkWrap: true,
                children: _callLogs.map((c) {
                  final icon = c.callType == 'video'
                      ? Icons.videocam_outlined
                      : Icons.call_outlined;
                  return ListTile(
                    leading: Icon(icon),
                    title: Text(c.statusLabel),
                    subtitle: Text(_fmt(c.startedAt)),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Future<void> _addMembers() async {
    final res = await http
        .get(Uri.parse('${AppApi.friends}/'), headers: AppSession.authHeaders())
        .timeout(const Duration(seconds: 8));

    if (!mounted || res.statusCode != 200) return;

    final dynamic data = jsonDecode(res.body);
    final list = (data is List
        ? data
        : (data['friends'] as List<dynamic>? ??
              data['results'] as List<dynamic>? ??
              <dynamic>[]));

    final users = list
        .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
        .toList();

    final selected = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm thành viên'),
          content: SizedBox(
            width: 420,
            height: 320,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                final checked = selected.contains(u.username);
                return CheckboxListTile(
                  value: checked,
                  title: Text(u.fullName),
                  subtitle: Text('${u.studentId} • ${u.username}'),
                  onChanged: (_) {
                    setDialogState(() {
                      if (checked) {
                        selected.remove(u.username);
                      } else {
                        selected.add(u.username);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected.isEmpty) return;

    final addRes = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/members/add/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'usernames': selected.toList()}),
    );

    if (!mounted) return;

    if (addRes.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã thêm thành viên')));
      _loadMembers();
    } else {
      final msg = _parseError(addRes.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Không thể thêm thành viên' : msg),
        ),
      );
    }
  }

  Future<void> _toggleApproval() async {
    final res = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/approval-setting/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'enabled': !widget.conversation.requireApprovalToJoin}),
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật chế độ duyệt thành viên')),
      );
      Navigator.pop(context, const _ChatActionResult(action: 'refresh'));
    }
  }

  Future<void> _transferOwner() async {
    await _loadMembers();
    final candidates = _members
        .where((m) => m.username != AppSession.username && m.status == 'active')
        .toList();

    if (!mounted || candidates.isEmpty) return;

    final picked = await showDialog<_Member>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chuyển quyền trưởng nhóm'),
        children: candidates
            .map(
              (m) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, m),
                child: Text(m.fullName),
              ),
            )
            .toList(),
      ),
    );

    if (picked == null) return;

    final res = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/transfer-owner/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'username': picked.username}),
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã chuyển quyền trưởng nhóm')),
      );
      Navigator.pop(context, const _ChatActionResult(action: 'refresh'));
    } else {
      final msg = _parseError(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Không thể chuyển quyền' : msg)),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final res = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/leave/'),
      headers: AppSession.authHeaders(),
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      Navigator.pop(context, const _ChatActionResult(action: 'removed'));
    } else {
      final msg = _parseError(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Không thể rời nhóm' : msg)),
      );
    }
  }

  Future<void> _dissolveGroup() async {
    final res = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/dissolve/'),
      headers: AppSession.authHeaders(),
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      Navigator.pop(context, const _ChatActionResult(action: 'removed'));
    } else {
      final msg = _parseError(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isEmpty ? 'Không thể giải tán nhóm' : msg)),
      );
    }
  }

  Future<void> _startCall(String callType) async {
    final res = await http.post(
      Uri.parse('${AppApi.chat}/${widget.conversation.id}/call/invite/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'call_type': callType}),
    );

    if (!mounted) return;

    if (res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final callLogId = (body['id'] as num?)?.toInt() ?? 0;

      final title = widget.conversation.displayName;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            conversationId: widget.conversation.id,
            callLogId: callLogId,
            callType: callType,
            title: title,
            isCaller: true,
          ),
        ),
      );
    } else {
      final msg = _parseError(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Không thể bắt đầu cuộc gọi' : msg),
        ),
      );
    }
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
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final suffix = dt.hour >= 12 ? 'pm' : 'am';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $suffix';
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'search', child: Text('Tìm tin nhắn')),
      if (widget.conversation.isGroup)
        const PopupMenuItem(value: 'members', child: Text('Xem thành viên')),
      const PopupMenuItem(
        value: 'call_history',
        child: Text('Lịch sử cuộc gọi'),
      ),
    ];

    if (widget.conversation.isGroup &&
        (widget.conversation.myRole == 'owner' ||
            widget.conversation.myRole == 'admin')) {
      items.add(
        const PopupMenuItem(
          value: 'add_members',
          child: Text('Thêm thành viên'),
        ),
      );
      items.add(
        PopupMenuItem(
          value: 'toggle_approval',
          child: Text(
            widget.conversation.requireApprovalToJoin
                ? 'Tắt duyệt thành viên'
                : 'Bật duyệt thành viên',
          ),
        ),
      );
    }

    if (widget.conversation.isGroup && widget.conversation.myRole == 'owner') {
      items.add(
        const PopupMenuItem(
          value: 'transfer_owner',
          child: Text('Chuyển quyền trưởng nhóm'),
        ),
      );
      items.add(
        const PopupMenuItem(value: 'dissolve', child: Text('Giải tán nhóm')),
      );
    }

    if (widget.conversation.isGroup) {
      items.add(const PopupMenuItem(value: 'leave', child: Text('Rời nhóm')));
    }

    return items;
  }

  Future<void> _handleMenuAction(String value) async {
    switch (value) {
      case 'search':
        setState(() {
          _showSearch = !_showSearch;
          if (!_showSearch) {
            _searchController.clear();
          }
        });
        break;
      case 'members':
        await _showMembers();
        break;
      case 'add_members':
        await _addMembers();
        break;
      case 'toggle_approval':
        await _toggleApproval();
        break;
      case 'transfer_owner':
        await _transferOwner();
        break;
      case 'leave':
        await _leaveGroup();
        break;
      case 'dissolve':
        await _dissolveGroup();
        break;
      case 'call_history':
        await _showCallHistory();
        break;
    }
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final mine = msg.sender == AppSession.username;

    Widget inner;
    if (msg.messageType == 'image' && msg.fileUrl.isNotEmpty) {
      inner = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(msg.fileUrl, fit: BoxFit.cover),
          ),
          if (msg.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              msg.content,
              style: TextStyle(
                color: mine ? Colors.white : const Color(0xFF1C1C1C),
              ),
            ),
          ],
        ],
      );
    } else if (msg.messageType == 'file') {
      inner = GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(msg.fileUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.fileName.isEmpty ? 'Tệp đính kèm' : msg.fileName,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
            if (msg.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                msg.content,
                style: TextStyle(
                  color: mine ? Colors.white : const Color(0xFF1C1C1C),
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      inner = Text(
        msg.content,
        style: TextStyle(color: mine ? Colors.white : const Color(0xFF1C1C1C)),
      );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : const Color(0xFFFFF2F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && widget.conversation.isGroup)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.sender,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            inner,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();

    final shownMessages = _showSearch && q.isNotEmpty
        ? _messages.where((m) {
            return m.content.toLowerCase().contains(q) ||
                m.fileName.toLowerCase().contains(q);
          }).toList()
        : _messages;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              child: Icon(
                widget.conversation.isGroup ? Icons.group : Icons.person,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_peerTyping)
                    const Text(
                      'đang nhập...',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryDark,
                      ),
                    )
                  else if (widget.conversation.isGroup)
                    Text(
                      '${widget.conversation.memberCount} thành viên • Vai trò: ${widget.conversation.myRole}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _startCall('audio'),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            onPressed: () => _startCall('video'),
            icon: const Icon(Icons.videocam_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (_) => _buildMenuItems(),
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
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm trong cuộc trò chuyện',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : shownMessages.isEmpty
                ? const Center(child: Text('Chưa có tin nhắn nào'))
                : ListView.builder(
                    controller: _messagesScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    itemCount: shownMessages.length,
                    itemBuilder: (_, index) {
                      return _buildMessageBubble(shownMessages[index]);
                    },
                  ),
          ),
          if (_pendingImageBytes != null || _pendingFile != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF8F8F8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pendingFile != null
                          ? 'Đã chọn file: ${_pendingFile!.name}'
                          : 'Đã chọn 1 ảnh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _pendingImageBytes = null;
                        _pendingFile = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
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
                    onPressed: _pickFile,
                    icon: const Icon(Icons.description_outlined),
                  ),
                  IconButton(
                    onPressed: () => _pickAndAttachImage(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    onPressed: () => _pickAndAttachImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
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
                        fillColor: const Color(0xFFFFF2F6),
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
                      onPressed: _sending ? null : _send,
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
    required this.isGroup,
    required this.displayName,
    required this.lastMessage,
    required this.unreadCount,
    required this.lastMessageTime,
    required this.memberCount,
    required this.memberProfiles,
    required this.myRole,
    required this.ownerUsername,
    required this.requireApprovalToJoin,
  });

  final int id;
  final bool isGroup;
  final String displayName;
  final String lastMessage;
  final int unreadCount;
  final String lastMessageTime;
  final int memberCount;
  final List<_ProfileMini> memberProfiles;
  final String myRole;
  final String ownerUsername;
  final bool requireApprovalToJoin;

  factory _Conversation.fromJson(Map<String, dynamic> json) {
    final members = (json['member_profiles'] as List<dynamic>? ?? [])
        .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
        .toList();

    return _Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      isGroup: json['is_group'] == true,
      displayName: (json['display_name'] ?? '').toString(),
      lastMessage: (json['last_message'] ?? '').toString(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageTime: (json['last_message_time'] ?? json['updated_at'] ?? '')
          .toString(),
      memberCount:
          (json['participant_count'] as num?)?.toInt() ?? members.length,
      memberProfiles: members,
      myRole: (json['my_role'] ?? 'member').toString(),
      ownerUsername: (json['owner_username'] ?? '').toString(),
      requireApprovalToJoin: json['require_approval_to_join'] == true,
    );
  }

  _ProfileMini? get firstMemberOrNull {
    if (memberProfiles.isEmpty) return null;
    return memberProfiles.first;
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
      avatar: (json['avatar'] ?? json['avatar_url'] ?? '').toString(),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.id,
    required this.sender,
    required this.messageType,
    required this.content,
    required this.fileName,
    required this.fileUrl,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String messageType;
  final String content;
  final String fileName;
  final String fileUrl;
  final String createdAt;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sender: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      content: (json['content'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      fileUrl: (json['file_url'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class _Member {
  _Member({
    required this.username,
    required this.fullName,
    required this.role,
    required this.status,
  });

  final String username;
  final String fullName;
  final String role;
  final String status;

  factory _Member.fromJson(Map<String, dynamic> json) {
    final profile = (json['profile'] as Map<String, dynamic>? ?? {});
    return _Member(
      username: (profile['username'] ?? '').toString(),
      fullName: ((profile['full_name'] ?? '').toString().isEmpty
          ? (profile['username'] ?? '').toString()
          : (profile['full_name'] ?? '').toString()),
      role: (json['role'] ?? 'member').toString(),
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

class _CallLog {
  _CallLog({
    required this.id,
    required this.callType,
    required this.status,
    required this.startedAt,
  });

  final int id;
  final String callType;
  final String status;
  final String startedAt;

  String get statusLabel {
    final prefix = callType == 'video' ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
    switch (status) {
      case 'missed':
        return '$prefix nhỡ';
      case 'rejected':
        return '$prefix bị từ chối';
      case 'busy':
        return '$prefix bận';
      case 'answered':
        return '$prefix đã kết nối';
      case 'ended':
        return '$prefix đã kết thúc';
      case 'canceled':
        return '$prefix đã hủy';
      default:
        return '$prefix đang đổ chuông';
    }
  }

  factory _CallLog.fromJson(Map<String, dynamic> json) {
    return _CallLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      callType: (json['call_type'] ?? 'video').toString(),
      status: (json['status'] ?? 'ringing').toString(),
      startedAt: (json['started_at'] ?? '').toString(),
    );
  }
}

class _ChatActionResult {
  const _ChatActionResult({required this.action});

  final String action;
}
