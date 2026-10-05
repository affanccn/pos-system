import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';

class AdvancedReportsScreen extends ConsumerStatefulWidget {
  const AdvancedReportsScreen({super.key});

  @override
  ConsumerState<AdvancedReportsScreen> createState() => _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends ConsumerState<AdvancedReportsScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    final startStr = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0).toIso8601String();
    final endStr = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String();
    try {
      final res = await apiClient.dio.get('/reports/advanced', queryParameters: {
        'startDate': startStr,
        'endDate': endStr,
      });
      setState(() {
        _reportData = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor yüklenemedi: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReport();
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<dynamic> peakHours) {
    if (peakHours.isEmpty) return const Center(child: Text('Veri yok', style: TextStyle(color: Colors.white54)));
    
    double maxY = 0;
    for (var p in peakHours) {
      if (p['count'] > maxY) maxY = (p['count'] as num).toDouble();
    }
    maxY = maxY + (maxY * 0.2);
    
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY == 0 ? 10 : maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}:00', style: const TextStyle(color: Colors.white70, fontSize: 10));
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: peakHours.map<BarChartGroupData>((p) {
            return BarChartGroupData(
              x: p['hour'],
              barRods: [
                BarChartRodData(
                  toY: (p['count'] as num).toDouble(),
                  color: const Color(0xFF38BDF8),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic> items, String Function(dynamic) nameExtractor, String Function(dynamic) valueExtractor) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (items.isEmpty) const Text('Veri yok', style: TextStyle(color: Colors.white54)),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(nameExtractor(item), 
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(valueExtractor(item), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Gelişmiş Raporlar', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text('${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
        : _reportData == null 
          ? const Center(child: Text('Veri bulunamadı', style: TextStyle(color: Colors.white)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Finansal Özet', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    children: [
                      _buildSummaryCard('Toplam Ciro', '${(_reportData!['financials']['totalRevenueCents'] / 100).toStringAsFixed(2)} TL', Icons.account_balance_wallet, Colors.green),
                      _buildSummaryCard('Nakit', '${(_reportData!['financials']['cashTotalCents'] / 100).toStringAsFixed(2)} TL', Icons.money, Colors.teal),
                      _buildSummaryCard('Kredi Kartı', '${(_reportData!['financials']['cardTotalCents'] / 100).toStringAsFixed(2)} TL', Icons.credit_card, Colors.blue),
                      _buildSummaryCard('İndirim', '${(_reportData!['financials']['discountCents'] / 100).toStringAsFixed(2)} TL', Icons.discount, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Operasyonel Özet', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    children: [
                      _buildSummaryCard('Toplam Sipariş', '${_reportData!['staff']['orderCount']}', Icons.receipt_long, Colors.purple),
                      _buildSummaryCard('Ortalama Hesap', '${(_reportData!['staff']['avgTicketCents'] / 100).toStringAsFixed(2)} TL', Icons.analytics, Colors.indigo),
                      _buildSummaryCard('Ort. Sipariş Süresi', '${(_reportData!['operations']['avgOrderTimeMin'] as num).toStringAsFixed(1)} dk', Icons.timer, Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Yoğun Saatler', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF1E293B),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildBarChart(_reportData!['operations']['peakHours'] as List<dynamic>),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildListSection('En Çok Satanlar', _reportData!['products']['bestSellers'] as List<dynamic>, 
                          (item) => item['name'], 
                          (item) => '${item['qty']} adet'
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildListSection('En Çok Tercih Edilen Masa', _reportData!['tables']['topTables'] as List<dynamic>, 
                          (item) => item['name'], 
                          (item) => '${item['orders']} sipariş'
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildListSection('Kategori Satışları', _reportData!['products']['categorySales'] as List<dynamic>, 
                          (item) => item['name'], 
                          (item) => '${(item['rev'] / 100).toStringAsFixed(2)} TL'
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildListSection('Garson Performansı', _reportData!['staff']['waiterSales'] as List<dynamic>, 
                          (item) => item['name'], 
                          (item) => '${(item['rev'] / 100).toStringAsFixed(2)} TL (${item['orders']} sip.)'
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
