import 'package:intl/intl.dart';

enum WarrantyStatus { active, expiringSoon, expired, none }

class DateFormatter {
  static final DateFormat _shortDate = DateFormat('MMM d, y');

  static String formatShort(DateTime? date) {
    if (date == null) return '—';
    return _shortDate.format(date);
  }

  static WarrantyStatus getWarrantyStatus(DateTime? warrantyEndDate) {
    if (warrantyEndDate == null) return WarrantyStatus.none;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(
      warrantyEndDate.year,
      warrantyEndDate.month,
      warrantyEndDate.day,
    );

    if (endDay.isBefore(today)) {
      return WarrantyStatus.expired;
    }

    final daysRemaining = endDay.difference(today).inDays;
    if (daysRemaining <= 30) {
      return WarrantyStatus.expiringSoon;
    }

    return WarrantyStatus.active;
  }
}
