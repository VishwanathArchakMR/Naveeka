/// Global reusable form validation helpers.
/// All return `null` if valid, or a user-friendly error message if invalid.
///
/// These messages are designed to be SHORT and CLEAN for premium UI.
class Validators {
  /// Required field
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Email format check
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    const pattern =
        r'^[\w\.-]+@[\w\.-]+\.\w+$'; // Allows john.doe@mail.com
    final regex = RegExp(pattern);
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Password strength check
  /// Backend rule: minimum 6 chars, at least one letter & one number
  static String? password(String? value, {bool requireStrong = false}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (requireStrong) {
      final hasLetter = value.contains(RegExp(r'[A-Za-z]'));
      final hasDigit = value.contains(RegExp(r'\d'));
      if (!hasLetter || !hasDigit) {
        return 'Include at least 1 letter & 1 number';
      }
    }
    return null;
  }

  /// Confirm password matches original
  static String? confirmPassword(String? value, String original) {
    if (value != original) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Phone number validation (basic)
  /// Matches backend: 7-15 digits, optional +countrycode
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final regex = RegExp(r'^\+?[0-9]{7,15}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Optional field: only checks when value provided
  static String? optionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final regex = RegExp(r'^(https?:\/\/)?([\w\-]+\.)+[\w]{2,}(\/\S*)?$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid URL';
    }
    return null;
  }

  /// Length limit validator
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value != null && value.length > max) {
      return '${fieldName ?? 'Field'} must be less than $max characters';
    }
    return null;
  }
}
