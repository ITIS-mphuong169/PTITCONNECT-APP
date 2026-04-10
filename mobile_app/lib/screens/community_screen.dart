import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/app_api.dart';
import 'package:mobile_app/core/app_session.dart';
import 'package:mobile_app/screens/documents_screen.dart';
import 'package:mobile_app/screens/groups_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool _loading = true;
  String? _errorMessage;
  final String _apiBase = AppApi.community;
  final _searchController = TextEditingController();
  String _selectedTopic = 'all';
  List<_Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts({String query = ''}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final uri = Uri.parse('$_apiBase/posts/').replace(
        queryParameters: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'username': AppSession.username,
        },
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('status ${res.statusCode}');
      }
      final list = (jsonDecode(res.body) as List<dynamic>)
          .map((e) => _Post.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
        _posts = [];
      });
    }
  }

  Future<void> _createPost() async {
    final controller = TextEditingController();
    final content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tạo bài viết',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Bạn đang nghĩ gì?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('Đăng'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (content == null || content.isEmpty) return;
    if (!mounted) return;
    final topicController = TextEditingController();
    final pickedTopic = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập category'),
        content: TextField(
          controller: topicController,
          decoration: const InputDecoration(hintText: 'Ví dụ: Flutter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, topicController.text.trim()),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
    final title = content.length > 60
        ? '${content.substring(0, 60)}...'
        : content;
    final res = await http.post(
      Uri.parse('$_apiBase/posts/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': AppSession.username,
        'title': title,
        'content': content,
        'topic': (pickedTopic == null || pickedTopic.isEmpty)
            ? 'Community'
            : pickedTopic,
      }),
    );
    if (res.statusCode == 201) {
      await _loadPosts();
    }
  }

  Future<void> _toggleLike(_Post post) async {
    final res = await http.post(
      Uri.parse('$_apiBase/posts/${post.id}/react/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        post.isLiked = body['liked'] == true;
        post.likes = (body['like_count'] ?? post.likes) as int;
      });
    }
  }

  Future<void> _toggleSave(_Post post) async {
    final res = await http.post(
      Uri.parse('$_apiBase/posts/${post.id}/save/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': AppSession.username}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        post.isSaved = body['saved'] == true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng đồng'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                );
              },
              child: const Text('#Tài liệu'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                );
              },
              child: const Text('#Nhóm'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        backgroundColor: const Color(0xFFF33B6D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Không tải được dữ liệu cộng đồng',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadPosts,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _filteredPosts.length + 1,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildFilters();
                  }
                  final post = _filteredPosts[index - 1];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _PostDetailScreen(
                              post: post,
                              username: AppSession.username,
                              apiBase: _apiBase,
                            ),
                          ),
                        );
                        _loadPosts();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _toggleLike(post),
                                  icon: Icon(
                                    post.isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: post.isLiked ? Colors.red : null,
                                  ),
                                ),
                                Text('${post.likes}'),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.mode_comment_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text('${post.comments.length} bình luận'),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _toggleSave(post),
                                  icon: Icon(
                                    post.isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  List<_Post> get _filteredPosts {
    final q = _searchController.text.trim().toLowerCase();
    return _posts.where((p) {
      final topicOk =
          _selectedTopic == 'all' ||
          p.topic.toLowerCase() == _selectedTopic.toLowerCase();
      final queryOk =
          q.isEmpty ||
          p.content.toLowerCase().contains(q) ||
          p.author.toLowerCase().contains(q) ||
          p.topic.toLowerCase().contains(q);
      return topicOk && queryOk;
    }).toList();
  }

  Widget _buildFilters() {
    final topics = <String>{
      'all',
      ..._posts.map((e) => e.topic).where((e) => e.isNotEmpty),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm bài viết, tác giả, category...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: topics.map((topic) {
              final selected = topic == _selectedTopic;
              final label = topic == 'all' ? '#Tất_cả' : '#$topic';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTopic = topic),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PostDetailScreen extends StatefulWidget {
  const _PostDetailScreen({
    required this.post,
    required this.apiBase,
    required this.username,
  });

  final _Post post;
  final String apiBase;
  final String username;

  @override
  State<_PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<_PostDetailScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết bài viết'),
        actions: [
          if (widget.post.author.toLowerCase() == widget.username.toLowerCase())
            IconButton(
              onPressed: _editPost,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.author,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(widget.post.content),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.post.comments.length,
              itemBuilder: (_, index) => ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person, size: 18),
                ),
                title: Text(widget.post.comments[index].author),
                subtitle: Text(widget.post.comments[index].content),
              ),
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
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập bình luận...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      final text = _commentController.text.trim();
                      if (text.isEmpty) return;
                      final res = await http.post(
                        Uri.parse(
                          '${widget.apiBase}/posts/${widget.post.id}/comments/',
                        ),
                        headers: const {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'username': widget.username,
                          'content': text,
                        }),
                      );
                      if (res.statusCode == 201) {
                        final body =
                            jsonDecode(res.body) as Map<String, dynamic>;
                        setState(() {
                          widget.post.comments.add(
                            _Comment(
                              author: (body['author_name'] ?? widget.username)
                                  .toString(),
                              content: (body['content'] ?? '').toString(),
                            ),
                          );
                          _commentController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPost() async {
    final ctl = TextEditingController(text: widget.post.content);
    final topicCtl = TextEditingController(text: widget.post.topic);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chỉnh sửa bài viết'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Nội dung'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: topicCtl,
              decoration: const InputDecoration(labelText: 'Category'),
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
    final content = ctl.text.trim();
    final topic = topicCtl.text.trim();
    final title = content.length > 60 ? '${content.substring(0, 60)}...' : content;
    final res = await http.patch(
      Uri.parse('${widget.apiBase}/posts/${widget.post.id}/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': widget.username,
        'title': title,
        'content': content,
        'topic': topic,
      }),
    );
    if (res.statusCode == 200) {
      setState(() {
        widget.post.content = content;
        widget.post.topic = topic;
      });
    }
  }
}

class _Post {
  _Post({
    required this.id,
    required this.author,
    required this.content,
    required this.likes,
    required this.topic,
    required this.comments,
  });

  final int id;
  final String author;
  String content;
  String topic;
  int likes;
  bool isLiked = false;
  bool isSaved = false;
  final List<_Comment> comments;

  factory _Post.fromJson(Map<String, dynamic> json) {
    final likeCount = (json['like_count'] as num?)?.toInt() ?? 0;
    final postId = (json['id'] as num?)?.toInt() ?? 0;
    return _Post(
      id: postId,
      author: (json['author_name'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      likes: likeCount,
      topic: (json['topic'] ?? '').toString(),
      comments: (json['comments'] as List<dynamic>? ?? [])
          .map(
            (e) => _Comment(
              author: (e['author_name'] ?? '').toString(),
              content: (e['content'] ?? '').toString(),
            ),
          )
          .toList(),
    );
  }
}

class _Comment {
  _Comment({required this.author, required this.content});

  final String author;
  final String content;
}
