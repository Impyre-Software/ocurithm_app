import '../../../Branch/data/model/branches_model.dart';
import '../../../Doctor/data/model/doctor_model.dart';
import '../models/appointment_model.dart';

abstract class AppointmentRepo {
  Future<DoctorModel> getAllDoctors({
    String? branch,
    bool? isActive,
  });

  Future<BranchesModel> getAllBranches();

  Future<AppointmentModel> getAllAppointment(
      {DateTime? date, String? branch, String? doctor, String? search});

  /// Fetches an appointment fresh by id, rather than relying on a
  /// potentially-stale object carried over from a list fetched earlier.
  Future<Appointment> getAppointmentById({required String id});

  Future<Appointment> editAppointment(
      {required String id,
      required String action,
      DateTime? date,
      String? doctor,
      AppointmentCancellationReason? cancellationReason});

  /// Reorders a doctor's daily queue. [orderedIds] are that doctor's active
  /// appointments for the day in their new order; the server assigns
  /// sequence 1..n and returns the affected appointments.
  Future<List<Appointment>> reorderAppointments(
      {required List<String> orderedIds});
}
