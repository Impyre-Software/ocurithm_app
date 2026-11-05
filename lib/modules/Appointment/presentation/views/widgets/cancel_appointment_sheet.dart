import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/appointment_model.dart';

/// Asks why before cancelling. Resolves to the chosen reason, or null when the
/// user backs out. A reason is required (the API rejects a cancel without one),
/// and "Other" requires the typed text. Mirrors web's `AppointmentCancelDialog`.
Future<AppointmentCancellationReason?> showCancellationReasonSheet(
    BuildContext context, Appointment appointment) {
  return showModalBottomSheet<AppointmentCancellationReason>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _CancelAppointmentSheet(appointment: appointment),
  );
}

class _CancelAppointmentSheet extends StatefulWidget {
  const _CancelAppointmentSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_CancelAppointmentSheet> createState() =>
      _CancelAppointmentSheetState();
}

class _CancelAppointmentSheetState extends State<_CancelAppointmentSheet> {
  String? _code;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _isOther => _code == 'other';

  bool get _isValid =>
      _code != null && (!_isOther || _noteController.text.trim().isNotEmpty);

  void _submit() {
    if (!_isValid) return;
    Navigator.pop(
      context,
      AppointmentCancellationReason(
        code: _code!,
        note: _isOther ? _noteController.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointment = widget.appointment;
    final subtitle = [
      appointment.patient?.name,
      appointment.datetime == null
          ? null
          : DateFormat('EEE, MMM d · hh:mm a').format(appointment.datetime!),
    ].whereType<String>().join(' · ');

    return Padding(
      // Lift the sheet above the keyboard while typing an "Other" reason.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel appointment?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ],
            const SizedBox(height: 4),
            Text('Choose why it is being cancelled.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _code,
              onChanged: (value) => setState(() => _code = value),
              child: Column(
                children: cancellationReasons
                    .map((reason) => RadioListTile<String>(
                          value: reason.key,
                          title: Text(reason.value),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
            if (_isOther) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _noteController,
                autofocus: true,
                maxLength: cancellationNoteMaxLength,
                maxLines: 3,
                minLines: 2,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Type the reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep appointment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600),
                    onPressed: _isValid ? _submit : null,
                    child: const Text('Cancel appointment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
