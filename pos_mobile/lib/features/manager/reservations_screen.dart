import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_controller.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<dynamic> _reservations = [];

  @override
  void initState() {
    super.initState();
    _fetchReservations();
  }

  Future<void> _fetchReservations() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/reservations', queryParameters: {
        'date': _selectedDate.toIso8601String(),
      });
      setState(() {
        _reservations = res.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchReservations();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return const Color(0xFFF59E0B);
      case 'CONFIRMED': return const Color(0xFF38BDF8);
      case 'ARRIVED': return const Color(0xFF10B981);
      case 'NO_SHOW': return const Color(0xFFEF4444);
      case 'CANCELLED': return Colors.grey;
      default: return Colors.white;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'PENDING': return 'Bekliyor';
      case 'CONFIRMED': return 'Onaylandı';
      case 'ARRIVED': return 'Geldi';
      case 'NO_SHOW': return 'Gelmedi';
      case 'CANCELLED': return 'İptal';
      default: return status;
    }
  }

  Future<void> _changeStatus(String id, String status) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.patch('/reservations/$id', data: {'status': status});
      _fetchReservations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showAddReservationDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddReservationDialog(
        selectedDate: _selectedDate,
        onAdded: () => _fetchReservations(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rezervasyonlar', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, color: Color(0xFF38BDF8), size: 18),
            label: Text(
              dateFormat.format(_selectedDate),
              style: const TextStyle(color: Color(0xFF38BDF8)),
            ),
            onPressed: _selectDate,
          ),
          IconButton(icon: const Icon(Icons.add, color: Color(0xFF10B981)), onPressed: _showAddReservationDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReservations),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _reservations.isEmpty
              ? const Center(child: Text('Bu tarihte rezervasyon yok.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _reservations.length,
                  itemBuilder: (context, index) {
                    final res = _reservations[index];
                    final rDate = DateTime.parse(res['reservationDate']);
                    final status = res['status'];

                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        iconColor: Colors.white54,
                        collapsedIconColor: Colors.white54,
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
                          child: Text(
                            timeFormat.format(rDate),
                            style: TextStyle(color: _getStatusColor(status), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          res['customerName'] ?? 'Bilinmeyen',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${res['guestCount']} Kişi • ${res['table']?['name'] ?? 'Masa Seçilmedi'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusText(status),
                            style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (res['customerPhone'] != null && res['customerPhone'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone, color: Colors.white54, size: 16),
                                        const SizedBox(width: 8),
                                        Text(res['customerPhone'], style: const TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                if (res['notes'] != null && res['notes'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.note, color: Colors.white54, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(res['notes'], style: const TextStyle(color: Colors.white))),
                                      ],
                                    ),
                                  ),
                                const Divider(color: Color(0xFF334155)),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (status != 'CONFIRMED')
                                      ActionChip(
                                        label: const Text('Onayla', style: TextStyle(color: Color(0xFF38BDF8))),
                                        backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                                        onPressed: () => _changeStatus(res['id'], 'CONFIRMED'),
                                      ),
                                    if (status != 'ARRIVED')
                                      ActionChip(
                                        label: const Text('Geldi', style: TextStyle(color: Color(0xFF10B981))),
                                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                                        onPressed: () => _changeStatus(res['id'], 'ARRIVED'),
                                      ),
                                    if (status != 'NO_SHOW')
                                      ActionChip(
                                        label: const Text('Gelmedi', style: TextStyle(color: Color(0xFFEF4444))),
                                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        onPressed: () => _changeStatus(res['id'], 'NO_SHOW'),
                                      ),
                                    if (status != 'CANCELLED')
                                      ActionChip(
                                        label: const Text('İptal Et', style: TextStyle(color: Colors.grey)),
                                        backgroundColor: Colors.grey.withValues(alpha: 0.1),
                                        onPressed: () => _changeStatus(res['id'], 'CANCELLED'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddReservationDialog extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final VoidCallback onAdded;

  const _AddReservationDialog({required this.selectedDate, required this.onAdded});

  @override
  ConsumerState<_AddReservationDialog> createState() => _AddReservationDialogState();
}

class _AddReservationDialogState extends ConsumerState<_AddReservationDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  int _guestCount = 2;
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final date = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _time.hour,
        _time.minute,
      );

      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post('/reservations', data: {
        'customerName': _nameController.text,
        'customerPhone': _phoneController.text,
        'reservationDate': date.toIso8601String(),
        'guestCount': _guestCount,
        'notes': _notesController.text,
      });
      
      if (mounted) {
        Navigator.pop(context);
        widget.onAdded();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Yeni Rezervasyon', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Müşteri Adı', labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon', labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Kişi Sayısı: $_guestCount', style: const TextStyle(color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white54),
                  onPressed: () {
                    if (_guestCount > 1) setState(() => _guestCount--);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white54),
                  onPressed: () {
                    setState(() => _guestCount++);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Saat', style: TextStyle(color: Colors.white54)),
              trailing: Text(_time.format(context), style: const TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
            ),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notlar', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
