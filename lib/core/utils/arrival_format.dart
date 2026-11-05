import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// How a check-in compares with the scheduled slot. Mirrors web's
/// `lib/appointment-arrival.ts` so both platforms word it the same way.
enum ArrivalPunctuality { early, onTime, late }

class ArrivalSummary {
  const ArrivalSummary({
    required this.time,
    required this.shortTime,
    this.punctuality,
    this.punctualityLabel,
  });

  /// "10:42 AM", or "Nov 3, 10:42 AM" when it was not the scheduled day.
  final String time;

  /// "10:42 AM" without the date — for the compact grid tile.
  final String shortTime;

  final ArrivalPunctuality? punctuality;

  /// "on time", "12 min early", "1 h 20 min late".
  final String? punctualityLabel;

  /// Green for early/on time, amber for late.
  Color get punctualityColor => punctuality == ArrivalPunctuality.late
      ? Colors.amber.shade800
      : Colors.green.shade700;
}

class ArrivalFormat {
  /// Arriving within this many minutes either side of the slot counts as on time.
  static const int onTimeWindowMinutes = 5;

  /// 45 → "45 min", 80 → "1 h 20 min", 120 → "2 h".
  static String formatMinutes(num totalMinutes) {
    final minutes = totalMinutes.abs().round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  /// Null when the patient has not been checked in. Both times are expected in
  /// local time (the appointment model converts them on parse).
  static ArrivalSummary? describe(DateTime? arrivedAt, DateTime? scheduledAt) {
    if (arrivedAt == null) return null;

    final sameDay = scheduledAt == null ||
        (arrivedAt.year == scheduledAt.year &&
            arrivedAt.month == scheduledAt.month &&
            arrivedAt.day == scheduledAt.day);
    final time =
        DateFormat(sameDay ? 'hh:mm a' : 'MMM d, hh:mm a').format(arrivedAt);
    final shortTime = DateFormat('hh:mm a').format(arrivedAt);

    if (scheduledAt == null) {
      return ArrivalSummary(time: time, shortTime: shortTime);
    }

    final diffMinutes =
        arrivedAt.difference(scheduledAt).inSeconds / Duration.secondsPerMinute;

    if (diffMinutes.abs() <= onTimeWindowMinutes) {
      return ArrivalSummary(
        time: time,
        shortTime: shortTime,
        punctuality: ArrivalPunctuality.onTime,
        punctualityLabel: 'on time',
      );
    }

    final early = diffMinutes < 0;
    return ArrivalSummary(
      time: time,
      shortTime: shortTime,
      punctuality: early ? ArrivalPunctuality.early : ArrivalPunctuality.late,
      punctualityLabel:
          '${formatMinutes(diffMinutes)} ${early ? 'early' : 'late'}',
    );
  }
}
