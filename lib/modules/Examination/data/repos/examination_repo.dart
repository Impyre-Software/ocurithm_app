import '../../../Branch/data/model/data.dart';
import '../../../Patient/data/model/one_exam.dart';
import '../model/patient_overview_model.dart';
import '../model/saved_Exam.dart';

/// Outcome of claiming the one-examiner-per-appointment lock.
///
/// [sessionId] is set when the caller now holds it — including when they already
/// did, since re-entering your own session is normal. [conflictMessage] carries the
/// server's wording naming whoever holds it instead.
class ExaminationSessionResult {
  const ExaminationSessionResult({this.sessionId, this.conflictMessage});

  final String? sessionId;
  final String? conflictMessage;

  bool get isGranted => sessionId != null;
}

abstract class ExaminationRepo {
  Future<ExaminationModel> makeExamination(
      {required Map<String, dynamic> data});

  Future<DataModel> makeFinalization(
      {required String id, required Map<String, dynamic> data});

  /// Soft-deletes an examination. Gated server-side on `deleteExaminations`, and
  /// confirmed by the caller's own [password] (a wrong one is a 403
  /// "Incorrect password").
  Future<void> deleteExamination(String id, {required String password});

  Future<SavedExaminationModel> getOneExamination(
      {required String appointmentId});

  Future<PatientOverviewModel> getPatientOverview(
      {required String patientId});

  /// Claims the examination lock for this appointment, or reports who holds it.
  Future<ExaminationSessionResult> startExaminationSession(
      {required String appointmentId});

  /// Tells the server this client is still examining. Best-effort.
  Future<void> heartbeatExaminationSession({required String sessionId});

  /// Releases the lock. Best-effort: a failure falls back to the stale timeout.
  Future<void> closeExaminationSession({required String sessionId});
}

