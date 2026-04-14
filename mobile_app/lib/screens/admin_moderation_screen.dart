import 'package:flutter/material.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  // --- DATA BÀI VIẾT (Giữ nguyên như cũ) ---
  List<Map<String, String>> posts = [
    {
      'id': '1', 
      'author': 'chill guy PTIT', 
      'time': '2h trước',
      'content': 'Nay ăn thử bát salad dưới canteen xịn phết mọi người ạ.'
    },
    {
      'id': '2', 
      'author': 'Nguyễn Văn A', 
      'time': '3h trước',
      'content': 'Góc chia sẻ tài liệu ôn thi môn Kỹ nghệ phần mềm.'
    },
  ];

  // --- DATA NGƯỜI DÙNG VI PHẠM (Thiết kế mới) ---
  List<Map<String, dynamic>> violatingUsers = [
    {
      'id': 'U001',
      'name': 'Nguyễn Văn A',
      'reason': 'Sử dụng ngôn từ không phù hợp trong bình luận.',
      'violationType': 'Ngôn từ thù ghét',
      'avatar': 'https://picsum.photos/200?random=10',
    },
    {
      'id': 'U002',
      'name': 'Trần Thị B',
      'reason': 'Đăng tải nội dung spam quảng cáo nhiều lần.',
      'violationType': 'Spam',
      'avatar': 'https://picsum.photos/200?random=11',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Quản trị hệ thống', 
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
          ),
          bottom: const TabBar(
            labelColor: Color(0xFFFF3B5C),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFF3B5C),
            tabs: [
              Tab(text: "Người dùng vi phạm"),
              Tab(text: "Bài viết chờ duyệt"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserViolationTab(), // Tab 1: Xử lý người dùng
            _buildPostManagementTab(), // Tab 2: Xử lý bài viết (ĐÃ FIX LỖI)
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ==================== TAB 1: NGƯỜI DÙNG VI PHẠM ==========================
  // =========================================================================

  Widget _buildUserViolationTab() {
    if (violatingUsers.isEmpty) {
      return const Center(child: Text("Không có báo cáo vi phạm nào."));
    }
    return ListView.builder(
      itemCount: violatingUsers.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _buildUserViolationItem(index),
    );
  }

  Widget _buildUserViolationItem(int index) {
    final user = violatingUsers[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(user['avatar']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Mã SV: ${user['id']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B5C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  user['violationType'], 
                  style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 10, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  const TextSpan(text: "Lý do: ", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: user['reason']),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _actionButton("Cảnh cáo", Colors.orange, () => _handleUserAction("cảnh cáo", index))),
              const SizedBox(width: 8),
              Expanded(child: _actionButton("Khóa", const Color(0xFFFF3B5C), () => _handleUserAction("khóa", index))),
              const SizedBox(width: 8),
              Expanded(child: _actionButton("Bỏ qua", Colors.grey, () => _handleUserAction("bỏ qua", index))),
            ],
          ),
        ],
      ),
    );
  }

  void _handleUserAction(String action, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Xác nhận $action?"),
        content: Text("Bạn có chắc chắn muốn thực hiện hành động này đối với ${violatingUsers[index]['name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B5C)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => violatingUsers.removeAt(index));
              _showAutoCloseDialog("${action[0].toUpperCase()}${action.substring(1)} thành công!");
            }, 
            child: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ==================== TAB 2: BÀI VIẾT CHỜ DUYỆT ==========================
  // =========================================================================

  Widget _buildPostManagementTab() {
    if (posts.isEmpty) {
      return const Center(child: Text("Không còn bài viết nào chờ duyệt"));
    }
    return ListView.builder(
      itemCount: posts.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _buildPostItem(index),
    );
  }

  Widget _buildPostItem(int index) {
    final post = posts[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20, 
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['author']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(post['time']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(post['content']!),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://picsum.photos/400/250?random=$index',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton("Duyệt", Colors.green, () => _confirmPostAction("Duyệt", index)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _actionButton("Xóa", const Color(0xFFFF3B5C), () => _confirmPostAction("Xóa", index)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  void _confirmPostAction(String action, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Bạn có chắc muốn $action?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => posts.removeAt(index));
              _showAutoCloseDialog("$action thành công!");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Chắc chắn', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ========================== HÀM TIỆN ÍCH DÙNG CHUNG ======================
  // =========================================================================

  Widget _actionButton(String text, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  void _showAutoCloseDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if(mounted) {
        Navigator.pop(context);
      }
    });
  }
}