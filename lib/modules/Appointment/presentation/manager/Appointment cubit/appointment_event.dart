part of 'appointment_cubit.dart';

@immutable
abstract class AppointmentEvent {}

class GetDoctorsEvent extends AppointmentEvent {
  final String? branch;
  final bool? isActive;

  GetDoctorsEvent({this.branch, this.isActive});
}

class GetBranchesEvent extends AppointmentEvent {}

class GetAppointmentsEvent extends AppointmentEvent {
  final DateTime? date;
  final String? branch;
  final String? doctor;
  final String? search;

  /// Background poll: fetch without showing the loading shimmer, and leave the
  /// current list in place if the request fails.
  final bool silent;

  GetAppointmentsEvent({
    this.date,
    this.branch,
    this.doctor,
    this.search,
    this.silent = false,
  });
}

class EditAppointmentEvent extends AppointmentEvent {
  final String id;
  final String action;
  final DateTime? date;
  final String? doctor;
  final BuildContext context;

  /// Required by the API when [action] is `cancel`.
  final model.AppointmentCancellationReason? cancellationReason;

  EditAppointmentEvent({
    required this.id,
    required this.action,
    required this.context,
    this.date,
    this.doctor,
    this.cancellationReason,
  });
}

class SelectDateEvent extends AppointmentEvent {
  final DateTime date;
  SelectDateEvent(this.date);
}

class SelectBranchEvent extends AppointmentEvent {
  final branch.Branch? selectedBranch;
  SelectBranchEvent(this.selectedBranch);
}

class SelectDoctorEvent extends AppointmentEvent {
  final Doctor? selectedDoctor;
  SelectDoctorEvent(this.selectedDoctor);
}

class SearchChangedEvent extends AppointmentEvent {
  final String search;
  SearchChangedEvent(this.search);
}

class RefreshAppointmentsEvent extends AppointmentEvent {}

class LocalUpdateAppointmentStatusEvent extends AppointmentEvent {
  final String id;
  final String status;

  LocalUpdateAppointmentStatusEvent({required this.id, required this.status});
}
