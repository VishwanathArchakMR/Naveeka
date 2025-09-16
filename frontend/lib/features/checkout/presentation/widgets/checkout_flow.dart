// lib/features/checkout/presentation/widgets/checkout_flow.dart

import 'package:flutter/material.dart';


class CheckoutFlow extends StatefulWidget {
  const CheckoutFlow({
    super.key,
    this.bookingData,
    this.onCompleted,
  });

  /// Optional booking payload passed from the route (e.g., flight/hotel selection).
  final Map<String, dynamic>? bookingData;

  /// Optional completion callback with merged checkout data.
  final void Function(Map<String, dynamic> finalOrder)? onCompleted;

  @override
  State<CheckoutFlow> createState() => _CheckoutFlowState();
}

class _CheckoutFlowState extends State<CheckoutFlow> {
  int _currentStep = 0;
  bool _processing = false;

  // Traveler form
  final _travelerKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Payment form
  final _paymentKey = GlobalKey<FormState>();
  String _paymentMethod = 'card';
  final _cardNumberCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  bool _agreed = true;

  // Derived summary
  Map<String, dynamic> get _traveler => <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };

  Map<String, dynamic> get _payment => <String, dynamic>{
        'method': _paymentMethod,
        if (_paymentMethod == 'card') ...{
          'cardNumber': _cardNumberCtrl.text.trim(),
          'cardHolder': _cardHolderCtrl.text.trim(),
          'cardCvv': _cardCvvCtrl.text.trim(),
          'cardExpiry': _cardExpiryCtrl.text.trim(),
        },
      };

  Map<String, dynamic> _buildOrder() {
    return <String, dynamic>{
      'booking': widget.bookingData ?? const <String, dynamic>{},
      'traveler': _traveler,
      'payment': _payment,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardCvvCtrl.dispose();
    _cardExpiryCtrl.dispose();
    super.dispose();
  }

  // ------------------ Validation helpers ------------------

  bool _validateTraveler() {
    final form = _travelerKey.currentState;
    if (form == null) return false;
    return form.validate();
  }

  bool _validatePayment() {
    if (!_agreed) {
      _snack('Please accept terms & conditions to continue.');
      return false;
    }
    if (_paymentMethod != 'card') return true; // basic validation only for card demo
    final form = _paymentKey.currentState;
    if (form == null) return false;
    return form.validate();
  }

  // ------------------ Navigation ------------------

  void _next() async {
    if (_currentStep == 0) {
      if (!_validateTraveler()) return;
      setState(() => _currentStep = 1);
      return;
    }
    if (_currentStep == 1) {
      if (!_validatePayment()) return;
      setState(() => _currentStep = 2);
      return;
    }
    if (_currentStep == 2) {
      await _processOrder();
      return;
    }
  }

  void _back() {
    if (_processing) return;
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _processOrder() async {
    if (_processing) return;
    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final order = _buildOrder();
    setState(() {
      _processing = false;
      _currentStep = 3;
    });

    widget.onCompleted?.call(order);
    _snack('Payment successful. Booking confirmed!');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final steps = <Step>[
      Step(
        title: const Text('Traveler'),
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 0,
        content: _TravelerForm(
          formKey: _travelerKey,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
        ),
      ),
      Step(
        title: const Text('Payment'),
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 1,
        content: _PaymentForm(
          formKey: _paymentKey,
          method: _paymentMethod,
          onMethodChanged: (m) => setState(() => _paymentMethod = m),
          agreed: _agreed,
          onToggleAgree: (v) => setState(() => _agreed = v),
          cardNumberCtrl: _cardNumberCtrl,
          cardHolderCtrl: _cardHolderCtrl,
          cardCvvCtrl: _cardCvvCtrl,
          cardExpiryCtrl: _cardExpiryCtrl,
        ),
      ),
      Step(
        title: const Text('Review'),
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 2,
        content: _ReviewBlock(
          booking: widget.bookingData,
          traveler: _traveler,
          payment: _payment,
        ),
      ),
      Step(
        title: const Text('Done'),
        state: _currentStep == 3 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 3,
        content: _ConfirmationBlock(order: _buildOrder()),
      ),
    ];

    return Stepper(
      type: StepperType.vertical,
      currentStep: _currentStep,
      onStepTapped: (i) {
        if (_processing) return;
        // Only allow backwards taps to avoid skipping validation.
        if (i < _currentStep) setState(() => _currentStep = i);
      },
      controlsBuilder: (context, details) {
        final isLastAction = _currentStep >= 2 && _currentStep < 3;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              FilledButton(
                onPressed: _processing ? null : _next,
                child: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLastAction ? 'Pay & confirm' : 'Continue'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _processing ? null : _back,
                child: const Text('Back'),
              ),
            ],
          ),
        );
      },
      steps: steps,
    );
  }
}

// ------------------ Traveler form ------------------

class _TravelerForm extends StatelessWidget {
  const _TravelerForm({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;

  String? _name(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Enter a valid name';
    return null;
  }

  String? _email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  }

  String? _phone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Phone is required';
    final re = RegExp(r'^[0-9+\-\s]{7,20}$');
    if (!re.hasMatch(s)) return 'Enter a valid phone';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _name,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: _phone,
          ),
        ],
      ),
    );
  }
}

// ------------------ Payment form ------------------

class _PaymentForm extends StatelessWidget {
  const _PaymentForm({
    required this.formKey,
    required this.method,
    required this.onMethodChanged,
    required this.agreed,
    required this.onToggleAgree,
    required this.cardNumberCtrl,
    required this.cardHolderCtrl,
    required this.cardCvvCtrl,
    required this.cardExpiryCtrl,
  });

  final GlobalKey<FormState> formKey;
  final String method;
  final ValueChanged<String> onMethodChanged;
  final bool agreed;
  final ValueChanged<bool> onToggleAgree;

  final TextEditingController cardNumberCtrl;
  final TextEditingController cardHolderCtrl;
  final TextEditingController cardCvvCtrl;
  final TextEditingController cardExpiryCtrl;

  String? _notEmpty(String label, String? v, {int min = 1}) {
    final s = (v ?? '').trim();
    if (s.length < min) return '$label is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final showCard = method == 'card';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Methods
        SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
            ButtonSegment<String>(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code)),
            ButtonSegment<String>(value: 'netbanking', label: Text('Netbanking'), icon: Icon(Icons.account_balance)),
          ],
          selected: {method},
          onSelectionChanged: (s) => onMethodChanged(s.first),
        ),
        const SizedBox(height: 16),

        // Card fields (if chosen)
        if (showCard)
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: cardNumberCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Card number',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  validator: (v) => _notEmpty('Card number', v, min: 12),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: cardHolderCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Card holder',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => _notEmpty('Card holder', v, min: 2),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cardExpiryCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'MM/YY',
                          prefixIcon: Icon(Icons.event),
                        ),
                        validator: (v) => _notEmpty('Expiry', v, min: 4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: cardCvvCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          prefixIcon: Icon(Icons.password),
                        ),
                        validator: (v) => _notEmpty('CVV', v, min: 3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: agreed,
          onChanged: (v) => onToggleAgree(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I agree to the Terms & Privacy Policy'),
        ),
      ],
    );
  }
}

// ------------------ Review & Confirmation ------------------

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({
    required this.booking,
    required this.traveler,
    required this.payment,
  });

  final Map<String, dynamic>? booking;
  final Map<String, dynamic> traveler;
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final total = (booking?['total'] as num?)?.toDouble() ?? 0.0;
    final title = booking?['title']?.toString() ?? 'Selected booking';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tile('Item', title),
        if (booking?['date'] != null) _tile('Date', booking!['date'].toString()),
        if (booking?['ref'] != null) _tile('Reference', booking!['ref'].toString()),
        const Divider(),
        _tile('Traveler', traveler['name']?.toString() ?? ''),
        _tile('Email', traveler['email']?.toString() ?? ''),
        _tile('Phone', traveler['phone']?.toString() ?? ''),
        const Divider(),
        _tile('Payment', payment['method']?.toString().toUpperCase() ?? ''),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              total > 0 ? '₹${total.toStringAsFixed(2)}' : '-',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Taxes and fees included where applicable.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _tile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ConfirmationBlock extends StatelessWidget {
  const _ConfirmationBlock({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final bookingRef = order['booking']?['ref']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(44),
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        ),
        const SizedBox(height: 12),
        const Text(
          'Booking confirmed!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          bookingRef == null ? 'Your order is complete.' : 'Reference: $bookingRef',
          style: const TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'A confirmation has been sent to the provided email.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
