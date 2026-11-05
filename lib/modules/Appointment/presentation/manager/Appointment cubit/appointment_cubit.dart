import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../Branch/data/model/branches_model.dart' as branch;
import '../../../../Doctor/data/model/doctor_model.dart';
import '../../../data/models/appointment_model.dart' as model;
import '../../../data/repos/appointment_repo.dart';

part 'appointment_event.dart';
part 'appointment_state.dart';

class AppointmentCubit extends Bloc<AppointmentEvent, AppointmentState> {
  final AppointmentRepo appointmentRepo;
  final _searchSubject = BehaviorSubject<String>();
  DateTime? selectedTime;

  bool get connection => state.status != AppointmentUiState.noConnection;
  DoctorModel? get doctors => state.doctors;
  branch.BranchesModel? get branches => state.branches;
  model.AppointmentModel? get appointments => state.appointments;
  String get search => state.search;
  branch.Branch? get selectedBranch => state.selectedBranch;
  Doctor? get selectedDoctor => state.selectedDoctor;
  DateTime get selectedDate => state.selectedDate;

  AppointmentCubit(this.appointmentRepo) : super(AppointmentState()) {
    on<GetDoctorsEvent>(_onGetDoctors);
    on<GetBranchesEvent>(_onGetBranches);
    on<GetAppointmentsEvent>(_onGetAppointments);
    on<EditAppointmentEvent>(_onEditAppointment);
    on<SelectDateEvent>(_onSelectDate);
    on<SelectBranchEvent>(_onSelectBranch);
    on<SelectDoctorEvent>(_onSelectDoctor);
    on<SearchChangedEvent>(_onSearchChanged);
    on<RefreshAppointmentsEvent>(_onRefreshAppointments);
    on<LocalUpdateAppointmentStatusEvent>(_onLocalUpdateStatus);

    // Listen to search subject with debounce
    _searchSubject
        .debounceTime(const Duration(milliseconds: 700))
        .listen((searchText) {
      add(GetAppointmentsEvent(search: searchText));
    });
  }

  static AppointmentCubit get(BuildContext context) => BlocProvider.of(context);

  void onSearchChanged(String searchText) {
    add(SearchChangedEvent(searchText));
    _searchSubject.add(searchText);
  }

  Future<void> _onGetDoctors(
      GetDoctorsEvent event, Emitter<AppointmentState> emit) async {
    emit(state.copyWith(status: AppointmentUiState.loadingDoctors));
    try {
      final doctors = await appointmentRepo.getAllDoctors(
        branch: event.branch,
        isActive: event.isActive,
      );
      emit(state.copyWith(
        status: AppointmentUiState.success,
        doctors: doctors,
      ));
    } catch (e) {
      log(e.toString());
      emit(state.copyWith(
        status: AppointmentUiState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onGetBranches(
      GetBranchesEvent event, Emitter<AppointmentState> emit) async {
    emit(state.copyWith(status: AppointmentUiState.loadingBranches));
    try {
      final branches = await appointmentRepo.getAllBranches();
      emit(state.copyWith(
        status: AppointmentUiState.success,
        branches: branches,
      ));
    } catch (e) {
      log(e.toString());
      emit(state.copyWith(
        status: AppointmentUiState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onGetAppointments(
      GetAppointmentsEvent event, Emitter<AppointmentState> emit) async {
    // A silent fetch is the 5-second poll: it must not flash the shimmer, and a
    // transient network blip must not replace a good list with an error screen.
    if (!event.silent) {
      emit(state.copyWith(status: AppointmentUiState.loading));
    }

    try {
      final appointments = await appointmentRepo.getAllAppointment(
        date: event.date ?? state.selectedDate,
        branch: event.branch ?? state.selectedBranch?.id,
        doctor: event.doctor ?? state.selectedDoctor?.id,
        search: event.search ?? state.search,
      );

      final grouped = AppointmentHelper.groupAppointmentsByTimeSlot(
          appointments.appointments);

      emit(state.copyWith(
        status: AppointmentUiState.success,
        appointments: appointments,
        groupedAppointments: grouped,
      ));
    } catch (e) {
      log(e.toString());

      if (event.silent) {
        // Keep whatever is on screen and wait for the next tick.
        return;
      }

      if (e.toString().toLowerCase().contains('no internet')) {
        emit(state.copyWith(
          status: AppointmentUiState.noConnection,
          errorMessage: e.toString(),
        ));
      } else {
        emit(state.copyWith(
          status: AppointmentUiState.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onEditAppointment(
      EditAppointmentEvent event, Emitter<AppointmentState> emit) async {
    emit(state.copyWith(
      status: AppointmentUiState.editLoading,
      updatingAppointmentId: event.id,
      updatingAction: event.action,
    ));
    try {
      final result = await appointmentRepo.editAppointment(
        id: event.id,
        action: event.action,
        date: event.date,
        doctor: event.doctor,
        cancellationReason: event.cancellationReason,
      );

      SnackbarService.showSuccess(
        event.context,
        message: "Appointment Updated successfully",
      );

      // Update local state if needed
      if (state.appointments != null) {
        final updatedList =
            List<model.Appointment>.from(state.appointments!.appointments);
        final index = updatedList.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          updatedList[index] = result;
        }

        final newAppointments = model.AppointmentModel(
          appointments: updatedList,
          total: state.appointments!.total,
          totalPages: state.appointments!.totalPages,
          error: '',
        );

        final grouped =
            AppointmentHelper.groupAppointmentsByTimeSlot(updatedList);

        emit(state.copyWith(
          status: AppointmentUiState.editSuccess,
          appointments: newAppointments,
          groupedAppointments: grouped,
          updatingAppointmentId: null,
          updatingAction: null,
        ));
      } else {
        emit(state.copyWith(
          status: AppointmentUiState.editSuccess,
          updatingAppointmentId: null,
          updatingAction: null,
        ));
      }
    } catch (e) {
      log(e.toString());
      SnackbarService.showError(
        event.context,
        message: e.toString(),
      );
      emit(state.copyWith(
        status: AppointmentUiState.editError,
        errorMessage: e.toString(),
        updatingAppointmentId: null,
        updatingAction: null,
      ));
    }
  }

  void _onSelectDate(SelectDateEvent event, Emitter<AppointmentState> emit) {
    emit(state.copyWith(selectedDate: event.date));
    add(GetAppointmentsEvent());
  }

  void _onSelectBranch(SelectBranchEvent event, Emitter<AppointmentState> emit) {
    emit(state.copyWith(selectedBranch: event.selectedBranch));
    // add(GetAppointmentsEvent());
  }

  void _onSelectDoctor(SelectDoctorEvent event, Emitter<AppointmentState> emit) {
    emit(state.copyWith(selectedDoctor: event.selectedDoctor));
    // add(GetAppointmentsEvent());
  }

  void _onSearchChanged(SearchChangedEvent event, Emitter<AppointmentState> emit) {
    emit(state.copyWith(search: event.search));
  }

  void _onRefreshAppointments(RefreshAppointmentsEvent event, Emitter<AppointmentState> emit) {
     add(GetAppointmentsEvent());
  }

  void _onLocalUpdateStatus(
      LocalUpdateAppointmentStatusEvent event, Emitter<AppointmentState> emit) {
    if (state.appointments != null) {
      final updatedList =
          List<model.Appointment>.from(state.appointments!.appointments);
      final index = updatedList.indexWhere((e) => e.id.toString() == event.id);
      if (index != -1) {
        updatedList[index] = updatedList[index].copyWith(status: event.status);

        final newAppointments = model.AppointmentModel(
          appointments: updatedList,
          total: state.appointments!.total,
          totalPages: state.appointments!.totalPages,
          error: '',
        );

        final grouped =
            AppointmentHelper.groupAppointmentsByTimeSlot(updatedList);

        emit(state.copyWith(
          appointments: newAppointments,
          groupedAppointments: grouped,
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _searchSubject.close();
    return super.close();
  }
}

class AppointmentHelper {
  static Map<String, List<model.Appointment>> groupAppointmentsByTimeSlot(
      List<model.Appointment> appointments) {
    final Map<String, List<model.Appointment>> groupedAppointments = {
      'morning': [], // 00:00 - 11:59
      'afternoon': [], // 12:00 - 17:59
      'evening': [], // 18:00 - 23:59
    };

    for (var appointment in appointments) {
      if (appointment.datetime != null) {
        final hour = appointment.datetime!.hour;

        if (hour < 12) {
          groupedAppointments['morning']!.add(appointment);
        } else if (hour < 18) {
          groupedAppointments['afternoon']!.add(appointment);
        } else {
          groupedAppointments['evening']!.add(appointment);
        }
      }
    }

    groupedAppointments.forEach((_, appointments) {
      appointments.sort((a, b) => (a.datetime ?? DateTime.now())
          .compareTo(b.datetime ?? DateTime.now()));
    });

    return groupedAppointments;
  }
}
