import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ocurithm/core/utils/colors.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';
import 'package:ocurithm/core/widgets/custom_freeze_loading.dart';
import 'package:ocurithm/modules/Appointment/presentation/manager/Appointment cubit/appointment_cubit.dart';
import 'package:ocurithm/modules/Examination/presentation/manager/examination_actions_cubit/examination_actions_cubit.dart';
import 'package:ocurithm/modules/Examination/presentation/manager/examination_form_cubit/examination_form_cubit.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/circle_view.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/header_view.dart';
import 'package:ocurithm/modules/Examination/data/catalog/measurements_constants.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/complain/complain_checklist.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/history/history_checklist.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/navigation_view.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/patient_bottom_sheet.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/prescription.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/review_examination.dart';
import 'package:ocurithm/modules/Save%20Reasons/presentation/views/widgets/save_reason_picker.dart';

import '../../../../../core/utils/app_style.dart';
import '../../../../../core/utils/services_locator.dart';
import '../../../../../core/widgets/DropdownPackage.dart';
import '../../../../../core/widgets/arrow_text_field.dart';
import '../../../../../core/widgets/height_spacer.dart';
import '../../../../../core/widgets/multi_select.dart';
import '../../../../../core/widgets/text_field.dart';
import '../../../../Appointment/data/models/appointment_model.dart';
import '../../../../Appointment/presentation/views/widgets/appointment_note.dart';
import '../../../../Medicine/presentation/manager/get_medicines_cubit/get_medicines_cubit.dart';

class MultiStepFormView extends StatelessWidget {
  const MultiStepFormView({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocListener<ExaminationActionsCubit, ExaminationActionsState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == ExaminationActionsStatus.loading) {
            customLoading(context, "");
          } else if (state.status == ExaminationActionsStatus.success) {
            Navigator.pop(context); // Close loading
            final action = context.read<ExaminationFormCubit>().action;

            if (action == "save") {
              Navigator.pop(context, true); // Pop the MultiStepFormPage
              SnackbarService.showSuccess(
                context,
                message: state.message ?? "Saved Successfully",
              );
            } else if (state.result != null &&
                state.result.examination != null) {
              // Show popup with Finalization and Cancel buttons
              _showFinalizationDialog(
                context,
                state.result.examination,
                state.result.doctor,
              );
            } else {
              // Fallback if result is empty? usually means just close.
              Navigator.pop(context, true);
              SnackbarService.showSuccess(
                context,
                message: state.message ?? "Success",
              );
            }
          } else if (state.status == ExaminationActionsStatus.error ||
              state.status == ExaminationActionsStatus.noConnection) {
            Navigator.pop(context); // Close loading
            SnackbarService.showError(
              context,
              message:
                  state.error ?? "Failed to finalize visit. Please try again.",
            );
          }
        },
        child: BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
            builder: (context, state) {
          final cubit = context.read<ExaminationFormCubit>();

          return Column(
            children: [
              ModernStepHeader(
                currentStep: cubit.currentStep,
                totalSteps: cubit.totalSteps,
                onPop: () {
                  if (cubit.currentStep > 0) {
                    cubit.previousStep();
                  } else {
                    Navigator.pop(context);
                  }
                },
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The booking note, so the doctor can read it mid-exam.
                    if (appointment.visibleNote != null)
                      IconButton(
                        tooltip: 'Appointment note',
                        onPressed: () {
                          WidgetsBinding.instance.focusManager.primaryFocus
                              ?.unfocus();
                          showAppointmentNoteSheet(context, appointment);
                        },
                        icon: Icon(Icons.sticky_note_2_outlined,
                            color: Colors.amber.shade700),
                      ),
                    IconButton(
                        onPressed: () async {
                          WidgetsBinding.instance.focusManager.primaryFocus
                              ?.unfocus();
                          if (appointment.patient?.id != null) {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => PatientDetailsBottomSheet(
                                patientId: appointment.patient!.id!,
                              ),
                            );
                          }
                        },
                        icon: SvgPicture.asset(
                          "assets/icons/patient.svg",
                          colorFilter: ColorFilter.mode(
                              Theme.of(context).iconTheme.color!,
                              BlendMode.srcIn),
                        )),
                  ],
                ),
              ),
              Expanded(
                // Wrapped with Expanded
                child: _buildStepContent(cubit.currentStep),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(int step) {
    final Widget content;
    switch (step) {
      case 0:
        content = const ComplainChecklist();
        break;
      case 1:
        content = const HistoryChecklist();
        break;
      case 2:
        content = const StepThreeContent();
        break;
      case 3:
        content = ExaminationReviewScreen(appointment: appointment);
        break;
      default:
        content = const SizedBox.shrink();
    }

    // Keying on the step forces a fresh scrollable on every transition, so the next
    // step always starts at the top instead of inheriting the previous scroll offset.
    return KeyedSubtree(key: ValueKey<int>(step), child: content);
  }

  void _showFinalizationDialog(
    BuildContext context,
    dynamic examination,
    dynamic doctor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colorz.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 32,
                    color: Colorz.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Examination Created',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The examination has been created successfully. Would you like to proceed with finalization?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          // Update appointment status to completed (proceed)
                          context.read<AppointmentCubit>().add(
                                EditAppointmentEvent(
                                  context: context,
                                  id: appointment.id.toString(),
                                  action: 'proceed',
                                ),
                              );
                          // Pop the MultiStepFormPage
                          Navigator.pop(context, true);
                          SnackbarService.showSuccess(
                            context,
                            message: 'Appointment marked as completed',
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          // Navigate to finalization page
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MultiBlocProvider(
                                providers: [
                                  BlocProvider(
                                      create: (context) =>
                                          sl<ExaminationActionsCubit>()),
                                  BlocProvider(
                                      create: (context) =>
                                          sl<GetMedicinesCubit>()
                                            ..getMedicines()),
                                ],
                                child: MedicalTreeForm(
                                  examination: examination,
                                  appointment: appointment,
                                  doctor: doctor,
                                ),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colorz.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Finalization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StepThreeContent extends StatefulWidget {
  const StepThreeContent({super.key});

  @override
  State<StepThreeContent> createState() => _StepThreeContentState();
}

class _StepThreeContentState extends State<StepThreeContent> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      children: const [EyeExaminationView()],
    );
  }
}

// Extract segment label to a separate widget for better performance
class SegmentLabel extends StatelessWidget {
  final String text;
  final int index;
  final Color color;

  const SegmentLabel({
    super.key,
    required this.text,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        text,
        style: appStyle(
          context,
          18,
          color,
          FontWeight.w500,
        ),
      ),
    );
  }
}

class EyeExaminationView extends StatelessWidget {
  const EyeExaminationView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();
    final List<Color> colorList = [
      Colors.grey[400]!,
      Colors.black,
      Colors.white,
    ];

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Padding(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Confrontation field",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color! ?? Colors.black,
                  FontWeight.bold),
            ),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: QuadrantContainer(
                    // Left side configuration
                    containerSize: 300,
                    title: "right eye",
                    colorList: colorList,
                    tapCounts: [
                      cubit.rightTopLeftTapCount,
                      cubit.rightTopRightTapCount,
                      cubit.rightBottomLeftTapCount,
                      cubit.rightBottomRightTapCount,
                    ],
                    tapHandlers: [
                      cubit.rightTopLeftHandleTap,
                      cubit.rightTopRightHandleTap,
                      cubit.rightBottomLeftHandleTap,
                      cubit.rightBottomRightHandleTap,
                    ],

                    side: 'right',
                  ),
                ),
                Expanded(
                  child: QuadrantContainer(
                    // Left side configuration
                    containerSize: 300,
                    title: 'left eye',
                    colorList: colorList,
                    tapCounts: [
                      cubit.leftTopLeftTapCount,
                      cubit.leftTopRightTapCount,
                      cubit.leftBottomLeftTapCount,
                      cubit.leftBottomRightTapCount,
                    ],
                    tapHandlers: [
                      cubit.leftTopLeftHandleTap,
                      cubit.leftTopRightHandleTap,
                      cubit.leftBottomLeftHandleTap,
                      cubit.leftBottomRightHandleTap,
                    ],

                    side: 'left',
                  ),
                ),
              ],
            ),
            const HeightSpacer(size: 10),
            Text(
              "Old Glasses",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [RightOldGlasses(), LeftOldGlasses()],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "Auto-refraction",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [RightAutorefContent(), LeftAutorefContent()],
              ),
            ),
            // Cycloplegic refraction only exists on a resumed visit whose last save
            // was made for a reason that allows it; the API folds that whole rule
            // into one flag.
            if (cubit.allowCycloplegicRefraction) ...[
              const HeightSpacer(size: 8),
              Text(
                "Cycloplegic Refraction",
                style: appStyle(
                    context,
                    18,
                    Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    FontWeight.bold),
              ),
              const HeightSpacer(size: 4),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    RightCycloplegicRefractionContent(),
                    LeftCycloplegicRefractionContent()
                  ],
                ),
              ),
            ],
            const HeightSpacer(size: 8),
            Text(
              "Refined Refraction",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  RightRefinedRefractionContent(),
                  LeftRefinedRefractionContent()
                ],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "Visual Acuity",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  RightVisualAcuityContent(),
                  LeftVisualAcuityContent()
                ],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "IOP (mmHg)",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [RightIOPContent(), LeftIOPContent()],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "Pupils",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [RightPupilsContent(), LeftPupilsContent()],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "EyeLid & Physical",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [RightEyeLid(), LeftEyeLid()],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "Eye Structure",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  RightAdditionalExaminationContent(),
                  LeftAdditionalExaminationContent()
                ],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "Fundus Examination",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const HeightSpacer(size: 4),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  FundusExaminationContent(isLeftEye: false),
                  FundusExaminationContent(isLeftEye: true)
                ],
              ),
            ),
            const HeightSpacer(size: 8),
            Text(
              "External Features ",
              style: appStyle(
                  context,
                  18,
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                  FontWeight.bold),
            ),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                SlitLampExaminationContent(isLeftEye: false),
                SlitLampExaminationContent(isLeftEye: true)
              ],
            ),
            StepNavigation(
              onPrevious: () => cubit.currentStep > 0
                  ? cubit.previousStep()
                  : Navigator.pop(context),
              onNext: () => cubit.nextStep(),
              isLastStep: cubit.currentStep == cubit.totalSteps - 1,
              canGoBack: true,
              canContinue: cubit.currentStep < cubit.totalSteps - 1,
              onSave: () async {
                if (cubit.appointmentData == null) return;

                // Cancelling the reason sheet cancels the save; a clinic with no
                // reasons configured saves without one.
                final pick = await promptForSaveReason(context);
                if (pick == null || !context.mounted) return;

                cubit.action = "save";
                cubit.saveReasonId = pick.id;
                context
                    .read<ExaminationActionsCubit>()
                    .createExamination(data: cubit.examinationData());
              },
              onConfirm: () async {
                if (cubit.appointmentData != null) {
                  cubit.action = "create";

                  context
                      .read<ExaminationActionsCubit>()
                      .createExamination(data: cubit.examinationData());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RightAutorefContent extends StatelessWidget {
  const RightAutorefContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: cubit.rightAurorefSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField('aurorefSpherical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: cubit.rightAurorefCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField('aurorefCylindrical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: cubit.rightAurorefAxis,
                onChanged: (selected) {
                  cubit.updateRightEyeField('aurorefAxis', selected);
                },
              ),
              // Add other Autoref fields...
            ],
          ),
        ),
      ),
    );
  }
}

class LeftAutorefContent extends StatelessWidget {
  const LeftAutorefContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: cubit.leftAurorefSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('aurorefSpherical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: cubit.leftAurorefCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('aurorefCylindrical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: cubit.leftAurorefAxis,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('aurorefAxis', selected);
                },
              ),
              // Add other Autoref fields...
            ],
          ),
        ),
      ),
    );
  }
}

class RightOldGlasses extends StatelessWidget {
  const RightOldGlasses({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: cubit.rightOldSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField('oldSpherical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: cubit.rightOldCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField('oldCylindrical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: cubit.rightOldAxis,
                onChanged: (selected) {
                  cubit.updateRightEyeField('oldAxis', selected);
                },
              ),
              const SizedBox(height: 8),
              // Same option list as UCVA/BCVA (web: SelectField
              // options={MEASUREMENT_ENUMS.ucva}).
              ArrowTextField(
                items: cubit.data['UCVA'] ?? [],
                textRow: "VA :",
                selectedValue: cubit.rightOldGlassesVa,
                onChanged: (selected) {
                  cubit.updateRightEyeField('oldGlassesVa', selected);
                },
              ),
              // Add other Autoref fields...
            ],
          ),
        ),
      ),
    );
  }
}

class LeftOldGlasses extends StatelessWidget {
  const LeftOldGlasses({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: cubit.leftOldSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('oldSpherical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: cubit.leftOldCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('oldCylindrical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: cubit.leftOldAxis,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('oldAxis', selected);
                },
              ),
              const SizedBox(height: 8),
              // Same option list as UCVA/BCVA (web: SelectField
              // options={MEASUREMENT_ENUMS.ucva}).
              ArrowTextField(
                items: cubit.data['UCVA'] ?? [],
                textRow: "VA :",
                selectedValue: cubit.leftOldGlassesVa,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('oldGlassesVa', selected);
                },
              ),
              // Add other Autoref fields...
            ],
          ),
        ),
      ),
    );
  }
}

class ModifiedExpandableContainer extends StatefulWidget {
  final String title;
  final Widget content;

  const ModifiedExpandableContainer({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  State<ModifiedExpandableContainer> createState() =>
      _ModifiedExpandableContainerState();
}

class _ModifiedExpandableContainerState
    extends State<ModifiedExpandableContainer> {
  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              spreadRadius: 2,
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.all(8),
                child: widget.content,
              ),
          ],
        ),
      ),
    );
  }
}

class RightVisualAcuityContent extends StatefulWidget {
  const RightVisualAcuityContent({super.key});

  @override
  State<RightVisualAcuityContent> createState() =>
      _RightVisualAcuityContentState();
}

class _RightVisualAcuityContentState extends State<RightVisualAcuityContent> {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['UCVA'] ?? [],
                textRow: "UCVA :",
                radius: 15,
                height: 40,
                selectedValue: cubit.rightUCVA,
                onChanged: (selected) {
                  cubit.updateRightEyeField('ucva', selected);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['BCVA'] ?? [],
                textRow: "BCVA :",
                radius: 15,
                height: 40,
                selectedValue: cubit.rightBCVA,
                onChanged: (selected) {
                  cubit.updateRightEyeField('bcva', selected);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeftVisualAcuityContent extends StatefulWidget {
  const LeftVisualAcuityContent({super.key});

  @override
  State<LeftVisualAcuityContent> createState() =>
      _LeftVisualAcuityContentState();
}

class _LeftVisualAcuityContentState extends State<LeftVisualAcuityContent> {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['UCVA'] ?? [],
                textRow: "UCVA :",
                radius: 15,
                height: 40,
                selectedValue: cubit.leftUCVA,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('ucva', selected);
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['BCVA'] ?? [],
                textRow: "BCVA :",
                radius: 15,
                height: 40,
                selectedValue: cubit.leftBCVA,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('bcva', selected);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RightPupilsContent extends StatelessWidget {
  const RightPupilsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsShape'] ?? [],
                textRow: "Shape :",
                selectedValue: cubit.rightPupilsShape,
                onChanged: (selected) {
                  cubit.updateRightEyeField('pupilsShape', selected);
                },
              ),
              if (cubit.rightPupilsShape == "others")
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: TextField2(
                    controller: cubit.rightShapeController,
                    hintText: 'Shape:',
                    required: false,
                    onTextFieldChanged: (value) {
                      cubit.updateRightEyeField('lidsShape', value);
                    },
                    borderColor: Theme.of(context).dividerColor,
                    fillColor: Theme.of(context).cardColor,
                    radius: 30,
                  ),
                ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsLightReflexTest'] ?? [],
                textRow: "Light Reflex Test :",
                hintText: 'Light Reflex:',
                selectedValue: cubit.rightPupilsLightReflexTest,
                onChanged: (selected) {
                  cubit.updateRightEyeField('pupilsLightReflexTest', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsNearReflexTest'] ?? [],
                textRow: "Near Reflex Test:",
                hintText: 'Near Reflex',
                selectedValue: cubit.rightPupilsNearReflexTest,
                onChanged: (selected) {
                  cubit.updateRightEyeField('pupilsNearReflexTest', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsSwingingFlashLightTest'] ?? [],
                textRow: "Swinging Flash Test :",
                hintText: "Swinging Flash:",
                selectedValue: cubit.rightPupilsSwingingFlashLightTest,
                onChanged: (selected) {
                  cubit.updateRightEyeField(
                      'pupilsSwingingFlashLightTest', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsOtherDisorders'] ?? [],
                textRow: "Other Disorders :",
                selectedValue: cubit.rightPupilsOtherDisorders,
                onChanged: (selected) {
                  cubit.updateRightEyeField('pupilsOtherDisorders', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeftPupilsContent extends StatelessWidget {
  const LeftPupilsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsShape'] ?? [],
                textRow: "Shape :",
                selectedValue: cubit.leftPupilsShape,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('pupilsShape', selected);
                },
              ),
              if (cubit.leftPupilsShape == "others")
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: TextField2(
                    controller: cubit.leftShapeController,
                    hintText: 'Shape',
                    required: false,
                    onTextFieldChanged: (value) {
                      cubit.updateLeftEyeField('lidsShape', value);
                    },
                    borderColor: Theme.of(context).dividerColor,
                    fillColor: Theme.of(context).cardColor,
                    radius: 30,
                  ),
                ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsLightReflexTest'] ?? [],
                textRow: "Light Reflex Test :",
                hintText: 'Light Reflex',
                selectedValue: cubit.leftPupilsLightReflexTest,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('pupilsLightReflexTest', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsNearReflexTest'] ?? [],
                textRow: "Near Reflex Test :",
                hintText: "Near Reflex:",
                selectedValue: cubit.leftPupilsNearReflexTest,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('pupilsNearReflexTest', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsSwingingFlashLightTest'] ?? [],
                textRow: "Swinging Flash Test :",
                hintText: "Swinging Flash:",
                selectedValue: cubit.leftPupilsSwingingFlashLightTest,
                onChanged: (selected) {
                  cubit.updateLeftEyeField(
                      'pupilsSwingingFlashLightTest', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['PupilsOtherDisorders'] ?? [],
                textRow: "Other Disorders :",
                selectedValue: cubit.leftPupilsOtherDisorders,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('pupilsOtherDisorders', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eye title with its own Merge action. Web has one Merge per eye card; keeping the
/// single both-eyes button here meant a doctor could not merge one side alone.
class _MergeHeader extends StatelessWidget {
  const _MergeHeader({required this.title, required this.onMerge});

  final String title;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: appStyle(
                context,
                16,
                Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: onMerge,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            "Merge",
            style: appStyle(context, 14, Colorz.primaryColor, FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class RightRefinedRefractionContent extends StatelessWidget {
  const RightRefinedRefractionContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _MergeHeader(
                title: "Right eye",
                onMerge: () => cubit.mergeRefinedWithAuto(isLeftEye: false),
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: cubit.rightRefinedRefractionSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField(
                      'refinedRefractionSpherical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: cubit.rightRefinedRefractionCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField(
                      'refinedRefractionCylindrical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: cubit.rightRefinedRefractionAxis,
                onChanged: (selected) {
                  cubit.updateRightEyeField('refinedRefractionAxis', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['NearVisionAddition'] ?? [],
                textRow: "Near vision addition :",
                selectedValue: cubit.rightNearVisionAddition,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateRightEyeField('nearVisionAddition', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cycloplegic refraction for one eye. Same fields and ranges as autorefraction,
/// with a Merge that pushes the reading into refined refraction — the step a doctor
/// takes right after a cycloplegic reading.
class _CycloplegicRefractionContent extends StatelessWidget {
  const _CycloplegicRefractionContent({required this.isLeftEye});

  final bool isLeftEye;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _MergeHeader(
                title: isLeftEye ? "Left eye" : "Right eye",
                onMerge: () => cubit.mergeRefinedFrom(
                  isLeftEye: isLeftEye,
                  source: RefinedMergeSource.cycloplegic,
                ),
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: isLeftEye
                    ? cubit.leftCycloplegicSpherical
                    : cubit.rightCycloplegicSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.updateLeftEyeField('cycloplegicSpherical', selected);
                  } else {
                    cubit.updateRightEyeField('cycloplegicSpherical', selected);
                  }
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: isLeftEye
                    ? cubit.leftCycloplegicCylindrical
                    : cubit.rightCycloplegicCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.updateLeftEyeField(
                        'cycloplegicCylindrical', selected);
                  } else {
                    cubit.updateRightEyeField(
                        'cycloplegicCylindrical', selected);
                  }
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: isLeftEye
                    ? cubit.leftCycloplegicAxis
                    : cubit.rightCycloplegicAxis,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.updateLeftEyeField('cycloplegicAxis', selected);
                  } else {
                    cubit.updateRightEyeField('cycloplegicAxis', selected);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RightCycloplegicRefractionContent extends StatelessWidget {
  const RightCycloplegicRefractionContent({super.key});

  @override
  Widget build(BuildContext context) =>
      const _CycloplegicRefractionContent(isLeftEye: false);
}

class LeftCycloplegicRefractionContent extends StatelessWidget {
  const LeftCycloplegicRefractionContent({super.key});

  @override
  Widget build(BuildContext context) =>
      const _CycloplegicRefractionContent(isLeftEye: true);
}

class LeftRefinedRefractionContent extends StatelessWidget {
  const LeftRefinedRefractionContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _MergeHeader(
                title: "Left eye",
                onMerge: () => cubit.mergeRefinedWithAuto(isLeftEye: true),
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Spherical :",
                selectedValue: cubit.leftRefinedRefractionSpherical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField(
                      'refinedRefractionSpherical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefSpherical'] ?? [],
                textRow: "Cylindrical :",
                selectedValue: cubit.leftRefinedRefractionCylindrical,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField(
                      'refinedRefractionCylindrical', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AurorefAxis'] ?? [],
                textRow: "Axis :",
                selectedValue: cubit.leftRefinedRefractionAxis,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('refinedRefractionAxis', selected);
                },
              ),
              ArrowTextField(
                items: cubit.data['NearVisionAddition'] ?? [],
                textRow: "Near vision addition :",
                selectedValue: cubit.leftNearVisionAddition,
                showSignIndicator: true,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('nearVisionAddition', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RightIOPContent extends StatelessWidget {
  const RightIOPContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['IOP'] ?? [],
                textRow: "IOP :",
                selectedValue: cubit.rightIOP,
                onChanged: (selected) {
                  cubit.updateRightEyeField('iop', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['MeansOfMeasurement'] ?? [],
                textRow: "Means of Measurement:",
                hintText: "Measurement",
                selectedValue: cubit.rightMeansOfMeasurement,
                onChanged: (selected) {
                  cubit.updateRightEyeField('meansOfMeasurement', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AcquireAnotherIOPMeasurement'] ?? [],
                textRow: "Another IOP:",
                selectedValue: cubit.rightAcquireAnotherIOPMeasurement,
                onChanged: (selected) {
                  cubit.updateRightEyeField(
                      'acquireAnotherIOPMeasurement', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeftIOPContent extends StatelessWidget {
  const LeftIOPContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['IOP'] ?? [],
                textRow: "IOP :",
                selectedValue: cubit.leftIOP,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('iop', selected);
                },
              ),
              const SizedBox(height: 8),
              CustomColumnDropdown(
                items: cubit.data['MeansOfMeasurement'] ?? [],
                textRow: "Means of Measurement:",
                hintText: "Measurement",
                selectedValue: cubit.leftMeansOfMeasurement,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('meansOfMeasurement', selected);
                },
              ),
              const SizedBox(height: 8),
              ArrowTextField(
                items: cubit.data['AcquireAnotherIOPMeasurement'] ?? [],
                textRow: "Another IOP:",
                selectedValue: cubit.leftAcquireAnotherIOPMeasurement,
                onChanged: (selected) {
                  cubit.updateLeftEyeField(
                      'acquireAnotherIOPMeasurement', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SlitLampExaminationContent extends StatelessWidget {
  final bool isLeftEye;

  const SlitLampExaminationContent({super.key, required this.isLeftEye});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${isLeftEye ? 'Left' : 'Right'} eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              TextField2(
                controller: isLeftEye
                    ? cubit.leftLidsController
                    : cubit.rightLidsController,
                hintText: 'Lids',
                required: false,
                onTextFieldChanged: (value) {
                  // cubit.updateStepState();
                },
                borderColor: Theme.of(context).dividerColor,
                fillColor: Theme.of(context).cardColor,
                radius: 10,
              ),
              const SizedBox(height: 20),
              TextField2(
                controller: isLeftEye
                    ? cubit.leftLashesController
                    : cubit.rightLashesController,
                hintText: 'Lashes',
                required: false,
                onTextFieldChanged: (value) {
                  // cubit.updateStepState();
                },
                borderColor: Theme.of(context).dividerColor,
                fillColor: Theme.of(context).cardColor,
                radius: 10,
              ),
              const SizedBox(height: 20),
              TextField2(
                controller: isLeftEye
                    ? cubit.leftLacrimalController
                    : cubit.rightLacrimalController,
                hintText: 'Lacrimal System',
                required: false,
                onTextFieldChanged: (value) {
                  // cubit.updateStepState();
                },
                borderColor: Theme.of(context).dividerColor,
                fillColor: Theme.of(context).cardColor,
                radius: 10,
              ),
              const SizedBox(height: 20),
              TextField2(
                controller: isLeftEye
                    ? cubit.leftConjunctivaController
                    : cubit.rightConjunctivaController,
                hintText: 'Conjunctiva',
                required: false,
                onTextFieldChanged: (value) {
                  //  cubit.updateStepState();
                },
                borderColor: Theme.of(context).dividerColor,
                fillColor: Theme.of(context).cardColor,
                radius: 10,
              ),
              const SizedBox(height: 20),
              TextField2(
                controller: isLeftEye
                    ? cubit.leftScleraController
                    : cubit.rightScleraController,
                hintText: 'Sclera',
                required: false,
                onTextFieldChanged: (value) {
                  // cubit.updateStepState();
                },
                borderColor: Theme.of(context).dividerColor,
                fillColor: Theme.of(context).cardColor,
                radius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RightAdditionalExaminationContent extends StatelessWidget {
  const RightAdditionalExaminationContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomMultiSelectDropdown(
                items: corneaV1,
                textRow: "Corneal Findings :",
                hintText: "Corneal Findings :",
                allowCustomInput: true,
                selectedValues: cubit.rightCornea,
                onChanged: (selected) {
                  cubit.rightCornea = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: anteriorChamberV1,
                textRow: "Anterior Chamber :",
                hintText: "Anterior Chamber :",
                allowCustomInput: true,
                selectedValues: cubit.rightAnteriorChambre,
                onChanged: (selected) {
                  cubit.rightAnteriorChambre = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: irisV1,
                textRow: "Iris Findings :",
                hintText: "Iris Findings :",
                allowCustomInput: true,
                selectedValues: cubit.rightIris,
                onChanged: (selected) {
                  cubit.rightIris = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: lensV1,
                textRow: "Lens Status :",
                hintText: "Lens Status :",
                allowCustomInput: true,
                selectedValues: cubit.rightLens,
                onChanged: (selected) {
                  cubit.rightLens = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: anteriorVitreousV1,
                textRow: "Vitreous Status :",
                hintText: "Vitreous Status :",
                allowCustomInput: true,
                selectedValues: cubit.rightAnteriorVitreous,
                onChanged: (selected) {
                  cubit.setAnteriorVitreous(false, selected);
                },
              ),
              if (cubit.rightAnteriorVitreous.contains(vitreousHemorrhageOption)) ...[
                const SizedBox(height: 15),
                CustomColumnDropdown(
                  items: vhGradeOptions,
                  textRow: "VH Grade :",
                  hintText: "-",
                  selectedValue: cubit.rightVitreousHemorrhageGrade,
                  onChanged: (selected) {
                    cubit.setVitreousHemorrhageGrade(false, selected);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LeftAdditionalExaminationContent extends StatelessWidget {
  const LeftAdditionalExaminationContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomMultiSelectDropdown(
                items: corneaV1,
                textRow: "Corneal Findings :",
                hintText: "Corneal Findings :",
                allowCustomInput: true,
                selectedValues: cubit.leftCornea,
                onChanged: (selected) {
                  cubit.leftCornea = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: anteriorChamberV1,
                textRow: "Anterior Chamber :",
                hintText: "Anterior Chamber :",
                allowCustomInput: true,
                selectedValues: cubit.leftAnteriorChambre,
                onChanged: (selected) {
                  cubit.leftAnteriorChambre = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: irisV1,
                textRow: "Iris Findings :",
                hintText: "Iris Findings :",
                allowCustomInput: true,
                selectedValues: cubit.leftIris,
                onChanged: (selected) {
                  cubit.leftIris = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: lensV1,
                textRow: "Lens Status :",
                hintText: "Lens Status :",
                allowCustomInput: true,
                selectedValues: cubit.leftLens,
                onChanged: (selected) {
                  cubit.leftLens = selected;
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: anteriorVitreousV1,
                textRow: "Vitreous Status :",
                hintText: "Vitreous Status :",
                allowCustomInput: true,
                selectedValues: cubit.leftAnteriorVitreous,
                onChanged: (selected) {
                  cubit.setAnteriorVitreous(true, selected);
                },
              ),
              if (cubit.leftAnteriorVitreous.contains(vitreousHemorrhageOption)) ...[
                const SizedBox(height: 15),
                CustomColumnDropdown(
                  items: vhGradeOptions,
                  textRow: "VH Grade :",
                  hintText: "-",
                  selectedValue: cubit.leftVitreousHemorrhageGrade,
                  onChanged: (selected) {
                    cubit.setVitreousHemorrhageGrade(true, selected);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FundusExaminationContent extends StatelessWidget {
  final bool isLeftEye;

  const FundusExaminationContent({super.key, required this.isLeftEye});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("${isLeftEye ? 'Left' : 'Right'} eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const SizedBox(height: 8),
              CustomMultiSelectDropdown(
                items: fundusOpticDiscV1,
                textRow: "Disc Appearance :",
                hintText: "Disc Appearance :",
                allowCustomInput: true,
                selectedValues: isLeftEye
                    ? cubit.leftFundusOpticDisc
                    : cubit.rightFundusOpticDisc,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.leftFundusOpticDisc = selected;
                  } else {
                    cubit.rightFundusOpticDisc = selected;
                  }
                },
              ),
              const SizedBox(height: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Cup Disc Ratio :",
                    style: appStyle(
                        context,
                        14,
                        Theme.of(context).textTheme.bodyLarge?.color ??
                            Colors.black,
                        FontWeight.w500),
                  ),
                  const HeightSpacer(size: 2),
                  TextFormField(
                    initialValue: (isLeftEye
                            ? cubit.leftCupDiscRatio
                            : cubit.rightCupDiscRatio)
                        ?.toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: "0.0 - 1.0",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    onChanged: (v) => cubit.setCupDiscRatio(isLeftEye, v.trim()),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: fundusMaculaV1,
                textRow: "Macular Findings :",
                hintText: "Macular Findings :",
                allowCustomInput: true,
                selectedValues: isLeftEye
                    ? cubit.leftFundusMacula
                    : cubit.rightFundusMacula,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.leftFundusMacula = selected;
                  } else {
                    cubit.rightFundusMacula = selected;
                  }
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: cubit.data['FundusVessels'] ?? [],
                textRow: "Vessels :",
                hintText: "Vessels :",
                selectedValues: isLeftEye
                    ? cubit.leftFundusVessels
                    : cubit.rightFundusVessels,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.leftFundusVessels = selected;
                  } else {
                    cubit.rightFundusVessels = selected;
                  }
                },
              ),
              const SizedBox(height: 15),
              CustomMultiSelectDropdown(
                items: fundusPeripheryV1,
                textRow: "Retina :",
                hintText: "Retina :",
                allowCustomInput: true,
                selectedValues: isLeftEye
                    ? cubit.leftFundusPeriphery
                    : cubit.rightFundusPeriphery,
                onChanged: (selected) {
                  if (isLeftEye) {
                    cubit.leftFundusPeriphery = selected;
                  } else {
                    cubit.rightFundusPeriphery = selected;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RightEyeLid extends StatelessWidget {
  const RightEyeLid({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Right eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const HeightSpacer(size: 10),
              CustomColumnDropdown(
                items: cubit.data['EyelidPtosis'] ?? [],
                textRow: "Ptosis :",
                hintText: "-",
                selectedValue: cubit.rightEyelidPtosis,
                onChanged: (selected) {
                  cubit.updateRightEyeField('eyelidPtosis', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['EyelidLagophthalmos'] ?? [],
                textRow: "Lagophthalmos :",
                hintText: "-",
                selectedValue: cubit.rightEyelidLagophthalmos,
                onChanged: (selected) {
                  cubit.updateRightEyeField('eyelidLagophthalmos', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['PalpableLymphNodes'] ?? [],
                textRow: "Palpable Lymph Nodes :",
                hintText: "-",
                selectedValue: cubit.rightPalpableLymphNodes,
                onChanged: (selected) {
                  cubit.updateRightEyeField('palpableLymphNodes', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['PapableTemporalArtery'] ?? [],
                textRow: "PapableTemporalArtery:",
                hintText: "-",
                selectedValue: cubit.rightPapableTemporalArtery,
                onChanged: (selected) {
                  cubit.updateRightEyeField('papableTemporalArtery', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['Exophthalmometry'] ?? [],
                textRow: "Exophthalmometry:",
                hintText: "-",
                selectedValue: cubit.rightExophthalmometry,
                onChanged: (selected) {
                  cubit.updateRightEyeField('exophthalmometry', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeftEyeLid extends StatelessWidget {
  const LeftEyeLid({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();

    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Left eye",
                  style: appStyle(
                      context,
                      16,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      FontWeight.bold)),
              const HeightSpacer(size: 10),
              CustomColumnDropdown(
                items: cubit.data['EyelidPtosis'] ?? [],
                textRow: "Ptosis :",
                hintText: "-",
                selectedValue: cubit.leftEyelidPtosis,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('eyelidPtosis', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['EyelidLagophthalmos'] ?? [],
                textRow: "Lagophthalmos :",
                hintText: "-",
                selectedValue: cubit.leftEyelidLagophthalmos,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('eyelidLagophthalmos', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['PalpableLymphNodes'] ?? [],
                textRow: "Palpable Lymph Nodes :",
                hintText: "-",
                selectedValue: cubit.leftPalpableLymphNodes,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('palpableLymphNodes', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['PapableTemporalArtery'] ?? [],
                textRow: "PapableTemporalArtery:",
                hintText: "-",
                selectedValue: cubit.leftPapableTemporalArtery,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('papableTemporalArtery', selected);
                },
              ),
              const HeightSpacer(size: 15),
              CustomColumnDropdown(
                items: cubit.data['Exophthalmometry'] ?? [],
                textRow: "Exophthalmometry:",
                hintText: "-",
                selectedValue: cubit.leftExophthalmometry,
                onChanged: (selected) {
                  cubit.updateLeftEyeField('exophthalmometry', selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
