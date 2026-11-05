import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';

import '../../../data/models/appointment_model.dart';

/// The note captured when the appointment was booked, in a bottom sheet. Mirrors
/// web's `AppointmentNoteButton` dialog. Read-only: the note is edited through the
/// appointment form. Does nothing when the appointment has no note.
Future<void> showAppointmentNoteSheet(
    BuildContext context, Appointment appointment) async {
  final note = appointment.visibleNote;
  if (note == null) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => _AppointmentNoteSheet(
      note: note,
      appointment: appointment,
    ),
  );
}

String? _formatDateTime(DateTime? value) =>
    value == null ? null : DateFormat('EEE, MMM d · hh:mm a').format(value);

class _AppointmentNoteSheet extends StatelessWidget {
  const _AppointmentNoteSheet({required this.note, required this.appointment});

  final String note;
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitle = [
      appointment.patient?.name,
      _formatDateTime(appointment.datetime),
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    final footer = [
      if ((appointment.createdBy?.name ?? '').trim().isNotEmpty)
        'Booked by ${appointment.createdBy!.name}',
      _formatDateTime(appointment.createdAt?.toLocal()),
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  color: Colors.amber.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Appointment note',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
          ],
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  note,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  footer,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: note));
                  if (context.mounted) {
                    SnackbarService.showSuccess(context,
                        message: 'Note copied');
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small amber "Note" chip, shown only when the appointment has a note — its
/// presence alone tells staff there is something to read.
class AppointmentNoteChip extends StatelessWidget {
  const AppointmentNoteChip({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    if (appointment.visibleNote == null) return const SizedBox.shrink();

    final color = Colors.amber.shade800;
    return Material(
      color: Colors.amber.withValues(alpha: 0.15),
      shape: StadiumBorder(
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.6))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showAppointmentNoteSheet(context, appointment),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                'Note',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
