import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_moderation_screen.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardBody(), 
      const AdminModerationScreen(), 
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFFF3B5C),
          unselectedItemColor: Colors.black54,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Thống kê'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Quản trị'),
          ],
        ),
      ),
    );
  }
}

// ---- WIDGET CHỨA GIAO DIỆN THỐNG KÊ ----
class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bảng điều khiển',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                _buildStatCard('1250', 'Sinh viên hoạt động'),
                const SizedBox(width: 16),
                _buildStatCard('1250', 'Bài viết chờ duyệt'),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Thống kê số lượng bài viết mới',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 220, 
              child: _buildBarChart(), 
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String number, String title) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B5C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF3B5C).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 30,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500);
                Widget text;
                switch (value.toInt()) {
                  case 0: text = const Text('22.02', style: style); break;
                  case 1: text = const Text('23.02', style: style); break;
                  case 2: text = const Text('24.02', style: style); break;
                  case 3: text = const Text('25.02', style: style); break;
                  case 4: text = const Text('26.02', style: style); break;
                  case 5: text = const Text('Today', style: style); break;
                  default: text = const Text('', style: style); break;
                }
                return SideTitleWidget(meta: meta, space: 10, child: text);
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                Widget text;
                const style = TextStyle(color: Colors.grey, fontSize: 11);
                if (value == 0) text = const Text('0', style: style);
                else if (value == 10) text = const Text('10K', style: style);
                else if (value == 20) text = const Text('20K', style: style);
                else if (value == 30) text = const Text('30K', style: style);
                else text = const Text('');
                return SideTitleWidget(meta: meta, space: 0, child: text);
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeGroupData(0, 18, const Color(0xFFA0BBE8)),
          _makeGroupData(1, 28, const Color(0xFF65E0C2)),
          _makeGroupData(2, 21, const Color(0xFF000000)), // Cột đen
          _makeGroupData(3, 28, const Color(0xFF7BB4FF)),
          _makeGroupData(4, 14, const Color(0xFFB698EA)),
          _makeGroupData(5, 24, const Color(0xFF6AD08A)),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }
}