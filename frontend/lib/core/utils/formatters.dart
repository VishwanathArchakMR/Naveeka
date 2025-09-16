import 'package:intl/intl.dart';

/// Global formatting helper functions for consistent UI across the app.
///
/// All functions here are safe to call with null values.
class Formatters {
  /// Formats a DateTime to a readable full date (Mar 4, 2025)
  static String formatDate(DateTime? date, {bool includeYear = true}) {
    if (date == null) return '';
    final format = includeYear ? DateFormat('MMM d, yyyy') : DateFormat('MMM d');
    return format.format(date.toLocal());
  }

  /// Formats a DateTime to a short time string (e.g., 9:41 PM)
  static String formatTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat('hh:mm a').format(date.toLocal());
  }

  /// Returns a "time ago" style string from a DateTime
  static String timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    return formatDate(date);
  }

  /// Formats a distance in meters into km with 1 decimal place (e.g., 2.3 km)
  /// If less than 1000m, shows in meters (e.g., 850 m)
  static String formatDistance(num? meters) {
    if (meters == null) return '';
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Formats a duration into mm:ss (for audio, timers)
  static String formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Formats a number with commas (and optional decimal precision)
  static String formatNumber(num? number, {int decimals = 0}) {
    if (number == null) return '0';
    return number.toStringAsFixed(decimals).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Capitalizes the first letter of a string
  static String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}
