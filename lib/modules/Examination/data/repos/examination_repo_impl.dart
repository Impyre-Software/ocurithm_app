import 'package:dio/dio.dart';
import 'package:ocurithm/modules/Examination/data/repos/examination_repo.dart';

import '../../../../../core/api/api_handler.dart';
import '../../../../../core/Network/shared.dart';
import '../../../../core/api/api_constants.dart';
import '../../../Branch/data/model/data.dart';
import '../../../Patient/data/model/one_exam.dart';
import '../model/patient_overview_model.dart';
import '../model/saved_Exam.dart';

class ExaminationRepoImpl implements ExaminationRepo {
  final ApiHandler _apiHandler = ApiHandler();

  Options _getOptions() {
    final String? token = CacheHelper.getData(key: "token");
    return Options(
      headers: {
        "Content-Type": "application/json",
        if (token != null) 'Cookie': 'ocurithmToken=$token',
      },
    );
  }

  @override
  Future<ExaminationModel> makeExamination(
      {required Map<String, dynamic> data}) async {
    final result = await _apiHandler.post<ExaminationModel>(
      ApiConstants.examination,
      data: data,
      options: _getOptions(),
      fromJson: (json) => ExaminationModel.fromJson(json),
    );

    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.message ?? "Failed to make examination");
    }
  }

  @override
  Future<DataModel> makeFinalization(
      {required String id, required Map<String, dynamic> data}) async {
    final result = await _apiHandler.post<DataModel>(
      "${ApiConstants.examination}/$id/finalization",
      data: data,
      options: _getOptions(),
      fromJson: (json) => DataModel.fromJson(json),
    );

    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.message ?? "Failed to finalize examination");
    }
  }

  @override
  Future<void> deleteExamination(String id, {required String password}) async {
    final response = await _apiHandler.delete(
      "${ApiConstants.examination}/$id",
      data: {"password": password},
      options: _getOptions(),
    );
    if (!response.success) {
      throw Exception(response.message ?? 'Failed to delete examination');
    }
  }

  @override
  Future<SavedExaminationModel> getOneExamination(
      {required String appointmentId}) async {
    final result = await _apiHandler.get<SavedExaminationModel>(
      ApiConstants.examination,
      queryParameters: {"appointment": appointmentId},
      options: _getOptions(),
      fromJson: (json) => SavedExaminationModel.fromJson(json),
    );

    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.message ?? "Failed fetch examination");
    }
  }

  @override
  Future<ExaminationSessionResult> startExaminationSession(
      {required String appointmentId}) async {
    final result = await _apiHandler.post<Map<String, dynamic>>(
      ApiConstants.examinationSessionStart,
      data: {"appointment": appointmentId},
      options: _getOptions(),
      fromJson: (json) => json,
    );

    if (result.success && result.data != null) {
      final session = result.data!["session"];
      return ExaminationSessionResult(
        sessionId: session is Map ? session["id"]?.toString() : null,
      );
    }

    // 409 is the expected "someone else is examining this patient" answer; its
    // message names them, so it is surfaced rather than swallowed.
    return ExaminationSessionResult(
      conflictMessage:
          result.message ?? "This appointment is currently being examined.",
    );
  }

  @override
  Future<void> heartbeatExaminationSession({required String sessionId}) async {
    await _apiHandler.post(
      ApiConstants.examinationSessionHeartbeat(sessionId),
      data: const {},
      options: _getOptions(),
    );
  }

  @override
  Future<void> closeExaminationSession({required String sessionId}) async {
    await _apiHandler.post(
      ApiConstants.examinationSessionClose(sessionId),
      data: const {},
      options: _getOptions(),
    );
  }

  @override
  Future<PatientOverviewModel> getPatientOverview(
      {required String patientId}) async {
    final result = await _apiHandler.get<PatientOverviewModel>(
      "${ApiConstants.patients}/$patientId/overview",
      options: _getOptions(),
      fromJson: (json) => PatientOverviewModel.fromJson(json),
    );

    if (result.success && result.data != null) {
      return result.data!;
    } else {
      throw Exception(result.message ?? "Failed to fetch patient overview");
    }
  }
}
