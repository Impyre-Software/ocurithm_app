import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_handler.dart';
import '../../../Branch/data/model/branches_model.dart';
import '../../../Doctor/data/model/doctor_model.dart';
import '../models/appointment_model.dart';
import 'appointment_repo.dart';

class AppointmentRepoImpl implements AppointmentRepo {
  final ApiHandler _apiHandler = ApiHandler();

  @override
  Future<DoctorModel> getAllDoctors({
    String? branch,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> query = {
        if (branch != null) "branch": branch,
        if (isActive != null) "isActive": isActive,
      };

      final response = await _apiHandler.get<DoctorModel>(
        ApiConstants.doctors,
        queryParameters: query,
        cancelKey: 'getAllDoctors',
        fromJson: (json) => DoctorModel.fromJson(json),
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to fetch doctors');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BranchesModel> getAllBranches() async {
    try {
      final response = await _apiHandler.get<BranchesModel>(
        ApiConstants.branches,
        cancelKey: 'getAllBranches',
        fromJson: (json) => BranchesModel.fromJson(json),
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to fetch branches');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AppointmentModel> getAllAppointment({
    DateTime? date,
    String? branch,
    String? doctor,
    String? search,
  }) async {
    try {
      Map<String, dynamic> query = {
        if (date != null)
          "startDate": DateTime(date.year, date.month, date.day, 0, 0, 0)
              .toIso8601String(),
        if (date != null)
          "endDate": DateTime(date.year, date.month, date.day, 23, 59, 59)
              .toIso8601String(),
        if (doctor != null) "doctor": doctor,
        if (branch != null) "branch": branch,
        if (search != null && search.isNotEmpty) "search": search,
        "pagination": false
      };

      final response = await _apiHandler.get<AppointmentModel>(
        ApiConstants.appointments,
        queryParameters: query,
        cancelKey: 'getAllAppointments',
        fromJson: (json) => AppointmentModel.fromJson(json),
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to fetch appointments');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Appointment> getAppointmentById({required String id}) async {
    final response = await _apiHandler.get<Appointment>(
      "${ApiConstants.appointments}/$id",
      cancelKey: 'getAppointmentById',
      fromJson: (json) => Appointment.fromJson(json),
    );

    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.message ?? 'Failed to fetch appointment');
    }
  }

  @override
  Future<Appointment> editAppointment({
    required String id,
    required String action,
    DateTime? date,
    String? doctor,
    AppointmentCancellationReason? cancellationReason,
  }) async {
    try {
      Map<String, dynamic> data = {
        "action": action,
        if (doctor != null) "doctor": doctor,
        if (date != null) "datetime": date.toIso8601String(),
        if (cancellationReason != null)
          "cancellationReason": cancellationReason.toJson(),
      };

      final response = await _apiHandler.put<Appointment>(
        '${ApiConstants.appointments}/$id',
        data: data,
        cancelKey: 'editAppointment',
        fromJson: (json) => Appointment.fromJson(json),
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to edit appointment');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Appointment>> reorderAppointments(
      {required List<String> orderedIds}) async {
    try {
      final response = await _apiHandler.patch<List<Appointment>>(
        "${ApiConstants.appointments}/reorder",
        data: {"orderedIds": orderedIds},
        cancelKey: 'reorderAppointments',
        fromJson: (json) =>
            (json as List).map((x) => Appointment.fromJson(x)).toList(),
      );

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to reorder appointments');
      }
    } catch (e) {
      rethrow;
    }
  }
}
