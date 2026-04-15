import 'package:flutter/material.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  // --- DATA TAB 1: NGƯỜI DÙNG VI PHẠM (100 MOCK DATA) ---
  List<Map<String, dynamic>> violatingUsers = List.generate(100, (index) {
    final types = ['Ngôn từ thù ghét', 'Spam/Lừa đảo', 'Quấy rối', 'Giả mạo'];
    final reasons = [
      'Sử dụng từ ngữ phản cảm, xúc phạm trong bình luận.',
      'Gửi hàng loạt tin nhắn chứa link lừa đảo trúng thưởng.',
      'Bắt nạt, công kích cá nhân sinh viên khác trên diễn đàn.',
      'Sử dụng hình ảnh và tên của giảng viên để tạo tài khoản ảo.'
    ];
    final contents = [
      'Bình luận: "Trường dạy chán quá, giảng viên toàn bọn..."',
      'Bài viết: "Click ngay link này để nhận 500k miễn phí: http://link-scam.xyz"',
      'Bình luận: "Mày ngu thế này học PTIT làm gì cho tốn tiền?"',
      'Hồ sơ: Tên hiển thị "TS. Nguyễn Văn X", ảnh đại diện copy từ website trường.'
    ];

    int typeIndex = index % 4;

    return {
      'id': 'U${(index + 1).toString().padLeft(3, '0')}',
      'name': 'Sinh viên số ${index + 1}',
      'reason': reasons[typeIndex],
      'violationType': types[typeIndex],
      'avatar': 'https://picsum.photos/200?random=${index}',
      'violatingContent': contents[typeIndex],
    };
  });

  // --- DATA TAB 2: BÀI VIẾT VI PHẠM (100 MOCK DATA) ---
  List<Map<String, dynamic>> violatingPosts = List.generate(100, (index) {
    final types = ['Nội dung nhạy cảm', 'Vi phạm chính sách', 'Spam/Lừa đảo', 'Tin giả'];
    final reasons = [
      'Hình ảnh chứa nội dung nhạy cảm.',
      'Chia sẻ tài liệu vi phạm bản quyền.',
      'Quảng cáo dịch vụ cày thuê không được phép.',
      'Đăng tin sai sự thật về lịch thi học kỳ.'
    ];
    
    int typeIndex = index % 4;

    return {
      'id': 'P${(index + 1).toString().padLeft(3, '0')}',
      'author': 'Người dùng số ${index + 1}',
      'time': '${(index % 24) + 1}h trước',
      'content': 'Đây là nội dung bài viết vi phạm số ${index + 1}. Bài viết này đã bị báo cáo vì vi phạm tiêu chuẩn cộng đồng của sinh viên PTIT.',
      'reason': reasons[typeIndex],
      'violationType': types[typeIndex],
      'image': 'https://picsum.photos/400/250?random=${100 + index}',
    };
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 10,
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFF3B5C),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Người dùng vi phạm"),
              Tab(text: "Bài viết vi phạm"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildViolationList(isUser: true), // Tab xử lý người dùng
            _buildViolationList(isUser: false), // Tab xử lý bài viết
          ],
        ),
      ),
    );
  }

  // Giao diện danh sách vi phạm
  Widget _buildViolationList({required bool isUser}) {
    final list = isUser ? violatingUsers : violatingPosts;
    
    if (list.isEmpty) {
      return const Center(child: Text("Hiện không có báo cáo vi phạm nào."));
    }

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemBuilder: (context, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Thông tin đối tượng vi phạm
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(isUser ? item['avatar'] : 'https://picsum.photos/100?random=${index}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? item['name'] : item['author'], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                        ),
                        Text(
                          isUser ? "ID: ${item['id']}" : item['time'], 
                          style: const TextStyle(color: Colors.grey, fontSize: 12)
                        ),
                      ],
                    ),
                  ),
                  // Nhãn loại vi phạm (Tag)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['violationType'],
                      style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              // Nội dung vi phạm
              if (!isUser) ...[
                // Dành cho Bài viết vi phạm
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(item['content'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(item['image'], height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ] else if (item.containsKey('violatingContent')) ...[
                // Dành cho Người dùng vi phạm (Hiển thị chi tiết nội dung họ đã vi phạm)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Chi tiết nội dung vi phạm:", 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "\"${item['violatingContent']}\"", 
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87)
                      ),
                    ],
                  ),
                ),
              ],

              // Lý do báo cáo vi phạm
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                    children: [
                      const TextSpan(text: "Lý do báo cáo: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: item['reason']),
                    ],
                  ),
                ),
              ),

              // Nhóm nút thao tác (Pill Shape)
              Row(
                children: [
                  _pillButton("Cảnh cáo", Colors.orange, () => _handleAction("cảnh cáo", index, isUser)),
                  const SizedBox(width: 8),
                  _pillButton(
                    isUser ? "Khóa tài khoản" : "Xóa bài", 
                    const Color(0xFFFF3B5C), 
                    () => _handleAction(isUser ? "khóa" : "xóa", index, isUser)
                  ),
                  const SizedBox(width: 8),
                  _pillButton("Bỏ qua", Colors.grey, () => _handleAction("bỏ qua", index, isUser)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
            ],
          ),
        );
      },
    );
  }

  // Widget nút bấm hình viên thuốc
  Widget _pillButton(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          text, 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Logic xử lý hành động
  void _handleAction(String action, int index, bool isUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Xác nhận $action?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          _pillButton("Chắc chắn", Colors.green, () {
            Navigator.pop(ctx);
            setState(() {
              if (isUser) {
                violatingUsers.removeAt(index);
              } else {
                violatingPosts.removeAt(index);
              }
            });
            _showAutoCloseDialog("Đã thực hiện $action thành công!");
          }),
          _pillButton("Hủy", const Color(0xFFFF3B5C), () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  void _showAutoCloseDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }
}