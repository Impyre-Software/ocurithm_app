import '../../../Branch/data/model/branches_model.dart';
import '../../../Branch/data/model/data.dart';
import '../../../Doctor/data/model/capability_model.dart';
import '../../../Login/data/model/login_response.dart';
import '../models/add_reception_model.dart';
import '../models/receptionists_model.dart';

/// Repository interface for Receptionist operations
/// Follows the clean architecture pattern used in Branch and Clinic modules
abstract class ReceptionistRepo {
  /// Create a new receptionist
  Future<AddReceptionistsModel> createReceptionist({
    required Receptionist receptionist,
  });

  /// Get all receptionists with optional filters
  Future<ReceptionistsModel> getAllReceptionists({
    int? page,
    String? search,
    String? clinic,
    String? branch,
  });

  /// Get a single receptionist by ID
  Future<Receptionist> getReceptionist({
    required String id,
  });

  /// Update an existing receptionist
  Future<Receptionist> updateReceptionist({
    required String id,
    required Receptionist receptionist,
  });

  /// Delete a receptionist
  Future<DataModel> deleteReceptionist({
    required String id,
  });

  /// Get all branches (helper method for dropdowns)
  Future<BranchesModel> getAllBranches();

  Future<CapabilityModel> getAllCapability();

  /// Areas and task bundles for the capability editor.
  Future<CapabilityCatalog> getCapabilityCatalog();
}
