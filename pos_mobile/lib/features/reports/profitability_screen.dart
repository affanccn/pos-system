import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';

class ProfitabilityScreen extends ConsumerStatefulWidget {
  const ProfitabilityScreen({super.key});

  @override
  ConsumerState<ProfitabilityScreen> createState() => _ProfitabilityScreenState();
}

class _ProfitabilityScreenState extends ConsumerState<ProfitabilityScreen> with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _data;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get('/reports/profitability', queryParameters: {
        'startDate': DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0).toIso8601String(),
        'endDate': DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toIso8601String(),
      });
      setState(() {
        _data = res.data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
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

  String _formatCurrency(num cents) {
    return '${(cents / 100).toStringAsFixed(2)} ₺';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Maliyet & Kârlılık', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.date_range, color: Color(0xFF38BDF8), size: 18),
            label: Text(
              '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
            ),
            onPressed: _selectDateRange,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReport),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Özet'),
            Tab(text: 'Ürünler'),
            Tab(text: 'Kategoriler'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _data == null
              ? const Center(child: Text('Veri yok', style: TextStyle(color: Colors.white54)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(),
                    _buildProductsTab(),
                    _buildCategoriesTab(),
                  ],
                ),
    );
  }

  // ─── ÖZET TAB ───
  Widget _buildSummaryTab() {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final categories = (_data!['categoryProfits'] as List<dynamic>?) ?? [];
    final lowMargin = (_data!['lowMarginProducts'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genel Özet Kartları
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('Toplam Ciro', _formatCurrency(summary['totalRevenueCents'] ?? 0), Icons.payments, const Color(0xFF38BDF8)),
              _buildStatCard('Toplam Maliyet', _formatCurrency(summary['totalCostCents'] ?? 0), Icons.receipt_long, const Color(0xFFEF4444)),
              _buildStatCard('Brüt Kâr', _formatCurrency(summary['totalProfitCents'] ?? 0), Icons.trending_up, const Color(0xFF10B981)),
              _buildStatCard('Brüt Marj', '% ${summary['overallMarginPercent'] ?? 0}', Icons.pie_chart, const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 8),
          // Alt satır: Ürün sayıları
          Row(
            children: [
              Expanded(child: _buildMiniCard('Toplam Ürün', '${summary['productCount'] ?? 0}', Icons.inventory_2, Colors.white70)),
              const SizedBox(width: 10),
              Expanded(child: _buildMiniCard('Satılan Ürün', '${summary['soldProductCount'] ?? 0}', Icons.shopping_cart, Colors.white70)),
            ],
          ),
          const SizedBox(height: 24),

          // Kategori Kârlılık Pie Chart
          if (categories.isNotEmpty) ...[
            const Text('Kategori Bazlı Kârlılık', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _buildCategoryPieSections(categories),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: categories.take(6).toList().asMap().entries.map((e) {
                final color = _pieColors[e.key % _pieColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: color),
                    const SizedBox(width: 4),
                    Text(e.value['categoryName'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Düşük Marjlı Ürünler
          if (lowMargin.isNotEmpty) ...[
            const Text('⚠ Düşük Marjlı Ürünler', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lowMargin.take(5).map((p) => _buildLowMarginCard(p)),
          ],
        ],
      ),
    );
  }

  // ─── ÜRÜNLER TAB ───
  Widget _buildProductsTab() {
    final products = (_data!['products'] as List<dynamic>?) ?? [];
    if (products.isEmpty) {
      return const Center(child: Text('Satış verisi bulunamadı.', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        final margin = (p['grossMarginPercent'] ?? 0).toDouble();
        final marginColor = margin >= 60
            ? const Color(0xFF10B981)
            : margin >= 40
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            iconColor: Colors.white54,
            collapsedIconColor: Colors.white54,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    p['productName'] ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: marginColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '% $margin',
                    style: TextStyle(color: marginColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${p['categoryName']}  •  Satış: ${p['totalSoldQty']}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    _detailRow('Satış Fiyatı', _formatCurrency(p['priceCents'] ?? 0)),
                    _detailRow('Reçete Maliyeti', _formatCurrency(p['recipeCostCents'] ?? 0)),
                    const Divider(color: Color(0xFF334155)),
                    _detailRow('Toplam Ciro', _formatCurrency(p['totalRevenueCents'] ?? 0)),
                    _detailRow('Toplam Maliyet', _formatCurrency(p['totalCostCents'] ?? 0), color: const Color(0xFFEF4444)),
                    _detailRow('Brüt Kâr', _formatCurrency(p['grossProfitCents'] ?? 0), color: const Color(0xFF10B981)),
                    if ((p['complimentaryQty'] ?? 0) > 0)
                      _detailRow('İkram', '${p['complimentaryQty']} adet', color: const Color(0xFFA78BFA)),
                    if ((p['returnedQty'] ?? 0) > 0)
                      _detailRow('İade', '${p['returnedQty']} adet', color: const Color(0xFFF43F5E)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── KATEGORİLER TAB ───
  Widget _buildCategoriesTab() {
    final categories = (_data!['categoryProfits'] as List<dynamic>?) ?? [];
    if (categories.isEmpty) {
      return const Center(child: Text('Kategori verisi bulunamadı.', style: TextStyle(color: Colors.white54)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bar Chart
          const Text('Kategori Kâr Karşılaştırması', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: categories.fold<double>(0, (max, c) {
                  final rev = ((c['totalRevenueCents'] ?? 0) / 100).toDouble();
                  return rev > max ? rev : max;
                }) * 1.2,
                barGroups: categories.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: ((c['totalRevenueCents'] ?? 0) / 100).toDouble(),
                        color: const Color(0xFF38BDF8),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: ((c['totalCostCents'] ?? 0) / 100).toDouble(),
                        color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text('${v.toInt()} ₺', style: const TextStyle(color: Colors.white54, fontSize: 9)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx >= categories.length) return const SizedBox.shrink();
                    final name = categories[idx]['categoryName'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(name.length > 6 ? '${name.substring(0, 6)}...' : name, style: const TextStyle(color: Colors.white54, fontSize: 9)),
                    );
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white12, strokeWidth: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 4),
              const Text('Ciro', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, color: const Color(0xFFEF4444)),
              const SizedBox(width: 4),
              const Text('Maliyet', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 24),

          // Kategori listesi
          ...categories.map((c) {
            final margin = (c['grossMarginPercent'] ?? 0).toDouble();
            final marginColor = margin >= 60 ? const Color(0xFF10B981) : margin >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c['categoryName'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: marginColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Marj: % $margin', style: TextStyle(color: marginColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _miniStat('Ciro', _formatCurrency(c['totalRevenueCents'] ?? 0), const Color(0xFF38BDF8))),
                        Expanded(child: _miniStat('Maliyet', _formatCurrency(c['totalCostCents'] ?? 0), const Color(0xFFEF4444))),
                        Expanded(child: _miniStat('Kâr', _formatCurrency(c['grossProfitCents'] ?? 0), const Color(0xFF10B981))),
                        Expanded(child: _miniStat('Adet', '${c['totalQty'] ?? 0}', Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── HELPER WİDGETLER ───

  static const _pieColors = [
    Color(0xFF38BDF8), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFFA78BFA), Color(0xFFF43F5E), Color(0xFF14B8A6), Color(0xFF6366F1),
  ];

  List<PieChartSectionData> _buildCategoryPieSections(List<dynamic> categories) {
    final total = categories.fold<double>(0, (s, c) => s + ((c['totalRevenueCents'] ?? 0) as num).toDouble());
    if (total == 0) return [];

    return categories.take(6).toList().asMap().entries.map((e) {
      final i = e.key;
      final c = e.value;
      final rev = ((c['totalRevenueCents'] ?? 0) as num).toDouble();
      final pct = (rev / total) * 100;
      return PieChartSectionData(
        value: rev,
        color: _pieColors[i % _pieColors.length],
        radius: 50,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }).toList();
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowMarginCard(dynamic p) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          child: const Icon(Icons.warning_amber, color: Color(0xFFF59E0B), size: 20),
        ),
        title: Text(p['productName'] ?? '', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Fiyat: ${_formatCurrency(p['priceCents'] ?? 0)} • Maliyet: ${_formatCurrency(p['recipeCostCents'] ?? 0)}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        trailing: Text(
          '% ${p['grossMarginPercent'] ?? 0}',
          style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
