import '../../../Appointment/data/models/appointment_model.dart'
    show AppointmentCancellationReason;

class PatientOverviewModel {
  final PatientOverviewInfo? patient;
  final List<PatientAppointment> appointments;
  final List<dynamic> investigations;

  PatientOverviewModel({
    this.patient,
    this.appointments = const [],
    this.investigations = const [],
  });

  factory PatientOverviewModel.fromJson(Map<String, dynamic> json) {
    return PatientOverviewModel(
      patient: json['patient'] != null
          ? PatientOverviewInfo.fromJson(json['patient'])
          : null,
      appointments: json['appointments'] != null
          ? List<PatientAppointment>.from(
              json['appointments'].map((x) => PatientAppointment.fromJson(x)))
          : [],
      investigations: json['investigations'] ?? [],
    );
  }
}

class PatientOverviewInfo {
  final String? id;
  final String? name;
  final String? birthDate;
  final String? gender;
  final String? nationality;
  final String? nationalId;
  final String? phone;
  final String? email;
  final String? address;
  final String? branchName;
  final String? clinicName;

  PatientOverviewInfo({
    this.id,
    this.name,
    this.birthDate,
    this.gender,
    this.nationality,
    this.nationalId,
    this.phone,
    this.email,
    this.address,
    this.branchName,
    this.clinicName,
  });

  factory PatientOverviewInfo.fromJson(Map<String, dynamic> json) {
    return PatientOverviewInfo(
      id: json['id'],
      name: json['name'],
      birthDate: json['birthDate'],
      gender: json['gender'],
      nationality: json['nationality'],
      nationalId: json['nationalId'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      branchName: json['branchName'],
      clinicName: json['clinicName'],
    );
  }
}

class PatientAppointment {
  final String? id;
  final String? typeName;
  final String? status;
  final String? doctorName;
  final String? date;
  final String? branchName;
  final String? description;

  /// Set when the visit produced an examination, which is what makes the row
  /// openable.
  final String? examinationId;

  /// What the doctor decided on that visit, so the history reads as decisions
  /// rather than as a list of dates.
  final List<PatientAppointmentAction> actions;

  /// The reason shown beside the status: the save reason while `Saved`, the
  /// cancellation reason while `Cancelled`, otherwise null.
  final String? statusReason;

  PatientAppointment({
    this.id,
    this.typeName,
    this.status,
    this.doctorName,
    this.date,
    this.branchName,
    this.description,
    this.examinationId,
    this.actions = const [],
    this.statusReason,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: json['id'],
      typeName: json['typeName'],
      status: json['status'],
      doctorName: json['doctorName'],
      date: json['date'],
      branchName: json['branchName'],
      description: json['description'],
      examinationId: json['examinationId'],
      actions: json['actions'] == null
          ? const []
          : List<PatientAppointmentAction>.from(json['actions']
              .map((x) => PatientAppointmentAction.fromJson(x))),
      statusReason: _statusReasonFrom(json),
    );
  }
}

String? _statusReasonFrom(Map<String, dynamic> json) {
  if (json['status'] == 'Saved' && json['saveReason'] is Map) {
    final name = json['saveReason']['name']?.toString().trim();
    return (name == null || name.isEmpty) ? null : name;
  }
  if (json['status'] == 'Cancelled' && json['cancellationReason'] is Map) {
    return AppointmentCancellationReason.fromJson(
            Map<String, dynamic>.from(json['cancellationReason']))
        .displayText;
  }
  return null;
}

class PatientAppointmentAction {
  final String? action;
  final String? eye;
  final String? data;

  PatientAppointmentAction({this.action, this.eye, this.data});

  factory PatientAppointmentAction.fromJson(Map<String, dynamic> json) {
    return PatientAppointmentAction(
      action: json['action'],
      eye: json['eye'],
      data: json['data'],
    );
  }
}
