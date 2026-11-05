import 'package:flutter/material.dart';
import 'package:ocurithm/core/utils/colors.dart';
import 'package:ocurithm/core/utils/format_helper.dart';
import 'package:ocurithm/core/utils/services_locator.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';
import 'package:ocurithm/core/widgets/scaffold_style.dart';
import 'package:ocurithm/modules/Appointment/data/models/appointment_lifecycle_status.dart';
import 'package:ocurithm/modules/Appointment/data/models/appointment_model.dart';
import 'package:ocurithm/modules/Appointment/data/repos/appointment_repo.dart';

/// Drag-to-reorder queue for a single doctor's day, mirroring web's
/// appointment-queue.ts: active appointments only (closed ones never appear
/// here), ordered by sequence with a datetime fallback for legacy rows the
/// backfill hasn't reached, and 1-based dense position numbers.
///
/// Mobile scopes this per-doctor explicitly (via [doctorId]) rather than
/// grouping every doctor into one view like web does, since the backend
/// itself rejects a reorder payload spanning more than one doctor.
class DoctorQueueView extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final DateTime date;

  const DoctorQueueView({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.date,
  });

  @override
  State<DoctorQueueView> createState() => _DoctorQueueViewState();
}

class _DoctorQueueViewState extends State<DoctorQueueView> {
  final AppointmentRepo _repo = sl<AppointmentRepo>();

  List<Appointment> _queue = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.getAllAppointment(
        date: widget.date,
        doctor: widget.doctorId,
      );
      setState(() {
        _queue = _activeSorted(result.appointments);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Active (non-closed) appointments, sorted by sequence — nulls sort last,
  /// matching web's seqValue() treating a missing sequence as +infinity —
  /// with datetime as the tiebreaker.
  List<Appointment> _activeSorted(List<Appointment> all) {
    final active = all.where((a) {
      final status = AppointmentLifecycleStatus.fromString(a.status);
      return !status.isClosed;
    }).toList();

    active.sort((a, b) {
      final seqA = a.sequence ?? double.infinity;
      final seqB = b.sequence ?? double.infinity;
      final seqCompare = seqA.compareTo(seqB);
      if (seqCompare != 0) return seqCompare;
      final timeA = a.datetime?.millisecondsSinceEpoch ?? 0;
      final timeB = b.datetime?.millisecondsSinceEpoch ?? 0;
      return timeA.compareTo(timeB);
    });
    return active;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final previous = List<Appointment>.from(_queue);

    // Optimistic: reorder locally first so the drag sticks immediately: the
    // network round trip must not make the list snap back before settling.
    setState(() {
      final moved = _queue.removeAt(oldIndex);
      _queue.insert(newIndex, moved);
      _isSaving = true;
    });

    try {
      final orderedIds = _queue.map((a) => a.id!).toList();
      final updated =
          await _repo.reorderAppointments(orderedIds: orderedIds);
      final byId = {for (final a in updated) a.id: a};
      setState(() {
        _queue = _queue
            .map((a) => byId[a.id] ?? a)
            .toList();
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _queue = previous;
        _isSaving = false;
      });
      SnackbarService.showError(context,
          message: 'Failed to reorder queue: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScaffold(
      title: "${widget.doctorName}'s Queue",
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colorz.primaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _queue.isEmpty
                  ? const Center(
                      child: Text('No active appointments in the queue today'))
                  : Stack(
                      children: [
                        ReorderableListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _queue.length,
                          onReorder: _isSaving ? (_, __) {} : _onReorder,
                          itemBuilder: (context, index) {
                            final appointment = _queue[index];
                            final status = AppointmentLifecycleStatus
                                .fromString(appointment.status);
                            return Container(
                              key: ValueKey(appointment.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: status == AppointmentLifecycleStatus
                                          .examining
                                      ? Colors.green
                                      : index == 0
                                          ? Colors.amber
                                          : theme.dividerColor,
                                  width: status ==
                                              AppointmentLifecycleStatus
                                                  .examining ||
                                          index == 0
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        Colorz.primaryColor.withValues(alpha: 0.15),
                                    child: Text('${index + 1}',
                                        style: TextStyle(
                                            color: Colorz.primaryColor,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appointment.patient?.name ??
                                              'Unknown patient',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          // "Saved · Dilation — <time>" for a
                                          // parked visit; "<status> — <time>"
                                          // otherwise.
                                          '${appointment.statusReason == null ? status.label : '${status.label} · ${appointment.statusReason}'}'
                                          '  —  ${FormatHelper.formatDateTime(appointment.datetime?.toString())}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: status.color),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.drag_handle),
                                ],
                              ),
                            );
                          },
                        ),
                        if (_isSaving)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colorz.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
