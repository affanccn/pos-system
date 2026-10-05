import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/app_states.dart';

class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  bool _isLoading = false;
  List<dynamic> _branches = [];

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/branches');
      setState(() {
        _branches = res.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Şubelerim', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchBranches),
        ],
      ),
      body: _isLoading
          ? const AppLoadingState(message: 'Şubeler yükleniyor...')
          : _branches.isEmpty
              ? const AppEmptyState(
                  message: 'Başka şube bulunamadı.',
                  icon: Icons.storefront_outlined,
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final branch = _branches[index];
                    final isActive = branch['isActive'] ?? true;
                    final createdAt = DateTime.tryParse(branch['createdAt'] ?? '');
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFF38BDF8).withValues(alpha: 0.15) : const Color(0xFF64748B).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.storefront,
                                      color: isActive ? const Color(0xFF38BDF8) : (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                branch['name'] ?? 'İsimsiz Şube',
                                                style: TextStyle(
                                                  color: isActive ? Colors.white : Colors.white54,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                isActive ? 'AKTİF' : 'PASİF',
                                                style: TextStyle(
                                                  color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.link, size: 14, color: Color(0xFF64748B)),
                                            SizedBox(width: 4),
                                            Text(
                                              '${branch['slug']}.restoran.com',
                                              style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        if (createdAt != null) ...[
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Kayıt: ${DateFormat('dd MMM yyyy', 'tr_TR').format(createdAt)}',
                                                style: TextStyle(color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey), fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
