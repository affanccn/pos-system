import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String _pin = '';

  void _onKeyPress(String val) {
    if (_pin.length < 4) {
      setState(() => _pin += val);
      if (_pin.length == 4) {
        debugPrint('--> 4 hane tamamlandı, gönderiliyor: $_pin');
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _clearPin() {
    setState(() => _pin = '');
  }

  Future<void> _submitPin() async {
    final currentPin = _pin;
    final success = await ref.read(authProvider).loginWithPin(currentPin);
    if (!mounted) return;
    if (!success) {
      _clearPin();
    }
  }

  Widget _buildKey(String label, {VoidCallback? onTap, Color? color}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: InkWell(
          onTap: onTap ?? () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: color ?? Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = ref.watch(authProvider);
    final authState = authController.state;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.point_of_sale_rounded, size: 54, color: Color(0xFF38BDF8)),
                  SizedBox(height: 12),
                  Text(
                    'Artisan Bistro POS',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Giriş yapmak için 4 haneli PIN girin',
                    style: TextStyle(fontSize: 14, color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
                  ),
                  SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? const Color(0xFF38BDF8) : Colors.transparent,
                          border: Border.all(
                            color: isFilled ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 20),

                  if (authState.isLoading)
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                    )
                  else if (authState.errorMessage != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        authState.errorMessage!,
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SizedBox(height: 24),

                  SizedBox(height: 8),

                  Row(children: [_buildKey('1'), _buildKey('2'), _buildKey('3')]),
                  Row(children: [_buildKey('4'), _buildKey('5'), _buildKey('6')]),
                  Row(children: [_buildKey('7'), _buildKey('8'), _buildKey('9')]),
                  Row(
                    children: [
                      _buildKey('C', onTap: _clearPin, color: Theme.of(context).dividerColor),
                      _buildKey('0'),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: InkWell(
                            onTap: _onBackspace,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 72,
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF475569), width: 1.5),
                              ),
                              child: Center(
                                child: Icon(Icons.backspace_outlined, color: Theme.of(context).colorScheme.onSurface, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}