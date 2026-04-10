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
    final uri = Uri.parse('${AppApi.groups}/').replace(
      queryParameters: _query.trim().isEmpty ? null : {'q': _query.trim()},
    );
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
    final avatarCtl = TextEditingController();
    final descCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tạo nhóm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Tên nhóm')),
            const SizedBox(height: 8),
            TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Môn học')),
            const SizedBox(height: 8),
            TextField(controller: categoryCtl, decoration: const InputDecoration(labelText: 'Danh mục nhóm')),
            const SizedBox(height: 8),
            TextField(controller: avatarCtl, decoration: const InputDecoration(labelText: 'Avatar URL (tùy chọn)')),
            const SizedBox(height: 8),
            TextField(
              controller: descCtl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo')),
        ],
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
        'avatar_url': avatarCtl.text.trim(),
        'description': descCtl.text.trim(),
      }),
    );
    if (res.statusCode == 201) _load();
  }

  Future<void> _joinGroup(_Group g) async {
    final res = await http.post(
      Uri.parse('${AppApi.groups}/${g.id}/join/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    final msg = res.statusCode == 201 ? 'Đã gửi yêu cầu tham gia' : 'Không thể gửi yêu cầu';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('#Nhóm học tập'),
        actions: [IconButton(onPressed: _createGroup, icon: const Icon(Icons.group_add_outlined))],
      ),
      body: Column(
        children: [
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
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _groups.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final g = _groups[i];
                      return Card(
                        child: ListTile(
                          title: Text(g.title),
                          subtitle: Text(
                            '${g.subject} • ${g.category.isEmpty ? "Khác" : g.category}\n'
                            '${g.memberCount}/${g.maxMembers} thành viên',
                          ),
                          isThreeLine: true,
                          trailing: g.ownerName.toLowerCase() == AppSession.username.toLowerCase()
                              ? TextButton(
                                  onPressed: () => _editGroup(g),
                                  child: const Text('Chỉnh sửa'),
                                )
                              : ElevatedButton(
                                  onPressed: () => _joinGroup(g),
                                  child: const Text('Tham gia'),
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
    required this.category,
    required this.avatarUrl,
  });

  final int id;
  final String title;
  final String subject;
  final int maxMembers;
  final int memberCount;
  final String ownerName;
  final String category;
  final String avatarUrl;

  factory _Group.fromJson(Map<String, dynamic> json) {
    return _Group(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      ownerName: (json['owner_name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
    );
  }
}

