import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ride_matching_service.dart';

enum _UpiPaymentStep {
  amountEntry,
  processing,
  success,
}

/// Dummy Razorpay-like UPI screen (no real gateway integration yet).
///
/// Goal:
/// - Show UPI payment UI like a gateway
/// - On "Pay" => mark dummy UPI payment as successful in Firestore
/// - Unlock contact/OTP only after success
class UpiPaymentScreen extends StatefulWidget {
  const UpiPaymentScreen({
    super.key,
    required this.matchId,
    required this.amount,
    required this.passengerEmail,
    required this.rideService,
  });

  final String matchId;
  final double amount;
  final String passengerEmail;
  final RideMatchingService rideService;

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  _UpiPaymentStep _step = _UpiPaymentStep.amountEntry;
  String _selectedUpiApp = 'PhonePe';

  Future<void> _simulatePayment() async {
    if (_step == _UpiPaymentStep.processing) return;

    setState(() => _step = _UpiPaymentStep.processing);

    // Simulate network payment processing delay
    await Future<void>.delayed(const Duration(seconds: 2));

    final now = DateTime.now().millisecondsSinceEpoch;
    final dummyPaymentId = 'DUMMY_UPI_$now';
    final dummyOrderId = 'DUMMY_ORDER_$now';

    await widget.rideService.markUpiPaymentSuccess(
      widget.matchId,
      paymentId: dummyPaymentId,
      orderId: dummyOrderId,
      signature: 'DUMMY_SIGNATURE',
    );

    if (!mounted) return;
    setState(() => _step = _UpiPaymentStep.success);
  }

  @override
  Widget build(BuildContext context) {
    final amountText = widget.amount.toStringAsFixed(0);

    return WillPopScope(
      onWillPop: () async {
        // If payment already succeeded, allow back to close the screen.
        // If not succeeded yet, this means "Cancel" (contact stays locked).
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('UPI Payment'),
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _step == _UpiPaymentStep.amountEntry
                        ? _buildAmountEntry(amountText)
                        : _step == _UpiPaymentStep.processing
                            ? _buildProcessing()
                            : _buildSuccess(amountText),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountEntry(String amountText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pay using UPI',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Amount: ₹$amountText',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose UPI app',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedUpiApp,
          items: const [
            DropdownMenuItem(value: 'PhonePe', child: Text('PhonePe')),
            DropdownMenuItem(value: 'Google Pay', child: Text('Google Pay')),
            DropdownMenuItem(value: 'Paytm', child: Text('Paytm')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedUpiApp = v);
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Confirm and pay. After payment, contact & OTP will be unlocked.',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _simulatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Pay & Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 8),
        CircularProgressIndicator(),
        SizedBox(height: 14),
        Text(
          'Processing UPI payment...',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text(
          'This is dummy flow for now (no real gateway).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccess(String amountText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 52, color: Colors.green),
        const SizedBox(height: 10),
        const Text(
          'Payment Successful',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '₹$amountText paid via UPI (dummy).',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: const Text(
            'Contact number and OTP are unlocked in Find Rides.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

