// lib/features/checkout/presentation/widgets/traveler_info.dart

import 'package:flutter/material.dart';

/// A reusable traveler info form section with validation for
/// name, email, and phone. Parent can validate via formKey.currentState!.validate(). [web:1570]
class TravelerInfo extends StatelessWidget {
  const TravelerInfo({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    this.enabled = true,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey, // standard Flutter form validation pattern [web:1570]
      child: Column(
        children: [
          TextFormField(
            controller: nameCtrl,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name], // platform autofill hint [web:1695]
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: _validateName, // validator contract: return error or null [web:1570]
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailCtrl,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email], // email autofill [web:1695]
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _validateEmail, // form field validation pattern [web:1570]
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: phoneCtrl,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber], // phone autofill [web:1695]
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: _validatePhone, // simple phone validator [web:1570]
          ),
        ],
      ),
    );
  }

  // ---- Validators ----

  static String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Enter a valid name';
    return null;
  } // matches Flutter Form validator usage [web:1570]

  static String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(s)) return 'Enter a valid email';
    return null;
  } // email check per common examples [web:1624]

  static String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Phone is required';
    // Lenient international-friendly pattern; can be replaced with stricter logic later.
    final re = RegExp(r'^[0-9+\-\s]{7,20}$');
    if (!re.hasMatch(s)) return 'Enter a valid phone';
    return null;
  } // simple phone validation within TextFormField [web:1572]
}
