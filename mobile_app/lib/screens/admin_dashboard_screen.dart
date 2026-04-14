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
      const DashboardBody(), // Tab Thống kê chuyên sâu
      const AdminModerationScreen(), // Tab Quản trị
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(index: _selectedIndex, children: _screens),
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
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Tổng quan'),
            BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Quản trị'),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// ==================== WIDGET THỐNG KÊ (DASHBOARD) ====================
// =====================================================================
class DashboardBody extends StatefulWidget {
  const DashboardBody({super.key});

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  bool isDailyGrowthView = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bảng điều khiển', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
            const SizedBox(height: 24),
            
            // --- KPI CƠ BẢN (Đã khôi phục đủ 4 chỉ số 2x2) ---
            _buildKpiGrid(),
            const SizedBox(height: 32),

            // --- MODULE 4: XU HƯỚNG TÌM KIẾM ---
            _buildSectionTitle('Xu hướng tìm kiếm'),
            _buildModule4SearchTrends(),
            const SizedBox(height: 32),

            // --- MODULE 1: BẢO VỆ CỘNG ĐỒNG ---
            _buildSectionTitle('Bảo vệ Cộng đồng (Báo cáo vi phạm)'),
            const SizedBox(height: 16),
            _buildModule1ProtectionChart(context),
            const SizedBox(height: 32),

            // --- MODULE 2: PHÂN TÍCH TĂNG TRƯỞNG ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Tăng trưởng sinh viên'),
                TextButton.icon(
                  onPressed: () => setState(() => isDailyGrowthView = !isDailyGrowthView),
                  icon: Icon(isDailyGrowthView ? Icons.calendar_month : Icons.today, size: 16, color: const Color(0xFFFF3B5C)),
                  label: Text(isDailyGrowthView ? 'Xem theo Tháng' : 'Xem theo Ngày', style: const TextStyle(color: Color(0xFFFF3B5C))),
                )
              ],
            ),
            _buildModule2GrowthChart(),
            const SizedBox(height: 32),

            // --- [BỔ SUNG] BIỂU ĐỒ CỘT CHỒNG (THEO KHÓA) ---
            _buildSectionTitle('Tăng trưởng theo khóa (4 tháng qua)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
              child: Column(
                children: [
                  SizedBox(height: 200, child: _buildStackedBarChart()),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildIndicator(const Color(0xFFA0BBE8), 'D21'),
                      const SizedBox(width: 12),
                      _buildIndicator(const Color(0xFF65E0C2), 'D22'),
                      const SizedBox(width: 12),
                      _buildIndicator(const Color(0xFFB698EA), 'D23'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- [BỔ SUNG] BIỂU ĐỒ TRÒN & HEATMAP GIỜ ---
            _buildSectionTitle('Chủ đề được bàn luận (24h qua)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phân loại chủ đề', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(height: 180, child: _buildPieChart()),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 24),
                  const Text('Mật độ hoạt động theo giờ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildActivityHeatmap(),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- MODULE 3: CHỈ SỐ GIỮ CHÂN (COHORT) ---
            _buildSectionTitle('Chỉ số giữ chân (Retention Rate)'),
            const Text('Tỷ lệ % sinh viên quay lại app theo từng tháng.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            _buildModule3CohortHeatmap(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  // --- KPI ĐÃ ĐƯỢC CHỈNH LẠI THÀNH LƯỚI 4 Ô ---
  Widget _buildKpiGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard('4,250', 'Sinh viên', Icons.people_alt_rounded),
            const SizedBox(width: 16),
            _buildStatCard('850', 'Tương tác 24h', Icons.forum_rounded),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard('120', 'Tài liệu mới', Icons.description_rounded),
            const SizedBox(width: 16),
            _buildStatCard('45%', 'DAU/MAU', Icons.trending_up_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String number, String title, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B5C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFFF3B5C).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
            const SizedBox(height: 12),
            Text(number, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ==================== MODULE 1: BẢO VỆ CỘNG ĐỒNG ====================
  Widget _buildModule1ProtectionChart(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.black87, 
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(fontSize: 11, fontWeight: FontWeight.bold);
                  switch (value.toInt()) {
                    case 0: return const Text('Spam', style: style);
                    case 1: return const Text('Độc hại', style: style);
                    case 2: return const Text('Lừa đảo', style: style);
                    case 3: return const Text('Khác', style: style);
                    default: return const Text('');
                  }
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: [
            _makeSimpleBar(0, 85, Colors.orange),
            _makeSimpleBar(1, 40, const Color(0xFFFF3B5C)),
            _makeSimpleBar(2, 20, Colors.red[900]!),
            _makeSimpleBar(3, 15, Colors.grey),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeSimpleBar(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: color, width: 30, borderRadius: BorderRadius.circular(6))]);
  }

  // ==================== MODULE 2: PHÂN TÍCH TĂNG TRƯỞNG ====================
  Widget _buildModule2GrowthChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: isDailyGrowthView ? _buildDailyLineChart() : _buildMonthlyBarChart(),
    );
  }

  Widget _buildMonthlyBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 500,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              getTitlesWidget: (v, meta) => Text('Tháng ${v.toInt() + 8}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
            )
          ), 
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeSimpleBar(0, 150, const Color(0xFF7BB4FF)),
          _makeSimpleBar(1, 300, const Color(0xFF7BB4FF)),
          _makeSimpleBar(2, 450, const Color(0xFF7BB4FF)),
          _makeSimpleBar(3, 200, const Color(0xFF7BB4FF)),
        ],
      ),
    );
  }

  Widget _buildDailyLineChart() {
    return LineChart(
      LineChartData(
        minY: 0, maxY: 100,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(getTooltipColor: (touchedSpot) => Colors.black87),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              interval: 5, 
              getTitlesWidget: (v, meta) => Text('Ngày ${v.toInt()}', style: const TextStyle(fontSize: 10))
            )
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(1, 10), FlSpot(5, 15), FlSpot(10, 85), FlSpot(15, 30), FlSpot(20, 25), FlSpot(25, 40), FlSpot(30, 20)],
            isCurved: true,
            color: const Color(0xFFFF3B5C),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xFFFF3B5C).withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  // ==================== CÁC COMPONENT BỔ SUNG (THEO YÊU CẦU CŨ) ====================
  Widget _buildStackedBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Text('Tháng ${v.toInt() + 8}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeStackedBar(0, 20, 30, 40),
          _makeStackedBar(1, 25, 35, 30),
          _makeStackedBar(2, 30, 40, 20),
          _makeStackedBar(3, 40, 50, 10),
        ],
      ),
    );
  }

  BarChartGroupData _makeStackedBar(int x, double d1, double d2, double d3) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
        toY: d1 + d2 + d3,
        width: 20,
        borderRadius: BorderRadius.circular(4),
        rodStackItems: [
          BarChartRodStackItem(0, d1, const Color(0xFFA0BBE8)),
          BarChartRodStackItem(d1, d1 + d2, const Color(0xFF65E0C2)),
          BarChartRodStackItem(d1 + d2, d1 + d2 + d3, const Color(0xFFB698EA)),
        ],
      )
    ]);
  }

  Widget _buildPieChart() {
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: [
                PieChartSectionData(value: 40, color: const Color(0xFF7BB4FF), title: '40%', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: 30, color: const Color(0xFF65E0C2), title: '30%', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: 30, color: const Color(0xFFFF3B5C), title: '30%', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIndicator(const Color(0xFF7BB4FF), 'Hỏi đáp'),
            const SizedBox(height: 8),
            _buildIndicator(const Color(0xFF65E0C2), 'Tài liệu'),
            const SizedBox(height: 8),
            _buildIndicator(const Color(0xFFFF3B5C), 'Tán gẫu'),
          ],
        )
      ],
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActivityHeatmap() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0h', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('12h', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('24h', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: Row(
            children: List.generate(24, (i) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C).withOpacity(i < 6 ? 0.1 : (i < 18 ? 0.5 : 0.9)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ==================== MODULE 3: CHỈ SỐ GIỮ CHÂN (COHORT) ====================
  Widget _buildModule3CohortHeatmap() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FA)), 
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Nhóm Đăng Ký', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tháng 1', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tháng 2', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tháng 3', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: [
              _buildCohortRow('Sinh viên Th 8 (400)', [100, 65, 40]),
              _buildCohortRow('Sinh viên Th 9 (650)', [100, 50, 20]),
              _buildCohortRow('Sinh viên Th 10 (200)', [100, 85, null]),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildCohortRow(String cohort, List<int?> percentages) {
    return DataRow(
      cells: [
        DataCell(Text(cohort, style: const TextStyle(fontWeight: FontWeight.w500))),
        ...percentages.map((pct) {
          if (pct == null) return const DataCell(Text('-'));
          Color bgColor;
          if (pct > 60) bgColor = Colors.green.withOpacity(pct / 100);
          else if (pct > 30) bgColor = Colors.blue.withOpacity(pct / 100);
          else bgColor = Colors.orange.withOpacity((100 - pct) / 100);

          return DataCell(
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
              child: Text('$pct%', style: TextStyle(color: pct > 40 ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            )
          );
        }).toList(),
      ]
    );
  }

  // ==================== MODULE 4: XU HƯỚNG TÌM KIẾM ====================
  Widget _buildModule4SearchTrends() {
    List<Map<String, dynamic>> trends = [
      {'rank': 1, 'keyword': 'Đồ án cơ sở dữ liệu', 'count': '1,200', 'isUp': true},
      {'rank': 2, 'keyword': 'Đề thi Mạng máy tính', 'count': '980', 'isUp': true},
      {'rank': 3, 'keyword': 'Nhà trọ quanh PTIT', 'count': '650', 'isUp': false},
    ];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Column(
        children: trends.map((trend) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: trend['rank'] == 1 ? Colors.orange.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              child: Text('#${trend['rank']}', style: TextStyle(color: trend['rank'] == 1 ? Colors.orange : Colors.black87, fontWeight: FontWeight.bold)),
            ),
            title: Text(trend['keyword'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Row(
              children: [
                Text('${trend['count']} lượt', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Icon(trend['isUp'] ? Icons.trending_up : Icons.trending_down, size: 14, color: trend['isUp'] ? Colors.green : Colors.red),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}