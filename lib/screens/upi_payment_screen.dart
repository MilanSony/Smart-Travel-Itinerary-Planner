import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ride_matching_service.dart';
import '../widgets/payment/upi_app_icon.dart';

enum _PaymentStep { methodSelection, upiPin, processing, success }

class UpiPaymentScreen extends StatefulWidget {
  const UpiPaymentScreen({
    super.key,
    required this.amount,
    this.matchId,
    this.passengerEmail = '',
    this.rideService,
    this.purposeLabel = 'Ride seat booking',
    this.successHint = 'Contact & OTP unlocked',
    this.payeeName,
    this.payerName,
  });

  final String? matchId;
  final double amount;
  final String passengerEmail;
  final RideMatchingService? rideService;
  final String purposeLabel;
  final String successHint;
  final String? payeeName;
  final String? payerName;

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen>
    with TickerProviderStateMixin {
  static const _razorpayBlue = Color(0xFF528FF0);
  static const _razorpayDarkBlue = Color(0xFF1A2B6D);
  static const _successGreen = Color(0xFF21C179);
  static const _pageBg = Color(0xFFF5F7FA);
  static const _demoPin = '1234';

  static const _upiApps = [
    UpiAppType.googlePay,
    UpiAppType.phonePe,
    UpiAppType.paytm,
    UpiAppType.other,
  ];

  _PaymentStep _step = _PaymentStep.methodSelection;
  String _selectedMethod = 'upi';
  UpiAppType? _selectedUpiApp = UpiAppType.phonePe;
  String _pin = '';
  bool _showPin = false;
  String? _methodError;
  String? _pinError;
  late AnimationController _successAnim;
  late AnimationController _shakeAnim;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _successAnim.dispose();
    _shakeAnim.dispose();
    super.dispose();
  }

  String get _amountFormatted => widget.amount.toStringAsFixed(
        widget.amount == widget.amount.roundToDouble() ? 0 : 2,
      );

  String get _amountWithDecimals => widget.amount.toStringAsFixed(2);

  String get _selectedUpiLabel =>
      _selectedUpiApp?.label ?? 'UPI';

  bool get _canContinue =>
      _selectedMethod == 'turbo_upi' ||
      (_selectedMethod == 'upi' && _selectedUpiApp != null);

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      _methodError = null;
    });
  }

  void _selectUpiApp(UpiAppType app) {
    setState(() {
      _selectedMethod = 'upi';
      _selectedUpiApp = app;
      _methodError = null;
    });
  }

  void _onContinue() {
    if (widget.amount <= 0) {
      _showError('Invalid payment amount.');
      return;
    }

    if (!_canContinue) {
      setState(() {
        _methodError = 'Please select a UPI app to continue.';
      });
      return;
    }

    if (_selectedMethod == 'upi' || _selectedMethod == 'turbo_upi') {
      setState(() {
        _methodError = null;
        _pin = '';
        _pinError = null;
        _step = _PaymentStep.upiPin;
      });
      return;
    }

    _showError('Only UPI is available right now.');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[800],
      ),
    );
  }

  Future<void> _shakePinField() async {
    HapticFeedback.mediumImpact();
    await _shakeAnim.forward(from: 0);
    _shakeAnim.reset();
  }

  void _onPinKey(String key) {
    if (_step == _PaymentStep.processing) return;

    setState(() {
      _pinError = null;

      if (key == 'back') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        return;
      }

      if (key == 'submit') {
        _validateAndPay();
        return;
      }

      if (_pin.length >= 4) return;
      if (!RegExp(r'^\d$').hasMatch(key)) return;

      _pin += key;
      if (_pin.length == 4) {
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (mounted && _pin.length == 4 && _step == _PaymentStep.upiPin) {
            _validateAndPay();
          }
        });
      }
    });
  }

  Future<void> _validateAndPay() async {
    if (_pin.length != 4) {
      setState(() => _pinError = 'Enter a 4-digit UPI PIN.');
      await _shakePinField();
      return;
    }

    if (!RegExp(r'^\d{4}$').hasMatch(_pin)) {
      setState(() {
        _pin = '';
        _pinError = 'PIN must contain only numbers.';
      });
      await _shakePinField();
      return;
    }

    if (_pin != _demoPin) {
      setState(() {
        _pin = '';
        _pinError = 'Incorrect PIN. Use 1234 for demo payment.';
      });
      await _shakePinField();
      return;
    }

    await _completePayment();
  }

  Future<void> _completePayment() async {
    if (_step == _PaymentStep.processing) return;
    setState(() {
      _step = _PaymentStep.processing;
      _pinError = null;
    });

    try {
      final rideService = widget.rideService;
      final matchId = widget.matchId;
      if (rideService != null && matchId != null) {
        await rideService.setPassengerPaymentMethod(matchId, 'upi');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      if (rideService != null && matchId != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await rideService.markUpiPaymentSuccess(
          matchId,
          paymentId: 'DUMMY_UPI_$now',
          orderId: 'DUMMY_ORDER_$now',
          signature: 'DUMMY_SIGNATURE',
        );
      }

      if (!mounted) return;
      setState(() => _step = _PaymentStep.success);
      await _successAnim.forward();
    } catch (e) {
      if (!mounted) return;
      final rideService = widget.rideService;
      final matchId = widget.matchId;
      if (rideService != null && matchId != null) {
        await rideService.markUpiPaymentFailed(
          matchId,
          error: e.toString(),
        );
      }
      setState(() {
        _step = _PaymentStep.upiPin;
        _pin = '';
        _pinError = 'Payment failed. Please try again.';
      });
      _showError('Payment failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != _PaymentStep.processing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step == _PaymentStep.upiPin) {
          setState(() {
            _step = _PaymentStep.methodSelection;
            _pin = '';
            _pinError = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        body: Stack(
          children: [
            if (_step == _PaymentStep.methodSelection ||
                _step == _PaymentStep.success)
              _buildMethodSelection(),
            if (_step == _PaymentStep.upiPin ||
                _step == _PaymentStep.processing)
              _buildUpiPinScreen(),
            if (_step == _PaymentStep.processing) _buildProcessingOverlay(),
            if (_step == _PaymentStep.success) _buildSuccessOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Screen 1 ────────────────────────────────────────────────────────────

  Widget _buildMethodSelection() {
    return Column(
      children: [
        _buildRazorpayHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _sectionLabel('Preferred methods'),
              _buildPreferredMethodsCard(),
              const SizedBox(height: 20),
              _sectionLabel('UPI, Cards & Other Methods'),
              _buildOtherMethodsCard(),
              if (_methodError != null) ...[
                const SizedBox(height: 12),
                _errorBanner(_methodError!),
              ],
            ],
          ),
        ),
        _buildStickyFooter(),
      ],
    );
  }

  Widget _buildRazorpayHeader() {
    return Container(
      color: _razorpayBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 4,
        right: 12,
        bottom: 14,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'T',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Genie',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.verified, size: 13, color: Colors.green[200]),
                    const SizedBox(width: 4),
                    Text(
                      'Razorpay Trusted Business',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.verified_user_outlined,
              color: Colors.white.withValues(alpha: 0.92), size: 21),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _borderedCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildPreferredMethodsCard() {
    return _borderedCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3FC5), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TURBO UPI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
        _selectableRow(
          selected: _selectedMethod == 'turbo_upi',
          onTap: () => _selectMethod('turbo_upi'),
          leading: _iciciLogo(size: 28),
          title: Row(
            children: [
              const Text(
                'ICICI Bank - XXXX 4411',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              const UpiBrandBadge(height: 18),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          footer: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _razorpayBlue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.white, size: 10),
                SizedBox(width: 4),
                Text(
                  'GET 5% CASHBACK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _selectableRow(
          selected: _selectedMethod == 'netbanking',
          onTap: () => _selectMethod('netbanking'),
          leading: _iciciLogo(size: 28, withBuilding: true),
          title: const Text(
            'ICICI Bank - Netbanking',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildOtherMethodsCard() {
    return _borderedCard(
      children: [
        _buildUpiSection(),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _methodRow(
          icon: Icons.credit_card_outlined,
          title: 'Pay using card',
          subtitle: 'All Card Supported',
          selected: _selectedMethod == 'card',
          onTap: () => _selectMethod('card'),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _methodRow(
          icon: Icons.payments_outlined,
          title: 'Cash On delivery',
          subtitle: 'Pay at the time of delivery',
          selected: _selectedMethod == 'cod',
          onTap: () => _selectMethod('cod'),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _methodRow(
          icon: Icons.account_balance_outlined,
          title: 'Net banking',
          subtitle: 'All Indian banks',
          selected: _selectedMethod == 'netbanking',
          onTap: () => _selectMethod('netbanking'),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _methodRow(
          icon: Icons.calendar_month_outlined,
          title: 'EMI',
          subtitle: 'Card, EarlySalary and more..',
          badge: 'NO COST EMI AVAILABLE',
          selected: _selectedMethod == 'emi',
          onTap: () => _selectMethod('emi'),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        _methodRow(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Wallet',
          subtitle: 'Paytm, PhonePe, Amazon Pay & more',
          selected: _selectedMethod == 'wallet',
          onTap: () => _selectMethod('wallet'),
        ),
      ],
    );
  }

  Widget _buildUpiSection() {
    final upiSelected = _selectedMethod == 'upi';

    return Material(
      color: upiSelected
          ? _razorpayBlue.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _selectMethod('upi'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UpiBrandBadge(height: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UPI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Pay with one-step UPI, apps or choose other',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (upiSelected)
                    const Icon(Icons.check_circle,
                        color: _razorpayBlue, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _upiApps.map((app) {
                  final selected =
                      upiSelected && _selectedUpiApp == app;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectUpiApp(app),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? _razorpayBlue
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: UpiAppIcon(app: app, size: 46),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            app.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? _razorpayBlue
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectableRow({
    required bool selected,
    required VoidCallback onTap,
    required Widget leading,
    required Widget title,
    Widget? trailing,
    Widget? footer,
  }) {
    return Material(
      color: selected
          ? _razorpayBlue.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (footer != null) footer,
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodRow({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? _razorpayBlue.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 24, color: const Color(0xFF374151)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _successGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iciciLogo({required double size, bool withBuilding = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      alignment: Alignment.center,
      child: Icon(
        withBuilding ? Icons.account_balance : Icons.savings_outlined,
        size: size * 0.55,
        color: const Color(0xFFE87722),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '₹ $_amountFormatted',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: _showAmountDetails,
                child: const Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 11,
                    color: _razorpayBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _canContinue ? _onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _razorpayBlue,
                disabledBackgroundColor: _razorpayBlue.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAmountDetails() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _detailRow(widget.purposeLabel, '₹ $_amountFormatted'),
            if (widget.payerName != null && widget.payeeName != null) ...[
              const SizedBox(height: 6),
              Text(
                '${widget.payerName} pays ${widget.payeeName}',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            _detailRow('Platform fee', '₹ 0'),
            const Divider(height: 28),
            _detailRow('Total payable', '₹ $_amountFormatted', bold: true),
            const SizedBox(height: 12),
            Text(
              widget.successHint,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Screen 2: UPI PIN ───────────────────────────────────────────────────

  Widget _buildUpiPinScreen() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: _step == _PaymentStep.processing
                        ? null
                        : () => setState(() {
                              _step = _PaymentStep.methodSelection;
                              _pin = '';
                              _pinError = null;
                            }),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ICICI Bank',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.payerName != null && widget.payeeName != null
                            ? '${widget.payerName} \u2192 ${widget.payeeName}'
                            : 'Paying via $_selectedUpiLabel',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const UpiBrandBadge(height: 24),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: _razorpayDarkBlue,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.payeeName != null
                    ? 'To ${widget.payeeName}'
                    : 'XXXXXX9238',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '₹ $_amountWithDecimals',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ENTER UPI PIN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[700],
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _showPin = !_showPin),
                      child: Row(
                        children: [
                          Icon(
                            _showPin
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 15,
                            color: _razorpayBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showPin ? 'HIDE' : 'SHOW',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _razorpayBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final offset = sin(_shakeAnim.value * pi * 6) * 8;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 11),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled && !_showPin
                              ? Colors.black87
                              : Colors.transparent,
                          border: Border.all(
                            color: _pinError != null
                                ? Colors.red[400]!
                                : filled
                                    ? Colors.black87
                                    : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _showPin && filled
                            ? Text(
                                _pin[i],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      );
                    }),
                  ),
                ),
                if (_pinError != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _pinError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Demo PIN: 1234',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
                const Spacer(),
                _buildNumericKeypad(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumericKeypad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['back', '0', 'submit'],
    ];

    return Container(
      color: const Color(0xFFEFEFEF),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 6,
        top: 6,
      ),
      child: Column(
        children: keys.map((row) {
          return Row(
            children: row.map((key) => Expanded(child: _buildKey(key))).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    if (key == 'back') {
      return _keyButton(
        onTap: () => _onPinKey('back'),
        child: const Icon(Icons.backspace_outlined, size: 24),
      );
    }
    if (key == 'submit') {
      final enabled = _pin.length == 4;
      return _keyButton(
        onTap: enabled ? () => _onPinKey('submit') : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled ? _razorpayBlue : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.check_rounded,
            color: enabled ? Colors.white : Colors.grey.shade500,
            size: 24,
          ),
        ),
      );
    }
    return _keyButton(
      onTap: () => _onPinKey(key),
      child: Text(
        key,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
      ),
    );
  }

  Widget _keyButton({required VoidCallback? onTap, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: 58, child: Center(child: child)),
      ),
    );
  }

  // ── Overlays ────────────────────────────────────────────────────────────

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedUpiApp != null)
              UpiAppIcon(app: _selectedUpiApp!, size: 52),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: _razorpayBlue),
            const SizedBox(height: 16),
            Text(
              'Processing via $_selectedUpiLabel...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Please wait',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.48 * _successAnim.value),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.62,
              child: Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.of(context).size.height *
                      0.62 *
                      (1 - _successAnim.value),
                ),
                child: Container(
                  color: _successGreen,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_rounded,
                          color: _successGreen,
                          size: 48,
                          weight: 700,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Payment successful',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹ $_amountFormatted paid via $_selectedUpiLabel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.successHint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _successGreen,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}