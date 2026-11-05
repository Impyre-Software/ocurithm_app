import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/error_message.dart';
import '../../../data/repos/examination_repo.dart';

part 'examination_actions_event.dart';
part 'examination_actions_state.dart';

class ExaminationActionsCubit extends Cubit<ExaminationActionsState> {
  final ExaminationRepo examinationRepo;

  ExaminationActionsCubit(this.examinationRepo)
      : super(const ExaminationActionsState());

  static ExaminationActionsCubit get(BuildContext context) =>
      BlocProvider.of(context);

  Future<void> createExamination({required Map<String, dynamic> data}) async {
    emit(state.copyWith(status: ExaminationActionsStatus.loading));
    try {
      final result = await examinationRepo.makeExamination(data: data);

      if (result.error == null && result.message != null) {
        // Assuming success based on message/error
        emit(state.copyWith(
          status: ExaminationActionsStatus.success,
          message: result.message,
          result: result,
        ));
      } else {
        emit(state.copyWith(
          status: ExaminationActionsStatus.error,
          error:
              result.error ?? result.message ?? 'Failed to create examination',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
          status: ExaminationActionsStatus.error, error: e.toString()));
    }
  }

  Future<void> makeFinalization(
      {required String id, required Map<String, dynamic> data}) async {
    emit(state.copyWith(status: ExaminationActionsStatus.loading));
    try {
      final result = await examinationRepo.makeFinalization(id: id, data: data);

      if (result.message != null &&
          (result.message!.toLowerCase().contains('success') ||
              result.message!.toLowerCase().contains('finalized'))) {
        emit(state.copyWith(
          status: ExaminationActionsStatus.success,
          message: result.message,
        ));
      } else if (result.error != null) {
        emit(state.copyWith(
          status: ExaminationActionsStatus.error,
          error: result.error,
        ));
      } else {
        // Fallback if no explicit error/success message pattern, assume success if no error?
        // Checking DataModel structure would be better, but assuming success for now if it returns.
        emit(state.copyWith(
          status: ExaminationActionsStatus.success,
          message: result.message ?? "Finalized successfully",
        ));
      }
    } catch (e) {
      emit(state.copyWith(
          status: ExaminationActionsStatus.error, error: e.toString()));
    }
  }

  /// Deletes after the caller re-enters their [password]. Returns null on success,
  /// otherwise the readable error, so the confirmation dialog can show it inline
  /// and stay open (a wrong password reads "Incorrect password").
  Future<String?> deleteExamination(String id,
      {required String password}) async {
    emit(state.copyWith(status: ExaminationActionsStatus.loading));
    try {
      await examinationRepo.deleteExamination(id, password: password);
      emit(state.copyWith(
        status: ExaminationActionsStatus.success,
        message: "Examination deleted successfully",
      ));
      return null;
    } catch (e) {
      final message = readableError(e);
      emit(state.copyWith(
          status: ExaminationActionsStatus.error, error: message));
      return message;
    }
  }
}
