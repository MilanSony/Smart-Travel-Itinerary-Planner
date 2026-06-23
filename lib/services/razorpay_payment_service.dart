import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayPaymentSuccess {
  final String paymentId;
  final String? orderId;
  final String? signature;

  const RazorpayPaymentSuccess({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });
}

class RazorpayPaymentFailure {
  final int? code;
  final String message;

  const RazorpayPaymentFailure({required this.code, required this.message});
}

class RazorpayPaymentService {
  RazorpayPaymentService() : _razorpay = Razorpay();

  final Razorpay _razorpay;

  Future<RazorpayPaymentSuccess> openCheckout({
    required int amountPaise,
    required String name,
    required String description,
    required String prefillEmail,
    String? prefillContact,
    String? orderId,
  }) {
    final completer = Completer<RazorpayPaymentSuccess>();

    void clearHandlers() {
      _razorpay.clear();
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) {
      if (!completer.isCompleted) {
        completer.complete(RazorpayPaymentSuccess(
          paymentId: response.paymentId ?? '',
          orderId: response.orderId,
          signature: response.signature,
        ));
      }
      clearHandlers();
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
      if (!completer.isCompleted) {
        completer.completeError(RazorpayPaymentFailure(
          code: response.code,
          message: response.message ?? 'Payment failed',
        ));
      }
      clearHandlers();
    });

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse response) {
      if (!completer.isCompleted) {
        completer.completeError(const RazorpayPaymentFailure(
          code: null,
          message: 'External wallet selected. Please complete payment.',
        ));
      }
      clearHandlers();
    });

    final options = <String, Object?>{
      'key': const String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: ''),
      'amount': amountPaise,
      'name': name,
      'description': description,
      'prefill': {
        'contact': prefillContact ?? '',
        'email': prefillEmail,
      },
      'method': {
        'upi': true,
        'card': false,
        'netbanking': false,
        'wallet': false,
        'emi': false,
        'paylater': false,
      },
      'theme': {'color': '#1E3A8A'},
    };

    if (orderId != null && orderId.isNotEmpty) {
      options['order_id'] = orderId;
    }

    _razorpay.open(options);
    return completer.future;
  }
}

