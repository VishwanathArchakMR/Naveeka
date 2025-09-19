// lib/features/checkout/providers/checkout_providers.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/config/constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';

/// Supported payment methods.
enum PaymentMethod { card, upi, netbanking }

@immutable
class TravelerData {
  final String name;
  final String email;
  final String phone;

  const TravelerData({
    this.name = '',
    this.email = '',
    this.phone = '',
  });

  bool get isValid {
    final emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final phoneRe = RegExp(r'^[0-9+\-\s]{7,20}$');
    if (name.trim().length < 2) return false;
    if (!emailRe.hasMatch(email.trim())) return false;
    if (!phoneRe.hasMatch(phone.trim())) return false;
    return true;
  }

  TravelerData copyWith({
    String? name,
    String? email,
    String? phone,
  }) {
    return TravelerData(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      };
}

@immutable
class PaymentData {
  final PaymentMethod method;

  // Card
  final String cardNumber; // spaced "XXXX XXXX ..."
  final String cardHolder;
  final String cardCvv;
  final String cardExpiry; // "MM/YY"

  // UPI
  final String upiId;

  // Netbanking
  final String bank;

  const PaymentData({
    this.method = PaymentMethod.card,
    this.cardNumber = '',
    this.cardHolder = '',
    this.cardCvv = '',
    this.cardExpiry = '',
    this.upiId = '',
    this.bank = '',
  });

  bool get isValid {
    switch (method) {
      case PaymentMethod.card:
        final number = cardNumber.replaceAll(' ', '');
        if (number.length < 12) return false;
        if (cardHolder.trim().length < 2) return false;
        if (cardCvv.trim().length < 3) return false;
        final exp = cardExpiry.trim();
        if (exp.length != 5 || exp != '/') return false;
        final mm = int.tryParse(exp.substring(0, 2));
        final yy = int.tryParse(exp.substring(3, 5));
        if (mm == null || yy == null || mm < 1 || mm > 12) return false;
        return true;
      case PaymentMethod.upi:
        final upi = upiId.trim();
        final re = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');
        return re.hasMatch(upi);
      case PaymentMethod.netbanking:
        return bank.trim().isNotEmpty;
    }
  }

  PaymentData copyWith({
    PaymentMethod? method,
    String? cardNumber,
    String? cardHolder,
    String? cardCvv,
    String? cardExpiry,
    String? upiId,
    String? bank,
  }) {
    return PaymentData(
      method: method ?? this.method,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolder: cardHolder ?? this.cardHolder,
      cardCvv: cardCvv ?? this.cardCvv,
      cardExpiry: cardExpiry ?? this.cardExpiry,
      upiId: upiId ?? this.upiId,
      bank: bank ?? this.bank,
    );
  }

  Map<String, dynamic> toJson() {
    final base = {'method': method.name};
    switch (method) {
      case PaymentMethod.card:
        return {
          ...base,
          'cardNumber': cardNumber.replaceAll(' ', ''),
          'cardHolder': cardHolder.trim(),
          'cardCvv': cardCvv.trim(),
          'cardExpiry': cardExpiry.trim(),
        };
      case PaymentMethod.upi:
        return {
          ...base,
          'upiId': upiId.trim(),
        };
      case PaymentMethod.netbanking:
        return {
          ...base,
          'bank': bank.trim(),
        };
    }
  }
}

@immutable
class CheckoutState {
  final Map<String, dynamic>? booking; // passed-in selection
  final TravelerData traveler;
  final PaymentData payment;
  final bool agreed;
  final bool processing;
  final AppException? error;
  final Map<String, dynamic>? lastOrder; // server response

  const CheckoutState({
    this.booking,
    this.traveler = const TravelerData(),
    this.payment = const PaymentData(),
    this.agreed = true,
    this.processing = false,
    this.error,
    this.lastOrder,
  });

  CheckoutState copyWith({
    Map<String, dynamic>? booking,
    TravelerData? traveler,
    PaymentData? payment,
    bool? agreed,
    bool? processing,
    AppException? error,
    Map<String, dynamic>? lastOrder,
    bool clearError = false,
  }) {
    return CheckoutState(
      booking: booking ?? this.booking,
      traveler: traveler ?? this.traveler,
      payment: payment ?? this.payment,
      agreed: agreed ?? this.agreed,
      processing: processing ?? this.processing,
      error: clearError ? null : (error ?? this.error),
      lastOrder: lastOrder ?? this.lastOrder,
    );
  }

  Map<String, dynamic> buildPayload() {
    return <String, dynamic>{
      'booking': booking ?? const <String, dynamic>{},
      'traveler': traveler.toJson(),
      'payment': payment.toJson(),
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

/// StateNotifier holding the checkout flow state and submission logic. [Riverpod]
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this.ref, {Map<String, dynamic>? initialBooking})
      : super(CheckoutState(booking: initialBooking));

  final Ref ref;

  // Mutators
  void setBooking(Map<String, dynamic>? booking) {
    state = state.copyWith(booking: booking, clearError: true);
  }

  void setTraveler({
    String? name,
    String? email,
    String? phone,
  }) {
    state = state.copyWith(
      traveler: state.traveler.copyWith(
        name: name,
        email: email,
        phone: phone,
      ),
      clearError: true,
    );
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(payment: state.payment.copyWith(method: method), clearError: true);
  }

  void setCard({
    String? number,
    String? holder,
    String? cvv,
    String? expiry,
  }) {
    state = state.copyWith(
      payment: state.payment.copyWith(
        cardNumber: number,
        cardHolder: holder,
        cardCvv: cvv,
        cardExpiry: expiry,
      ),
      clearError: true,
    );
  }

  void setUpi({String? upiId}) {
    state = state.copyWith(payment: state.payment.copyWith(upiId: upiId), clearError: true);
  }

  void setBank({String? bank}) {
    state = state.copyWith(payment: state.payment.copyWith(bank: bank), clearError: true);
  }

  void setAgreed(bool value) {
    state = state.copyWith(agreed: value, clearError: true);
  }

  bool validateTraveler() => state.traveler.isValid;

  bool validatePayment() => state.payment.isValid && state.agreed;

  /// Submit the checkout to the backend; returns ApiResult with the server response.
  Future<ApiResult<Map<String, dynamic>>> submit() async {
    if (!validateTraveler()) {
      return ApiResult.fail(
        const AppException(message: 'Invalid traveler details', safeMessage: 'Please check traveler details.'),
      );
    }
    if (!validatePayment()) {
      return ApiResult.fail(
        const AppException(message: 'Invalid payment details', safeMessage: 'Please check payment details and terms.'),
      );
    }

    state = state.copyWith(processing: true, clearError: true);

    final payload = state.buildPayload();
    final dio = DioClient.instance.dio;

    final result = await ApiResult.guardFuture<Map<String, dynamic>>(() async {
      final res = await dio.post(AppConstants.apiBookings, data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });

    return result.fold(
      onSuccess: (data) {
        state = state.copyWith(processing: false, lastOrder: data, clearError: true);
        return ApiResult.ok(data);
      },
      onError: (err) {
        state = state.copyWith(processing: false, error: err);
        return ApiResult.fail(err);
      },
    );
  }
}

/// Family provider so screens can inject the optional booking payload.
final checkoutProvider = StateNotifierProvider.family<CheckoutNotifier, CheckoutState, Map<String, dynamic>?>(
  (ref, initialBooking) => CheckoutNotifier(ref, initialBooking: initialBooking),
);
