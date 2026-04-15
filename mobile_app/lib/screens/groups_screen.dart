import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _loading = true;
  List<_Group> _groups = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final params = <String, String>{'username': AppSession.username};
    if (_query.trim().isNotEmpty) params['q'] = _query.trim();
    final uri = Uri.parse('${AppApi.groups}/').replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _Group.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _groups = list;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _createGroup() async {
    final titleCtl = TextEditingController();
    final subjectCtl = TextEditingController();
    final categoryCtl = TextEditingController();
    final descCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tạo nhóm'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: 'Tên nhóm'),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: subjectCtl,
                  decoration: const InputDecoration(labelText: 'Môn học'),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: categoryCtl,
                  decoration: const InputDecoration(labelText: 'Danh mục nhóm'),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: descCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final res = await http.post(
      Uri.parse('${AppApi.groups}/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': AppSession.username,
        'title': titleCtl.text.trim(),
        'subject': subjectCtl.text.trim(),
        'category': categoryCtl.text.trim(),
        'description': descCtl.text.trim(),
      }),
    );

    if (res.statusCode == 201) {
      _load();
    }
  }

  Future<void> _joinGroup(_Group g) async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${g.id}/join/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      _setGroupJoined(g.id, incrementCount: true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tham gia nhóm')));
      _load();
      return;
    }

    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic> && data['detail'] == 'already member') {
        _setGroupJoined(g.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn đã tham gia nhóm')));
        return;
      }
    } catch (_) {
      // ignore JSON parse errors
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tham gia nhóm')));
  }

  void _setGroupJoined(int groupId, {bool incrementCount = false}) {
    if (!mounted) return;
    setState(() {
      _groups = _groups.map((group) {
        if (group.id != groupId) return group;
        return _Group(
          id: group.id,
          title: group.title,
          subject: group.subject,
          maxMembers: group.maxMembers,
          memberCount: incrementCount ? group.memberCount + 1 : group.memberCount,
          ownerName: group.ownerName,
          description: group.description,
          category: group.category,
          avatarUrl: group.avatarUrl,
          joined: true,
        );
      }).toList();
    });
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('#Nhóm học tập'),
        actions: [
          IconButton(
            onPressed: _createGroup,
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          /// 🔍 Search
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: TextField(
              onChanged: (v) {
                _query = v;
                _load();
              },
              decoration: const InputDecoration(
                hintText: 'Tìm nhóm theo tên hoặc mô tả...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          /// 📋 List nhóm
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const Center(child: Text('Không có nhóm nào'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final g = _groups[i];

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// 🏷️ Title
                                  Text(
                                    g.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  /// 📝 Description
                                  Text(
                                    g.description.isEmpty
                                        ? 'Không có mô tả'
                                        : g.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  /// 👥 Member + trạng thái
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${g.memberCount} thành viên',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),

                                      if (g.ownerName.toLowerCase() ==
                                          AppSession.username.toLowerCase())
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Chủ nhóm',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      else if (g.joined)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Đã tham gia',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: () => _joinGroup(g),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('Tham gia'),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  /// 📚 Subject + Category
                                  Text(
                                    '${g.subject} • ${g.category.isEmpty ? "Khác" : g.category}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGroup(_Group g) async {
    final titleCtl = TextEditingController(text: g.title);
    final subjectCtl = TextEditingController(text: g.subject);
    final categoryCtl = TextEditingController(text: g.category);
    final avatarCtl = TextEditingController(text: g.avatarUrl);
    final descCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chỉnh sửa nhóm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Tên nhóm')),
            const SizedBox(height: 8),
            TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Môn học')),
            const SizedBox(height: 8),
            TextField(controller: categoryCtl, decoration: const InputDecoration(labelText: 'Danh mục nhóm')),
            const SizedBox(height: 8),
            TextField(controller: avatarCtl, decoration: const InputDecoration(labelText: 'Avatar URL')),
            const SizedBox(height: 8),
            TextField(
              controller: descCtl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả mới'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await http.patch(
      Uri.parse('${AppApi.groups}/${g.id}/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': AppSession.username,
        'title': titleCtl.text.trim(),
        'subject': subjectCtl.text.trim(),
        'category': categoryCtl.text.trim(),
        'avatar_url': avatarCtl.text.trim(),
        if (descCtl.text.trim().isNotEmpty) 'description': descCtl.text.trim(),
      }),
    );
    if (res.statusCode == 200) _load();
  }
}

class _Group {
  _Group({
    required this.id,
    required this.title,
    required this.subject,
    required this.maxMembers,
    required this.memberCount,
    required this.ownerName,
    required this.description,
    required this.category,
    required this.avatarUrl,
    required this.joined,
  });

  final int id;
  final String title;
  final String subject;
  final int maxMembers;
  final int memberCount;
  final String ownerName;
  final String description;
  final String category;
  final String avatarUrl;
  final bool joined;

  factory _Group.fromJson(Map<String, dynamic> json) {
    return _Group(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      ownerName: (json['owner_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      joined: (json['joined'] as bool?) ?? false,
    );
  }
}
