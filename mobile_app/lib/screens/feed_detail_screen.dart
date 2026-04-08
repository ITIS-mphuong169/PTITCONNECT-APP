import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile_app/screens/feed_screen.dart';

class FeedDetailScreen extends StatelessWidget {
  const FeedDetailScreen({super.key, required this.item});

  final FeedItem item;

  Future<void> _openOriginal(BuildContext context) async {
    final uri = Uri.parse(item.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong mo duoc bai viet goc')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết bài viết')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 180,
              color: const Color(0xFFFFE6EF),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : const Icon(
                      Icons.newspaper_outlined,
                      size: 60,
                      color: Colors.black54,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.public, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.source,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              if (item.publishedAt.isNotEmpty)
                Text(
                  item.publishedAt,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.summary.isEmpty
                ? 'Bài viết không có mô tả ngắn. Nhấn nút bên dưới để đọc bản gốc từ website trường.'
                : item.summary,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openOriginal(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Mở bài gốc từ website PTIT'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFF33B6D),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
