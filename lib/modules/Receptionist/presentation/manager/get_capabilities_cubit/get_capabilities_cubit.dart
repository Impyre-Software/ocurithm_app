import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocurithm/modules/Login/data/model/login_response.dart';
import '../../../data/repos/receptionist_repo.dart';

part 'get_capabilities_state.dart';
part 'get_capabilities_event.dart';

class GetCapabilitiesCubit
    extends Bloc<GetCapabilitiesEvent, GetCapabilitiesState> {
  final ReceptionistRepo _receptionistRepo;

  GetCapabilitiesCubit(this._receptionistRepo)
      : super(const GetCapabilitiesState()) {
    on<GetAllCapabilitiesEvent>(_onGetAllCapabilities);
  }

  Future<void> _onGetAllCapabilities(
    GetAllCapabilitiesEvent event,
    Emitter<GetCapabilitiesState> emit,
  ) async {
    emit(state.copyWith(status: GetCapabilitiesStatus.loading));

    try {
      final response = await _receptionistRepo.getAllCapability();
      // Best effort: without the catalog the editor still works as a flat list.
      CapabilityCatalog? catalog;
      try {
        catalog = await _receptionistRepo.getCapabilityCatalog();
      } catch (_) {
        catalog = null;
      }

      if (response.capabilities.isNotEmpty) {
        emit(state.copyWith(
          status: GetCapabilitiesStatus.success,
          capabilities: response.capabilities,
          catalog: catalog,
        ));
      } else {
        emit(state.copyWith(
          status: GetCapabilitiesStatus.error,
          errorMessage: 'No capabilities found',
        ));
      }
    } catch (e) {
      if (e.toString().contains('No internet connection')) {
        // Assuming the repo or interceptor might throw this text or we can catch specific exception types
        emit(state.copyWith(
          status: GetCapabilitiesStatus.noConnection,
          errorMessage: 'No internet connection',
        ));
      } else {
        emit(state.copyWith(
          status: GetCapabilitiesStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }
}
