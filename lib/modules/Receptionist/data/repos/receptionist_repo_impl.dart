import '../../../../../core/api/api_constants.dart';
import '../../../../../core/api/api_handler.dart';
import '../../../Branch/data/model/branches_model.dart';
import '../../../Branch/data/model/data.dart';
import '../../../Doctor/data/model/capability_model.dart';
import '../../../Login/data/model/login_response.dart';
import '../models/add_reception_model.dart';
import '../models/receptionists_model.dart';
import 'receptionist_repo.dart';

/// Repository implementation for Receptionist operations
/// Uses ApiHandler for all API calls (following the new pattern)
class ReceptionistRepoImpl implements ReceptionistRepo {
  final ApiHandler _apiHandler = ApiHandler();

  @override
  Future<AddReceptionistsModel> createReceptionist({
    required Receptionist receptionist,
  }) async {
    try {
      // Sanitize and validate data before sending
      Map<String, dynamic> data = {
        "name": receptionist.name?.trim(),
        "phone": receptionist.phone?.trim(),
        "password": receptionist.password,
        "branch": receptionist.branch?.id,
        "clinic": receptionist.clinic?.id,
        if (receptionist.birthDate != null)
          "birthDate": receptionist.birthDate.toString(),
        if (receptionist.image != null && receptionist.image!.isNotEmpty)
          "image": receptionist.image,
      };

      final response = await _apiHandler.post<AddReceptionistsModel>(
        ApiConstants.receptionists,
        data: data,
        cancelKey: 'createReceptionist',
        fromJson: (json) => AddReceptionistsModel.fromJson(json),
      );

      // Check if the response was successful
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        // Handle error case
        throw Exception(response.message ?? 'Failed to create receptionist');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ReceptionistsModel> getAllReceptionists({
    int? page,
    String? search,
    String? clinic,
    String? branch,
  }) async {
    try {
      Map<String, dynamic> query = {
        if (page != null) "page": page,
        if (page != null) 'limit': 10,
        if (search != null && search.isNotEmpty) "search": search,
        if (clinic != null && clinic.isNotEmpty) "clinic": clinic,
        if (branch != null && branch.isNotEmpty) "branch": branch,
      };

      final response = await _apiHandler.get<ReceptionistsModel>(
        ApiConstants.receptionists,
        queryParameters: query,
        cancelKey: 'getAllReceptionists',
        fromJson: (json) => ReceptionistsModel.fromJson(json),
      );

      // Check if the response was successful
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        // Handle error case
        throw Exception(response.message ?? 'Failed to fetch receptionists');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Receptionist> getReceptionist({
    required String id,
  }) async {
    try {
      final response = await _apiHandler.get<Receptionist>(
        '${ApiConstants.receptionists}/$id',
        cancelKey: 'getReceptionist',
        fromJson: (json) => Receptionist.fromJson(json),
      );

      // Check if the response was successful
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        // Handle error case
        throw Exception(response.message ?? 'Failed to fetch receptionist');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<CapabilityCatalog> getCapabilityCatalog() async {
    final response = await _apiHandler.get<CapabilityCatalog>(
      '${ApiConstants.capabilities}/catalog',
      cancelKey: 'getCapabilityCatalog',
      fromJson: (json) =>
          CapabilityCatalog.fromJson(Map<String, dynamic>.from(json)),
    );
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception(response.message ?? 'Failed to fetch capability catalog');
  }

  Future<CapabilityModel> getAllCapability() async {
    try {
    final response = await _apiHandler.get<CapabilityModel>(
      ApiConstants.capabilities,
      cancelKey: 'getAllCapability',
      fromJson: (json) => CapabilityModel.fromJson(json),
    );

    // Check if the response was successful
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      // Handle error case
      throw Exception(response.message ?? 'Failed to fetch capabilities');
    }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Receptionist> updateReceptionist({
    required String id,
    required Receptionist receptionist,
  }) async {
    try {
      Map<String, dynamic> data = {
        "name": receptionist.name?.trim(),
        "phone": receptionist.phone?.trim(),
        "branch": receptionist.branch?.id,
        if (receptionist.birthDate != null)
          "birthDate": receptionist.birthDate.toString(),
        if (receptionist.capability != null &&
            receptionist.capability!.isNotEmpty)
          "capabilities": receptionist.capability,
        if (receptionist.image != null && receptionist.image!.isNotEmpty)
          "image": receptionist.image,
      };

      final response = await _apiHandler.put<Receptionist>(
        '${ApiConstants.receptionists}/$id',
        data: data,
        cancelKey: 'updateReceptionist',
        fromJson: (json) => Receptionist.fromJson(json),
      );

      // Check if the response was successful
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        // Handle error case
        throw Exception(response.message ?? 'Failed to update receptionist');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<DataModel> deleteReceptionist({
    required String id,
  }) async {
    try {
      final response = await _apiHandler.delete<DataModel>(
        '${ApiConstants.receptionists}/$id',
        cancelKey: 'deleteReceptionist',
        fromJson: (json) => DataModel.fromJson(json),
      );

      // Check if the response was successful
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        // Handle error case
        throw Exception(response.message ?? 'Failed to delete receptionist');
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

      // Check if the response was successful
      if (response.success && response.data != null) {
        return response.data!;
      } else {
        // Handle error case
        throw Exception(response.message ?? 'Failed to fetch branches');
      }
    } catch (e) {
      rethrow;
    }
  }
}
