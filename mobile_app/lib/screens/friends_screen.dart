// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/avatar_utils.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/messages_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';

Widget _avatar(String name, {double radius = 20}) {
  return initialsAvatar(name, radius: radius);
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;

  List<_RequestItem> _requests = [];
  List<_RequestItem> _sent = [];
  List<_ProfileMini> _friends = [];
  List<_ProfileMini> _suggestions = [];

  Timer? _timer;
  Timer? _searchDebounce;

  final TextEditingController _searchController = TextEditingController();
  List<_ProfileMini> _searchResults = [];
  bool _searching = false;
  final Set<String> _hiddenSuggestionUsernames = <String>{};

  final TextEditingController _friendSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );

    _load();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _friendSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    final params = {'username': AppSession.username};

    try {
      final results = await Future.wait([
        http.get(
          Uri.parse(
            '${AppApi.users}/friends/requests/inbox/',
          ).replace(queryParameters: params),
          headers: AppSession.authHeaders(),
        ),
        http.get(
          Uri.parse(
            '${AppApi.users}/friends/requests/sent/',
          ).replace(queryParameters: params),
          headers: AppSession.authHeaders(),
        ),
        http.get(
          Uri.parse(
            '${AppApi.users}/friends/',
          ).replace(queryParameters: params),
          headers: AppSession.authHeaders(),
        ),
        http.get(
          Uri.parse(
            '${AppApi.users}/friends/suggestions/',
          ).replace(queryParameters: params),
          headers: AppSession.authHeaders(),
        ),
      ]);

      if (!mounted) return;

      _requests = (jsonDecode(results[0].body) as List)
          .map((e) => _RequestItem.fromJson(e, incoming: true))
          .toList();

      _sent = (jsonDecode(results[1].body) as List)
          .map((e) => _RequestItem.fromJson(e, incoming: false))
          .toList();

      _friends = ((jsonDecode(results[2].body)['friends'] ?? []) as List)
          .map((e) => _ProfileMini.fromJson(e))
          .toList();

      _suggestions = ((jsonDecode(results[3].body)['results'] ?? []) as List)
          .map((e) => _ProfileMini.fromJson(e))
          .where((e) => !_hiddenSuggestionUsernames.contains(e.username))
          .toList();

      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================= CARD DÙNG CHUNG =================

  void _openUserCard(
    _ProfileMini profile,
    String type, {
    _RequestItem? request,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatar(
                profile.fullName.isEmpty ? profile.username : profile.fullName,
                radius: 34,
              ),
              const SizedBox(height: 12),
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(profile.studentId),
              Text(profile.email),
              const SizedBox(height: 8),
              Text(
                'Lớp: ${profile.classCode} • Ngành: ${profile.major}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  if (type == 'friend')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessagesScreen(
                                openPeerUsername: profile.username,
                              ),
                            ),
                          );
                        },
                        child: const Text('Nhắn tin'),
                      ),
                    ),

                  if (type == 'request') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _decide(request!, 'reject');
                        },
                        child: const Text('Từ chối'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _decide(request!, 'accept');
                        },
                        child: const Text('Đồng ý'),
                      ),
                    ),
                  ],

                  if (type == 'suggestion') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Xóa'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sendRequest(profile.username);
                        },
                        child: const Text('Thêm'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= API =================

  Future<void> _decide(_RequestItem item, String action) async {
    await http.post(
      Uri.parse('${AppApi.users}/friends/requests/${item.id}/decide/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({'username': AppSession.username, 'action': action}),
    );
    _load();
  }

  Future<void> _sendRequest(String username) async {
    await http.post(
      Uri.parse('${AppApi.users}/friends/requests/send/'),
      headers: AppSession.authHeaders(
        extra: const {'Content-Type': 'application/json'},
      ),
      body: jsonEncode({
        'username': AppSession.username,
        'to_username': username,
      }),
    );
    _load();
    if (_searchController.text.trim().isNotEmpty) {
      await _searchUsers(_searchController.text.trim());
    }
  }

  Future<void> _searchUsers(String rawQuery) async {
    final q = rawQuery.trim();

    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);

    try {
      final uri = Uri.parse('${AppApi.users}/search/').replace(
        queryParameters: {
          'username': AppSession.username,
          'q': q,
        },
      );
      final res = await http
          .get(uri, headers: AppSession.authHeaders())
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final blockedUsernames = <String>{
          ..._friends.map((e) => e.username),
          ..._requests.map((e) => e.profile.username),
          ..._sent.map((e) => e.profile.username),
        };

        final results = (body['results'] as List<dynamic>? ?? [])
            .map((e) => _ProfileMini.fromJson(e as Map<String, dynamic>))
            .where((e) => !blockedUsernames.contains(e.username))
            .where((e) => !_hiddenSuggestionUsernames.contains(e.username))
            .toList();

        setState(() {
          _searchResults = results;
          _searching = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }

  Widget _actionCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color background,
    Color iconColor = Colors.white,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final query = _friendSearchController.text.trim().toLowerCase();
    final filteredFriends = query.isEmpty
        ? _friends
        : _friends.where((f) {
            final fullName = f.fullName.toLowerCase();
            final studentId = f.studentId.toLowerCase();
            return fullName.contains(query) || studentId.contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _friendSearchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm bạn bè theo tên hoặc mã sinh viên',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _friendSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _friendSearchController.clear();
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredFriends.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? 'Chưa có bạn bè'
                        : 'Không tìm thấy bạn bè phù hợp',
                  ),
                )
              : ListView.builder(
                  itemCount: filteredFriends.length,
                  itemBuilder: (_, i) {
                    final f = filteredFriends[i];
                    return ListTile(
                      leading: _avatar(
                        f.fullName.isEmpty ? f.username : f.fullName,
                      ),
                      title: Text(
                        f.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text('${f.studentId} • ${f.email}'),
                      trailing: _actionCircleButton(
                        icon: Icons.message_rounded,
                        background: const Color(0xFFE53935),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessagesScreen(
                                openPeerUsername: f.username,
                              ),
                            ),
                          );
                        },
                      ),
                      onTap: () => _openUserCard(f, 'friend'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddFriendTab() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final items = hasQuery ? _searchResults : _suggestions;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                _searchUsers(value);
              });
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc mã sinh viên',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        _searchUsers('');
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(
                      child: Text(
                        hasQuery
                            ? 'Không tìm thấy người phù hợp'
                            : 'Chưa có gợi ý kết bạn',
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final s = items[i];
                        return ListTile(
                          leading: _avatar(
                            s.fullName.isEmpty ? s.username : s.fullName,
                          ),
                          title: Text(
                            s.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text('${s.studentId} • ${s.email}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _actionCircleButton(
                                icon: Icons.close_rounded,
                                background: Colors.white,
                                iconColor: const Color(0xFF4E81FF),
                                onTap: () {
                                  setState(() {
                                    _hiddenSuggestionUsernames.add(s.username);
                                    _suggestions.removeWhere(
                                      (e) => e.username == s.username,
                                    );
                                    _searchResults.removeWhere(
                                      (e) => e.username == s.username,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              _actionCircleButton(
                                icon: Icons.person_add_alt_1_rounded,
                                background: const Color(0xFF4E81FF),
                                onTap: () => _sendRequest(s.username),
                              ),
                            ],
                          ),
                          onTap: () => _openUserCard(s, 'suggestion'),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bạn bè'),
            Tab(text: 'Lời mời'),
            Tab(text: 'Gợi ý'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                ListView(
                  children: _requests
                      .map(
                        (e) => ListTile(
                          leading: _avatar(
                            e.profile.fullName.isEmpty
                                ? e.profile.username
                                : e.profile.fullName,
                          ),
                          title: Text(
                            e.profile.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${e.profile.studentId} • ${e.profile.email}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _actionCircleButton(
                                icon: Icons.close_rounded,
                                background: Colors.white,
                                iconColor: const Color(0xFF4E81FF),
                                onTap: () => _decide(e, 'reject'),
                              ),
                              const SizedBox(width: 8),
                              _actionCircleButton(
                                icon: Icons.check_rounded,
                                background: const Color(0xFF4E81FF),
                                onTap: () => _decide(e, 'accept'),
                              ),
                            ],
                          ),
                          onTap: () =>
                              _openUserCard(e.profile, 'request', request: e),
                        ),
                      )
                      .toList(),
                ),
                _buildAddFriendTab(),
              ],
            ),
    );
  }
}

class _RequestItem {
  final int id;
  final _ProfileMini profile;

  _RequestItem({required this.id, required this.profile});

  factory _RequestItem.fromJson(
    Map<String, dynamic> json, {
    required bool incoming,
  }) {
    return _RequestItem(
      id: json['id'] ?? 0,
      profile: _ProfileMini.fromJson(
        incoming ? json['from_profile'] : json['to_profile'],
      ),
    );
  }
}

class _ProfileMini {
  final String username;
  final String fullName;
  final String studentId;
  final String email;
  final String classCode;
  final String major;
  final String avatar;

  _ProfileMini({
    required this.username,
    required this.fullName,
    required this.studentId,
    required this.email,
    required this.classCode,
    required this.major,
    required this.avatar,
  });

  factory _ProfileMini.fromJson(Map<String, dynamic> json) {
    return _ProfileMini(
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      studentId: json['student_id'] ?? '',
      email: json['email'] ?? '',
      classCode: json['class_code'] ?? '',
      major: json['major'] ?? '',
      avatar: json['avatar_url'] ?? json['avatar'] ?? '',
    );
  }
}
