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
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Maliyet & Kârlılık', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.date_range, color: Color(0xFF38BDF8), size: 18),
            label: Text(
              '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
            ),
            onPressed: _selectDateRange,
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchReport),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Özet'),
            Tab(text: 'Ürünler'),
            Tab(text: 'Kategoriler'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _data == null
              ? Center(child: Text('Veri yok', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))))
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

  Widget _buildSummaryTab() {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final categories = (_data!['categoryProfits'] as List<dynamic>?) ?? [];
    final lowMargin = (_data!['lowMarginProducts'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMiniCard('Toplam Ürün', '${summary['productCount'] ?? 0}', Icons.inventory_2, Colors.white70)),
              SizedBox(width: 10),
              Expanded(child: _buildMiniCard('Satılan Ürün', '${summary['soldProductCount'] ?? 0}', Icons.shopping_cart, Colors.white70)),
            ],
          ),
          SizedBox(height: 24),

          if (categories.isNotEmpty) ...[
            Text('Kategori Bazlı Kârlılık', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
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
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: categories.take(6).toList().asMap().entries.map((e) {
                final color = _pieColors[e.key % _pieColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: color),
                    SizedBox(width: 4),
                    Text(e.value['categoryName'] ?? '', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
            SizedBox(height: 24),
          ],

          if (lowMargin.isNotEmpty) ...[
            Text('⚠ Düşük Marjlı Ürünler', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...lowMargin.take(5).map((p) => _buildLowMarginCard(p)),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    final products = (_data!['products'] as List<dynamic>?) ?? [];
    if (products.isEmpty) {
      return Center(child: Text('Satış verisi bulunamadı.', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))));
    }

    return ListView.builder(
      padding: EdgeInsets.all(12),
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
          color: Theme.of(context).cardColor,
          margin: EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            iconColor: Colors.white54,
            collapsedIconColor: Colors.white54,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    p['productName'] ?? '',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 12),
            ),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    _detailRow('Satış Fiyatı', _formatCurrency(p['priceCents'] ?? 0)),
                    _detailRow('Reçete Maliyeti', _formatCurrency(p['recipeCostCents'] ?? 0)),
                    Divider(color: Theme.of(context).dividerColor),
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

  Widget _buildCategoriesTab() {
    final categories = (_data!['categoryProfits'] as List<dynamic>?) ?? [];
    if (categories.isEmpty) {
      return Center(child: Text('Kategori verisi bulunamadı.', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54))));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kategori Kâr Karşılaştırması', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
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
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text('${v.toInt()} ₺', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 9)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx >= categories.length) return const SizedBox.shrink();
                    final name = categories[idx]['categoryName'] ?? '';
                    return Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(name.length > 6 ? '${name.substring(0, 6)}...' : name, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 9)),
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
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10, color: const Color(0xFF38BDF8)),
              SizedBox(width: 4),
              Text('Ciro', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 11)),
              SizedBox(width: 16),
              Container(width: 10, height: 10, color: const Color(0xFFEF4444)),
              SizedBox(width: 4),
              Text('Maliyet', style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 11)),
            ],
          ),
          SizedBox(height: 24),

          ...categories.map((c) {
            final margin = (c['grossMarginPercent'] ?? 0).toDouble();
            final marginColor = margin >= 60 ? const Color(0xFF10B981) : margin >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
            return Card(
              color: Theme.of(context).cardColor,
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c['categoryName'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: marginColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Marj: % $margin', style: TextStyle(color: marginColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
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
        titleStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }).toList();
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2),
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
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 10)),
                Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowMarginCard(dynamic p) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          child: Icon(Icons.warning_amber, color: Color(0xFFF59E0B), size: 20),
        ),
        title: Text(p['productName'] ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Fiyat: ${_formatCurrency(p['priceCents'] ?? 0)} • Maliyet: ${_formatCurrency(p['recipeCostCents'] ?? 0)}',
          style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 11),
        ),
        trailing: Text(
          '% ${p['grossMarginPercent'] ?? 0}',
          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 13)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.54), fontSize: 10)),
        SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }
}
