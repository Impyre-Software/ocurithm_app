part of 'get_capabilities_cubit.dart';

enum GetCapabilitiesStatus {
  initial,
  loading,
  success,
  error,
  noConnection,
}

extension GetCapabilitiesStatusX on GetCapabilitiesStatus {
  bool get isInitial => this == GetCapabilitiesStatus.initial;
  bool get isLoading => this == GetCapabilitiesStatus.loading;
  bool get isSuccess => this == GetCapabilitiesStatus.success;
  bool get isError => this == GetCapabilitiesStatus.error;
  bool get noConnection => this == GetCapabilitiesStatus.noConnection;
}

class GetCapabilitiesState {
  final GetCapabilitiesStatus status;
  final List<Capability>? capabilities;

  /// Areas and bundles; null when the API predates them or the call failed, in
  /// which case the editor falls back to a flat list.
  final CapabilityCatalog? catalog;
  final String? errorMessage;

  const GetCapabilitiesState({
    this.status = GetCapabilitiesStatus.initial,
    this.capabilities,
    this.catalog,
    this.errorMessage,
  });

  // Helper getters
  bool get isInitial => status.isInitial;
  bool get isLoading => status.isLoading;
  bool get isSuccess => status.isSuccess;
  bool get isError => status.isError;
  bool get noConnection => status.noConnection;

  GetCapabilitiesState copyWith({
    GetCapabilitiesStatus? status,
    List<Capability>? capabilities,
    CapabilityCatalog? catalog,
    String? errorMessage,
  }) {
    return GetCapabilitiesState(
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      catalog: catalog ?? this.catalog,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
