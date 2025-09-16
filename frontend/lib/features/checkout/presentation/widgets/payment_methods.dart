// lib/features/checkout/presentation/widgets/payment_methods.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Segmented payment methods with validated fields for Card and UPI, and a bank selector for Netbanking. [1]
class PaymentMethods extends StatelessWidget {
  const PaymentMethods({
    super.key,
    required this.method,               // 'card' | 'upi' | 'netbanking'
    required this.onMethodChanged,
    // Terms/consent
    required this.agreed,
    required this.onToggleAgree,
    // Card form
    this.cardFormKey,
    this.cardNumberCtrl,
    this.cardHolderCtrl,
    this.cardCvvCtrl,
    this.cardExpiryCtrl,
    this.cardEnabled = true,
    // UPI
    this.upiCtrl,
    // Netbanking
    this.bankNames = const <String>['HDFC', 'ICICI', 'SBI', 'Axis', 'Kotak'],
    this.selectedBank,
    this.onBankChanged,
  });

  final String method;
  final ValueChanged<String> onMethodChanged;

  final bool agreed;
  final ValueChanged<bool> onToggleAgree;

  // Card fields
  final GlobalKey<FormState>? cardFormKey;
  final TextEditingController? cardNumberCtrl;
  final TextEditingController? cardHolderCtrl;
  final TextEditingController? cardCvvCtrl;
  final TextEditingController? cardExpiryCtrl;
  final bool cardEnabled;

  // UPI
  final TextEditingController? upiCtrl;

  // Netbanking
  final List<String> bankNames;
  final String? selectedBank;
  final ValueChanged<String?>? onBankChanged;

  @override
  Widget build(BuildContext context) {
    final showCard = method == 'card';
    final showUpi = method == 'upi';
    final showNet = method == 'netbanking';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
            ButtonSegment<String>(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code)),
            ButtonSegment<String>(value: 'netbanking', label: Text('Netbanking'), icon: Icon(Icons.account_balance)),
          ],
          selected: {method},
          onSelectionChanged: (s) => onMethodChanged(s.first),
        ), // M3 segmented buttons for limited options [1][8]
        const SizedBox(height: 16),

        if (showCard) _CardForm(
          formKey: cardFormKey,
          numberCtrl: cardNumberCtrl,
          holderCtrl: cardHolderCtrl,
          cvvCtrl: cardCvvCtrl,
          expiryCtrl: cardExpiryCtrl,
          enabled: cardEnabled,
        ),

        if (showUpi) ...[
          TextFormField(
            controller: upiCtrl,
            enabled: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'username@bank',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            validator: _upiValidator,
          ), // Simple UPI format check via validator [13]
        ],

        if (showNet) ...[
          DropdownButtonFormField<String>(
            value: selectedBank,
            items: bankNames
                .map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                .toList(growable: false),
            onChanged: onBankChanged,
            decoration: const InputDecoration(
              labelText: 'Select bank',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Please select a bank' : null,
          ), // Basic bank selector for netbanking [13]
        ],

        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: agreed,
          onChanged: (v) => onToggleAgree(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I agree to the Terms & Privacy Policy'),
        ), // Consent checkbox kept independent from method [13]
      ],
    );
  }

  // --------- Validators ---------

  static String? _upiValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'UPI ID is required';
    // very lenient pattern: local@handle
    final re = RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$');
    if (!re.hasMatch(s)) return 'Enter a valid UPI ID';
    return null;
  } // Form/validator pattern per Flutter docs [13]
}

// ---------------- Card form ----------------

class _CardForm extends StatelessWidget {
  const _CardForm({
    required this.formKey,
    required this.numberCtrl,
    required this.holderCtrl,
    required this.cvvCtrl,
    required this.expiryCtrl,
    required this.enabled,
  });

  final GlobalKey<FormState>? formKey;
  final TextEditingController? numberCtrl;
  final TextEditingController? holderCtrl;
  final TextEditingController? cvvCtrl;
  final TextEditingController? expiryCtrl;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey, // Validate from parent using formKey.currentState!.validate() [13]
      child: Column(
        children: [
          TextFormField(
            controller: numberCtrl,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              const _CardNumberFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: 'XXXX XXXX XXXX XXXX',
              prefixIcon: Icon(Icons.credit_card),
            ),
            validator: _numberValidator,
          ), // Basic formatting and length checks; custom Luhn can be added later [15]
          const SizedBox(height: 16),
          TextFormField(
            controller: holderCtrl,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Card holder',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.length < 2) return 'Enter a valid name';
              return null;
            },
          ), // Simple non-empty name validation [13]
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: expiryCtrl,
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    const _CardExpiryFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'MM/YY',
                    hintText: 'MM/YY',
                    prefixIcon: Icon(Icons.event),
                  ),
                  validator: _expiryValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: cvvCtrl,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: 'XXX',
                    prefixIcon: Icon(Icons.password),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.length < 3) return 'Enter a valid CVV';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------- Card validators ---------

  static String? _numberValidator(String? v) {
    final s = (v ?? '').replaceAll(' ', '');
    if (s.length < 12) return 'Enter a valid card number';
    // Optional: Luhn check could be added here for stricter validation.
    return null;
  } // Form/validator pattern per Flutter docs [13]

  static String? _expiryValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 5 || s != '/') return 'Enter expiry as MM/YY';
    final mm = int.tryParse(s.substring(0, 2));
    final yy = int.tryParse(s.substring(3, 5));
    if (mm == null || yy == null || mm < 1 || mm > 12) return 'Invalid month';
    // crude past-date check
    final now = DateTime.now();
    final year = 2000 + yy;
    final endOfMonth = DateTime(year, mm + 1, 0);
    if (endOfMonth.isBefore(DateTime(now.year, now.month, 1))) {
      return 'Card expired';
    }
    return null;
  } // Simple MM/YY validation without packages [15]
}

// ---------------- Input formatters ----------------

/// Inserts spaces every 4 digits (e.g., 4111 1111 1111 1111).
class _CardNumberFormatter extends TextInputFormatter {
  const _CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
} // Simple card number visual formatting to assist readability [14]

/// Formats MMYY into MM/YY while typing.
class _CardExpiryFormatter extends TextInputFormatter {
  const _CardExpiryFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);
    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buf.write('/');
      buf.write(text[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
} // Basic MM/YY formatter to guide correct input structure [12]
