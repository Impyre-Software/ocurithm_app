import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ocurithm/core/widgets/height_spacer.dart';

import '../../../../../core/utils/colors.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../Appointment/data/models/appointment_model.dart';
import '../../../data/catalog/history_catalog.dart';
import '../../../data/catalog/complain_catalog.dart';
import '../../manager/examination_actions_cubit/examination_actions_cubit.dart';
import '../../manager/examination_form_cubit/examination_form_cubit.dart';
import 'circle_view.dart';
import 'examination_pdf_service.dart';
import 'navigation_view.dart';

class ExaminationReviewScreen extends StatefulWidget {
  const ExaminationReviewScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<ExaminationReviewScreen> createState() =>
      _ExaminationReviewScreenState();
}

class _ExaminationReviewScreenState extends State<ExaminationReviewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      if (_pageController.page?.round() != _selectedTab) {
        setState(() {
          _selectedTab = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExaminationFormCubit>();
    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (BuildContext context, state) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0).copyWith(bottom: 0),
          child: Column(
            spacing: 16,
            children: [
              // Print Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Examination Review',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ExaminationPdfService.generateAndPrintExamination(
                        appointment: widget.appointment,
                        cubit: cubit,
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colorz.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),

              // Patient Info and History Section
              Column(
                children: [
                  _buildPatientInfoCard(),
                  _buildHistorySection(),
                ],
              ),

              Column(
                spacing: 10,
                children: [
                  _buildEyeTitleRow(),
                  _buildSynchronizedQuadrantSection(),
                  _buildSynchronizedExaminationSection(
                    title: 'Old-Glasses',
                    sectionIndex: 0,
                    // Axis and VA are excluded, as on Refined Refraction.
                    signedLabels: const {'Spherical', 'Cylindrical'},
                    dataLE: {
                      'Spherical': FormatHelper.formatPositiveValue(
                          cubit.leftOldSpherical),
                      'Cylindrical': FormatHelper.formatPositiveValue(
                          cubit.leftOldCylindrical),
                      'Axis': cubit.leftOldAxis,
                      'VA': cubit.leftOldGlassesVa,
                    },
                    dataRE: {
                      'Spherical': FormatHelper.formatPositiveValue(
                          cubit.rightOldSpherical),
                      'Cylindrical': FormatHelper.formatPositiveValue(
                          cubit.rightOldCylindrical),
                      'Axis': cubit.rightOldAxis,
                      'VA': cubit.rightOldGlassesVa,
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'Auto-refraction',
                    sectionIndex: 0,
                    // Axis and VA are excluded, as on Refined Refraction.
                    signedLabels: const {'Spherical', 'Cylindrical'},
                    dataLE: {
                      'Spherical': FormatHelper.formatPositiveValue(
                          cubit.leftAurorefSpherical),
                      'Cylindrical': FormatHelper.formatPositiveValue(
                          cubit.leftAurorefCylindrical),
                      'Axis': cubit.leftAurorefAxis,
                    },
                    dataRE: {
                      'Spherical': FormatHelper.formatPositiveValue(
                          cubit.rightAurorefSpherical),
                      'Cylindrical': FormatHelper.formatPositiveValue(
                          cubit.rightAurorefCylindrical),
                      'Axis': cubit.rightAurorefAxis,
                    },
                  ),
                  // Absent from almost every visit, so the block is skipped rather
                  // than shown as a row of dashes.
                  if (_hasCycloplegicReading(cubit))
                    _buildSynchronizedExaminationSection(
                      title: 'Cycloplegic Refraction',
                      sectionIndex: 2,
                      signedLabels: const {'Spherical', 'Cylindrical'},
                      dataLE: {
                        'Spherical': FormatHelper.formatPositiveValue(
                            cubit.leftCycloplegicSpherical),
                        'Cylindrical': FormatHelper.formatPositiveValue(
                            cubit.leftCycloplegicCylindrical),
                        'Axis': cubit.leftCycloplegicAxis,
                      },
                      dataRE: {
                        'Spherical': FormatHelper.formatPositiveValue(
                            cubit.rightCycloplegicSpherical),
                        'Cylindrical': FormatHelper.formatPositiveValue(
                            cubit.rightCycloplegicCylindrical),
                        'Axis': cubit.rightCycloplegicAxis,
                      },
                    ),
                  _buildSynchronizedExaminationSection(
                    title: 'Refined Refraction',
                    sectionIndex: 2,
                    // Axis is excluded: it is always 0-180, so a sign says nothing.
                    signedLabels: const {
                      'Spherical',
                      'Cylindrical',
                      'NearVision',
                    },
                    dataLE: {
                      'Spherical': FormatHelper.formatPositiveValue(
                          cubit.leftRefinedRefractionSpherical),
                      'Cylindrical': FormatHelper.formatPositiveValue(
                          cubit.leftRefinedRefractionCylindrical),
                      'Axis': cubit.leftRefinedRefractionAxis,
                      'NearVision': FormatHelper.formatPositiveValue(
                          cubit.leftNearVisionAddition),
                    },
                    dataRE: {
                      'Spherical': FormatHelper.formatPositiveValue(
                          cubit.rightRefinedRefractionSpherical),
                      'Cylindrical': FormatHelper.formatPositiveValue(
                          cubit.rightRefinedRefractionCylindrical),
                      'Axis': cubit.rightRefinedRefractionAxis,
                      'NearVision': FormatHelper.formatPositiveValue(
                          cubit.rightNearVisionAddition),
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'Visual Acuity',
                    sectionIndex: 1,
                    dataLE: {
                      'UCVA': cubit.leftUCVA,
                      'BCVA': cubit.leftBCVA,
                    },
                    dataRE: {
                      'UCVA': cubit.rightUCVA,
                      'BCVA': cubit.rightBCVA,
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'IOP',
                    sectionIndex: 3,
                    dataLE: {
                      'IOP Value': cubit.leftIOP,
                      'Measurement Method': cubit.leftMeansOfMeasurement,
                      'Additional Measurement':
                          cubit.leftAcquireAnotherIOPMeasurement,
                    },
                    dataRE: {
                      'IOP Value': cubit.rightIOP,
                      'Measurement Method': cubit.rightMeansOfMeasurement,
                      'Additional Measurement':
                          cubit.rightAcquireAnotherIOPMeasurement,
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'Pupils',
                    sectionIndex: 4,
                    dataLE: {
                      'Shape': cubit.leftPupilsShape,
                      'Light Reflex': cubit.leftPupilsLightReflexTest,
                      'Near Reflex': cubit.leftPupilsNearReflexTest,
                      'Swinging Flashlight':
                          cubit.leftPupilsSwingingFlashLightTest,
                      'Other Disorders': cubit.leftPupilsOtherDisorders,
                    },
                    dataRE: {
                      'Shape': cubit.rightPupilsShape,
                      'Light Reflex': cubit.rightPupilsLightReflexTest,
                      'Near Reflex': cubit.rightPupilsNearReflexTest,
                      'Swinging Flashlight':
                          cubit.rightPupilsSwingingFlashLightTest,
                      'Other Disorders': cubit.rightPupilsOtherDisorders,
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'Eyelid & Physcal',
                    sectionIndex: 5,
                    dataLE: {
                      'Eyelid Ptosis': cubit.leftEyelidPtosis,
                      'Lagophthalmos': cubit.leftEyelidLagophthalmos,
                      'Palpable Lymph Nodes': cubit.leftPalpableLymphNodes,
                      'Papable Temporal Artery':
                          cubit.leftPapableTemporalArtery,
                      'Exophthalmometry': cubit.leftExophthalmometry,
                    },
                    dataRE: {
                      'Eyelid Ptosis': cubit.rightEyelidPtosis,
                      'Lagophthalmos': cubit.rightEyelidLagophthalmos,
                      'Palpable Lymph Nodes': cubit.rightPalpableLymphNodes,
                      'Papable Temporal Artery':
                          cubit.rightPapableTemporalArtery,
                      'Exophthalmometry': cubit.rightExophthalmometry,
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'Eye Structure',
                    sectionIndex: 7,
                    dataLE: {
                      'Corneal Findings': cubit.leftCornea.join(', '),
                      'Anterior Chamber': cubit.leftAnteriorChambre.join(', '),
                      'Iris Findings': cubit.leftIris.join(', '),
                      'Lens Status': cubit.leftLens.join(', '),
                      'Vitreous Status': cubit.leftAnteriorVitreous.join(', '),
                      if ((cubit.leftVitreousHemorrhageGrade ?? '')
                          .toString()
                          .isNotEmpty)
                        'VH Grade': cubit.leftVitreousHemorrhageGrade.toString(),
                    },
                    dataRE: {
                      'Corneal Findings': cubit.rightCornea.join(', '),
                      'Anterior Chamber': cubit.rightAnteriorChambre.join(', '),
                      'Iris Findings': cubit.rightIris.join(', '),
                      'Lens Status': cubit.rightLens.join(', '),
                      'Vitreous Status': cubit.rightAnteriorVitreous.join(', '),
                      if ((cubit.rightVitreousHemorrhageGrade ?? '')
                          .toString()
                          .isNotEmpty)
                        'VH Grade':
                            cubit.rightVitreousHemorrhageGrade.toString(),
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'Fundus Examination',
                    sectionIndex: 8,
                    dataLE: {
                      'Disc Appearance': cubit.leftFundusOpticDisc.join(', '),
                      if ((cubit.leftCupDiscRatio ?? '').toString().isNotEmpty)
                        'Cup Disc Ratio': cubit.leftCupDiscRatio.toString(),
                      'Macular Findings': cubit.leftFundusMacula.join(', '),
                      'Vessels': cubit.leftFundusVessels.join(', '),
                      'Retina': cubit.leftFundusPeriphery.join(', '),
                    },
                    dataRE: {
                      'Disc Appearance': cubit.rightFundusOpticDisc.join(', '),
                      if ((cubit.rightCupDiscRatio ?? '').toString().isNotEmpty)
                        'Cup Disc Ratio': cubit.rightCupDiscRatio.toString(),
                      'Macular Findings': cubit.rightFundusMacula.join(', '),
                      'Vessels': cubit.rightFundusVessels.join(', '),
                      'Retina': cubit.rightFundusPeriphery.join(', '),
                    },
                  ),
                  _buildSynchronizedExaminationSection(
                    title: 'External Features',
                    sectionIndex: 6,
                    dataLE: {
                      'Lids': cubit.leftLidsController.text,
                      'Lashes': cubit.leftLashesController.text,
                      'Lacrimal': cubit.leftLacrimalController.text,
                      'Conjunctiva': cubit.leftConjunctivaController.text,
                      'Sclera': cubit.leftScleraController.text,
                    },
                    dataRE: {
                      'Lids': cubit.rightLidsController.text,
                      'Lashes': cubit.rightLashesController.text,
                      'Lacrimal': cubit.rightLacrimalController.text,
                      'Conjunctiva': cubit.rightConjunctivaController.text,
                      'Sclera': cubit.rightScleraController.text,
                    },
                  ),
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
                  if (cubit.appointmentData != null) {
                    cubit.action = "save";
                    context
                        .read<ExaminationActionsCubit>()
                        .createExamination(data: cubit.examinationData());
                  }
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
      ),
    );
  }

  Widget _buildQuadrantSection({required bool isLeft}) {
    final cubit = context.read<ExaminationFormCubit>();

    // Define color list matching your original implementation
    final List<Color> _colorList = [
      Colors.grey[400]!,
      Colors.black,
      Colors.white,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 0),
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.all(0),
          title: Text(
            'Confrontation Fields',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          children: [
            QuadrantContainer(
              containerSize: 280,
              colorList: _colorList,
              tapCounts: isLeft
                  ? [
                      cubit.leftTopLeftTapCount,
                      cubit.leftTopRightTapCount,
                      cubit.leftBottomLeftTapCount,
                      cubit.leftBottomRightTapCount,
                    ]
                  : [
                      cubit.rightTopLeftTapCount,
                      cubit.rightTopRightTapCount,
                      cubit.rightBottomLeftTapCount,
                      cubit.rightBottomRightTapCount,
                    ],
              side: isLeft ? 'left' : 'right',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeTitleRow() {
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: Text('Right Eye',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              )),
        ),
        Expanded(
          child: Text('Left Eye',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              )),
        ),
      ],
    );
  }

  Widget _buildSynchronizedQuadrantSection() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Expanded(child: _buildQuadrantSection(isLeft: false)),
          Expanded(child: _buildQuadrantSection(isLeft: true)),
        ],
      ),
    );
  }

  Widget _buildSynchronizedExaminationSection({
    required String title,
    required int sectionIndex,
    required Map<String, dynamic> dataLE,
    required Map<String, dynamic> dataRE,
    Set<String> signedLabels = const {},
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Expanded(
            child: _buildExaminationSection(
              title: title,
              data: dataRE,
              sectionIndex: sectionIndex,
              isLeft: false,
              signedLabels: signedLabels,
            ),
          ),
          Expanded(
            child: _buildExaminationSection(
              title: title,
              data: dataLE,
              sectionIndex: sectionIndex,
              isLeft: true,
              signedLabels: signedLabels,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExaminationSection({
    required String title,
    required Map<String, dynamic> data,
    required int sectionIndex,
    required bool isLeft,
    Set<String> signedLabels = const {},
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 0),
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: false,
          // Add this
          initiallyExpanded: true,
          enabled: false,
          // Ad d this
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          // Optional for better spacing
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          // Add this for better alignment
          childrenPadding: const EdgeInsets.all(16),
          // Add this for better padding

          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          children: [
            Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.entries
                  .map((entry) => _buildDataRow(
                        entry.key,
                        entry.value,
                        showSign: signedLabels.contains(entry.key),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value, {bool showSign = false}) {
    final displayValue = value?.toString() ?? 'N/A';
    final isLongText = displayValue.length > 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            if (showSign) ...[
              const SizedBox(width: 4),
              _buildSignIndicator(value),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: isLongText ? 13 : 14,
              color:
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Whether either eye carries a cycloplegic reading worth showing.
  bool _hasCycloplegicReading(ExaminationFormCubit cubit) => [
        cubit.leftCycloplegicSpherical,
        cubit.leftCycloplegicCylindrical,
        cubit.leftCycloplegicAxis,
        cubit.rightCycloplegicSpherical,
        cubit.rightCycloplegicCylindrical,
        cubit.rightCycloplegicAxis,
      ].any((value) {
        if (value == null) return false;
        final text = value.toString().trim();
        return text.isNotEmpty && text != '-' && text != 'N/A';
      });

  /// Green outlined plus for a positive reading, red outlined minus for a negative
  /// one. Mirrors the badge on the measurements step so the summary reads the same.
  Widget _buildSignIndicator(dynamic value) {
    final sign = FormatHelper.measurementSign(value);
    if (sign == 0) return const SizedBox.shrink();

    final isPositive = sign > 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(
        isPositive ? Icons.add : Icons.remove,
        size: 12,
        color: color,
      ),
    );
  }

  String? calculateAge(DateTime? birthDate) {
    if (birthDate == null) {
      print("Error: Birth date is null.");
      return "N/A";
    }

    try {
      DateTime currentDate = DateTime.now();
      int age = currentDate.year - birthDate.year;

      // Adjust if the birthday has not occurred yet this year
      if (currentDate.month < birthDate.month ||
          (currentDate.month == birthDate.month &&
              currentDate.day < birthDate.day)) {
        age--;
      }

      return '$age Years';
    } catch (e) {
      print("Error calculating age: $e");
      return "N/A";
    }
  }

  Widget _buildPatientInfoCard() {
    final cubit = context.read<ExaminationFormCubit>();

    return Card(
      elevation: 4,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardColor),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person_outline,
                      color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cubit.appointmentData?.patient?.name ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        cubit.appointmentData?.patient?.nationalId ?? 'Unknown',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.calendar_today,
                  label: 'Age',
                  value:
                      '${calculateAge(cubit.appointmentData?.patient?.birthDate)}',
                ),
                _buildInfoItem(
                  icon: Icons.person,
                  label: 'Gender',
                  value: cubit.appointmentData?.patient?.gender ?? 'N/A',
                ),
                _buildInfoItem(
                  icon: Icons.phone,
                  label: 'Contact',
                  value: cubit.appointmentData?.patient?.phone ?? 'N/A',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colorz.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return BlocBuilder<ExaminationFormCubit, ExaminationFormState>(
      builder: (context, state) {
        final cubit = context.read<ExaminationFormCubit>();

        // Structured complaint entries first (visible fields per selected option;
        // zero-field options show as "Present"), then legacy free-text complaints.
        final complaintsData = <String, String>{};
        for (final optKey in cubit.selectedComplaints) {
          final entries = visibleComplainEntries(optKey, cubit.complainValues);
          if (entries.isEmpty) {
            complaintsData[complainOptionLabel(optKey)] = 'Present';
          } else {
            for (final e in entries) {
              complaintsData['${complainOptionLabel(optKey)} — ${e.key}'] = e.value;
            }
          }
        }
        complaintsData.addAll({
          'Complain One': cubit.oneComplaintController.text,
          'Complain Two': cubit.twoComplaintController.text,
          'Complain Three': cubit.threeComplaintController.text,
        });

        // Structured checklist entries first (visible, non-empty fields per
        // selected category), then the legacy free-text notes.
        final historyData = <String, String>{};
        for (final catKey in cubit.selectedHistoryCategories) {
          for (final e in visibleHistoryEntries(catKey, cubit.historyValues)) {
            historyData['${historyCategoryLabel(catKey)} — ${e.key}'] = e.value;
          }
        }
        historyData.addAll({
          'Family History': cubit.familyHistoryController.text,
          'Present Illness': cubit.presentIllnessController.text,
          'Past History': cubit.pastHistoryController.text,
          'Medication History': cubit.medicationHistoryController.text,
        });

        return Column(
          children: [
            HeightSpacer(size: 0),
            _buildExpandableCard(
              title: 'Medical History',
              icon: Icons.history,
              content: historyData,
              color: Theme.of(context).primaryColor,
              isHistoryCard: true,
            ),
            _buildExpandableCard(
              title: 'Chief Complaints',
              icon: Icons.medical_information,
              content: complaintsData,
              color: Theme.of(context).primaryColor,
              isComplaintCard: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required dynamic content,
    required Color color,
    bool isComplaintCard = false,
    bool isHistoryCard = false,
  }) {
    return Card(
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          enabled: false,
          initiallyExpanded: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            if (isHistoryCard && content is Map<String, String>)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content.entries.map((entry) {
                  return SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            top: 4,
                            bottom: 16,
                          ),
                          child: Text(
                            entry.value.isEmpty
                                ? 'No data available'
                                : entry.value,
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color ??
                                  Colors.black,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else if (isComplaintCard && content is Map<String, String>)
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content.isEmpty
                      ? [
                          Text(
                            'No complaints available',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).primaryColor,
                              height: 1.5,
                            ),
                          ),
                        ]
                      : content.entries.map((entry) {
                          return SizedBox(
                            width: MediaQuery.of(context).size.width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 4,
                                    bottom: 16,
                                  ),
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color ??
                                          Colors.black,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              )
            else
              Text(
                content?.isEmpty ?? true ? 'No data available' : content,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).primaryColor,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
