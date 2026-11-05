import 'package:flutter/material.dart' hide Action;
import 'package:ocurithm/core/utils/colors.dart';
import 'package:ocurithm/core/utils/format_helper.dart';
import 'package:ocurithm/core/utils/glasses_prescription.dart';
import 'package:ocurithm/core/widgets/height_spacer.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/circle_view.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/prescription_pdf.dart';
import 'package:ocurithm/modules/Examination/data/catalog/history_catalog.dart';
import 'package:ocurithm/modules/Examination/data/catalog/complain_catalog.dart';
import 'package:ocurithm/modules/Patient/data/model/one_exam.dart';

/// Whether a recorded value is worth showing in the examination details.
///
/// Empty means: null, blank text, the "-" placeholder dropdowns save when nothing
/// was picked, "N/A", or an empty list. A real reading of 0 / "0.00" (plano) is a
/// value. Mirrors web's `ExaminationDetailsDailog/has-value.ts`.
bool hasEnteredValue(dynamic value) {
  if (value == null) return false;
  if (value is Iterable) return value.any(hasEnteredValue);
  final text = value.toString().trim();
  return text.isNotEmpty && text != '-' && text.toUpperCase() != 'N/A';
}

/// Shown for one eye's gap when the other eye recorded the field, so the two
/// eyes' rows stay lined up.
const String _emptyEyeValue = '—';

/// Whether either eye carries a cycloplegic reading worth showing.
bool _hasCycloplegicReading(ExaminationModel examination) {
  final measurements = examination.examination?.measurements ?? const [];

  return measurements.any((m) => [
        m.cycloplegicSpherical,
        m.cycloplegicCylindrical,
        m.cycloplegicAxis,
      ].any(hasEnteredValue));
}

/// Untouched quadrants stay at 0 (the form's starting colour), so all-zero in
/// both eyes means the confrontation field was never recorded.
bool _hasConfrontationReading(ExaminationModel examination) {
  final measurements = examination.examination?.measurements ?? const [];
  return measurements.any((m) => [
        m.topLeft,
        m.topRight,
        m.bottomLeft,
        m.bottomRight,
      ].any((value) => value != null && value != 0));
}

/// Whether either eye recorded any measurement at all. `toJson` omits the old
/// glasses and near-addition fields, so those are checked explicitly.
bool _hasAnyMeasurement(ExaminationModel examination) {
  const skipped = {
    'eye',
    'examination',
    'topLeft',
    'topRight',
    'bottomLeft',
    'bottomRight',
    'createdAt',
    'updatedAt',
    'id',
  };
  final measurements = examination.examination?.measurements ?? const [];
  return _hasConfrontationReading(examination) ||
      measurements.any((m) =>
          [
            m.oldSpherical,
            m.oldCylindrical,
            m.oldAxis,
            m.oldGlassesVa,
            m.nearVisionAddition,
          ].any(hasEnteredValue) ||
          m
              .toJson()
              .entries
              .where((entry) => !skipped.contains(entry.key))
              .any((entry) => hasEnteredValue(entry.value)));
}

bool _hasFinalizationContent(Finalization? finalization) =>
    finalization != null &&
    (hasEnteredValue(finalization.diagnosis) ||
        finalization.actions.isNotEmpty ||
        finalization.medicine.isNotEmpty);

/// Whether the examination recorded anything beyond the patient's identity.
bool _hasRecordedAnything(ExaminationModel examinationModel) {
  final examination = examinationModel.examination;
  final complain = examination?.complain;
  final history = examination?.history;
  return _hasFinalizationContent(examinationModel.finalization) ||
      _hasAnyMeasurement(examinationModel) ||
      (complain?.selectedComplaints.isNotEmpty ?? false) ||
      (history?.selectedCategories.isNotEmpty ?? false) ||
      [
        complain?.complainOne,
        complain?.complainTwo,
        complain?.complainThree,
        history?.presentIllness,
        history?.pastHistory,
        history?.medicationHistory,
        history?.familyHistory,
      ].any(hasEnteredValue);
}

class OneExaminationContent extends StatelessWidget {
  final ExaminationModel examination;

  const OneExaminationContent({super.key, required this.examination});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Patient Info and History Section
          Column(
            spacing: 10,
            children: [
              _buildPatientInfoCard(context, examination),
              _buildFinalizationSection(context, examination),
              _buildHistorySection(context, examination),
            ],
          ),

          _buildEyeComparisonSection(context,
              examination: examination, isDark: isDark, theme: theme),

          if (!_hasRecordedAnything(examination))
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No data was recorded for this examination.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationContent(BuildContext context, Action action,
      List<Medicine>? medicines, ExaminationModel examinationModel) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              FormatHelper.capitalizeFirstLetter(action.action ?? ""),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colorz.primaryColor,
              ),
            ),
            IconButton(
                onPressed: () {
                  generateAndPrintPrescription(
                    examination: examinationModel,
                    showPrescriptionTable: false,
                    action: action,
                    prescriptionList:
                        examinationModel.finalization?.medicine ?? [],
                    diagnosis: examinationModel.finalization?.diagnosis,
                  );
                },
                icon: Icon(Icons.print_outlined, color: Colorz.primaryColor)),
          ],
        ),
        const SizedBox(height: 12),

        // Check if medications exist in the action
        if (medicines != null && medicines.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colorz.primaryColor.withValues(alpha: 0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colorz.primaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Dosage',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colorz.primaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Duration',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colorz.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Medications List
                ...medicines.asMap().entries.map((entry) {
                  final index = entry.key;
                  final medication = entry.value;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: index == medicines.length - 1
                              ? Colors.transparent
                              : (isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            FormatHelper.capitalizeFirstLetter(
                                medication.name?.toString() ?? ''),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            FormatHelper.capitalizeFirstLetter(
                                medication.dosage?.toString() ?? ''),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            FormatHelper.capitalizeFirstLetter(
                                medication.duration?.toString() ?? ''),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

        ],
      ],
    );
  }

  Widget _buildGlassesContent(
      BuildContext context, Action action, ExaminationModel examinationModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem(
          context,
          title: FormatHelper.capitalizeFirstLetter(action.action ?? ""),
          // Older records hold "IPD: 63" typed by hand; strip it so the label
          // this view adds is not doubled up.
          content: GlassesPrescription.normalizeIpd(action.data).isEmpty
              ? ''
              : "IPD: ${GlassesPrescription.normalizeIpd(action.data)}",
          onTap: () {
            generateAndPrintPrescription(
              examination: examinationModel,
              showPrescriptionTable: true,
              action: action,
              diagnosis: examinationModel.finalization?.diagnosis,
            );
          },
        ),
      ],
    );
  }

  Widget _buildInvestigationsContent(
      BuildContext context, Action action, ExaminationModel examinationModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              FormatHelper.capitalizeFirstLetter(action.action ?? ""),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colorz.primaryColor,
              ),
            ),
            IconButton(
                onPressed: () {
                  generateAndPrintPrescription(
                    examination: examinationModel,
                    showPrescriptionTable: false,
                    action: action,
                    diagnosis: examinationModel.finalization?.diagnosis,
                  );
                },
                icon: Icon(Icons.print_outlined, color: Colorz.primaryColor)),
          ],
        ),
        const SizedBox(height: 8),
        ...action.metaData.map((investigation) {
          if (investigation == 'corneal') {
            final cornealSubOptions = action.metaData
                .where((item) => ['topography', 'pentacam']
                    .contains(item.toString().toLowerCase()))
                .toList();

            return _buildNestedInvestigation(
              mainTitle: FormatHelper.capitalizeFirstLetter(investigation),
              subOptions: cornealSubOptions,
            );
          } else if (investigation == 'cataract') {
            final hasBiometry = action.metaData.contains('biometry');
            final biometryTypes = action.metaData
                .where((item) => ['ultrasound', 'optical']
                    .contains(item.toString().toLowerCase()))
                .toList();

            return _buildNestedInvestigation(
              mainTitle: FormatHelper.capitalizeFirstLetter(investigation),
              subOptions: hasBiometry ? ['Biometry', ...biometryTypes] : [],
            );
          } else if (![
            'topography',
            'pentacam',
            'biometry',
            'ultrasound',
            'optical'
          ].contains(investigation.toString().toLowerCase())) {
            return _buildInvestigationItem(investigation);
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildLaserContent(
      BuildContext context, Action action, ExaminationModel examinationModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem(
          context,
          title: FormatHelper.capitalizeFirstLetter(action.action ?? ""),
          content: FormatHelper.capitalizeFirstLetter(action.data ?? ''),
          onTap: () {
            generateAndPrintPrescription(
              examination: examinationModel,
              showPrescriptionTable: false,
              action: action,
              diagnosis: examinationModel.finalization?.diagnosis,
            );
          },
        ),
      ],
    );
  }

  Widget _buildKeratoconusContent(
      BuildContext context, Action action, ExaminationModel examinationModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem(context,
            title: FormatHelper.capitalizeFirstLetter(action.action ?? ""),
            content: FormatHelper.capitalizeFirstLetter(action.data ?? ''),
            onTap: () {
          generateAndPrintPrescription(
            examination: examinationModel,
            showPrescriptionTable: false,
            action: action,
            diagnosis: examinationModel.finalization?.diagnosis,
          );
        }),
      ],
    );
  }

  Widget _buildORContent(
      BuildContext context, Action action, ExaminationModel examinationModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem(context,
            title: 'Surgery Type',
            content: FormatHelper.capitalizeFirstLetter(action.data ?? ''),
            onTap: () {
          generateAndPrintPrescription(
            examination: examinationModel,
            showPrescriptionTable: false,
            action: action,
            diagnosis: examinationModel.finalization?.diagnosis,
          );
        }),
        if (action.metaData.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Additional Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colorz.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          if (action.data?.toLowerCase() == 'cataract surgery') ...[
            ...action.metaData.map((detail) => _buildORDetailItem(detail)),
          ] else if (action.data?.toLowerCase() ==
              'intravitreal injection') ...[
            ...action.metaData
                .where((detail) => [
                      'eylea',
                      'lucentis',
                      'avastin',
                      'ziv-aflibercept',
                      'vabysmo',
                      'vsiqqoo',
                      'ozurdex'
                    ].contains(detail.toString().toLowerCase()))
                .map((detail) => _buildORDetailItem(detail)),
          ] else ...[
            ...action.metaData.map((detail) => _buildORDetailItem(detail)),
          ],
        ],
      ],
    );
  }

  Widget _buildAppointmentContent(
      BuildContext context, Action action, ExaminationModel examinationModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem(context,
            title: FormatHelper.capitalizeFirstLetter(action.action ?? ""),
            content: FormatHelper.capitalizeFirstLetter(action.data ?? ''),
            onTap: () {
          generateAndPrintPrescription(
            examination: examinationModel,
            showPrescriptionTable: false,
            action: action,
            diagnosis: examinationModel.finalization?.diagnosis,
          );
        }),
      ],
    );
  }

  Widget _buildDetailItem(BuildContext context,
      {required String title, required String content, Function()? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colorz.primaryColor,
                  ),
                ),
                IconButton(
                    onPressed: onTap,
                    icon:
                        Icon(Icons.print_outlined, color: Colorz.primaryColor)),
              ],
            ),
            if (hasEnteredValue(content)) ...[
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNestedInvestigation({
    required String mainTitle,
    required List<dynamic> subOptions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInvestigationItem(mainTitle),
        if (subOptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subOptions
                  .map((option) => _buildInvestigationItem(option))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildInvestigationItem(dynamic investigation) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colorz.primaryColor),
          const SizedBox(width: 8),
          Text(
            FormatHelper.capitalizeFirstLetter(investigation),
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildORDetailItem(dynamic detail) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Colorz.primaryColor),
          const SizedBox(width: 8),
          Text(
            FormatHelper.capitalizeFirstLetter(detail),
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildQuadrantSection(BuildContext context,
      {required bool isLeft, required ExaminationModel examinationModel}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> _colorList = isDark
        ? [
            Colors.grey[700]!,
            Colors.grey[900]!,
            Colors.white.withValues(alpha: 0.9),
          ]
        : [
            Colors.grey[400]!,
            Colors.black,
            Colors.white,
          ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: Colorz.primaryColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: true,
          enabled: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.all(16),
          title: Text(
            'Confrontation Fields',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colorz.primaryColor,
            ),
          ),
          children: [
            if (examinationModel.examination?.measurements.isNotEmpty ?? false)
              QuadrantContainer(
                containerSize: 280,
                colorList: _colorList,
                tapCounts: isLeft
                    ? [
                        examinationModel.examination?.measurements[0].topLeft ??
                            0,
                        examinationModel
                                .examination?.measurements[0].topRight ??
                            0,
                        examinationModel
                                .examination?.measurements[0].bottomLeft ??
                            0,
                        examinationModel
                                .examination?.measurements[0].bottomRight ??
                            0,
                      ]
                    : [
                        examinationModel.examination?.measurements[1].topLeft ??
                            0,
                        examinationModel
                                .examination?.measurements[1].topRight ??
                            0,
                        examinationModel
                                .examination?.measurements[1].bottomLeft ??
                            0,
                        examinationModel
                                .examination?.measurements[1].bottomRight ??
                            0,
                      ],
                side: isLeft ? 'left' : 'right',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExaminationSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Map<String, dynamic> data,
    required int sectionIndex,
    required bool isLeft,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shadowColor: Colorz.primaryColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: true,
          enabled: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.all(16),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colorz.primaryColor,
            ),
          ),
          children: [
            Column(
              children: data.entries
                  .map((entry) => _buildDataRow(entry.key, entry.value,
                      isDark: isDark, theme: theme))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value,
      {required bool isDark, required ThemeData theme}) {
    final displayValue = value?.toString() ?? 'N/A';
    final isLongText = displayValue.length > 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colorz.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: isLongText ? 13 : 14,
              color: isDark ? Colors.white : Colors.black,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  String? calculateAge(DateTime? birthDate) {
    if (birthDate == null) return "N/A";
    try {
      DateTime currentDate = DateTime.now();
      int age = currentDate.year - birthDate.year;
      if (currentDate.month < birthDate.month ||
          (currentDate.month == birthDate.month &&
              currentDate.day < birthDate.day)) {
        age--;
      }
      return '$age Years';
    } catch (e) {
      return "N/A";
    }
  }

  Widget _buildPatientInfoCard(
      BuildContext context, ExaminationModel examination) {
    return Card(
      elevation: 4,
      shadowColor: Colorz.primaryColor.withValues(alpha: 0.2),
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
                  backgroundColor: Colorz.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person_outline, color: Colorz.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examination.examination?.patient?.name ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colorz.primaryColor,
                        ),
                      ),
                      if (hasEnteredValue(
                          examination.examination?.patient?.nationalId))
                        Text(
                          examination.examination!.patient!.nationalId!
                              .toString(),
                          style: TextStyle(
                            color: Colorz.primaryColor,
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
                if (examination.examination?.patient?.birthDate != null)
                  _buildInfoItem(
                    icon: Icons.calendar_today,
                    label: 'Age',
                    value:
                        '${calculateAge(examination.examination?.patient?.birthDate)}',
                  ),
                if (hasEnteredValue(examination.examination?.patient?.gender))
                  _buildInfoItem(
                    icon: Icons.person,
                    label: 'Gender',
                    value: examination.examination!.patient!.gender!,
                  ),
                // _buildInfoItem(
                //   icon: Icons.phone,
                //   label: 'Contact',
                //   value: examination.examination?.patient?.phone ?? 'N/A',
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalizationSection(
      BuildContext context, ExaminationModel examination) {
    final finalization = examination.finalization;
    if (finalization == null || !_hasFinalizationContent(finalization)) {
      return const SizedBox.shrink();
    }
    return _buildExpandableFinalizationCard(context,
        finalization: finalization, examination: examination);
  }

  Widget _buildExpandableFinalizationCard(BuildContext context,
      {required Finalization finalization,
      required ExaminationModel examination}) {
    return Card(
      elevation: 3,
      shadowColor: Colorz.primaryColor.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colorz.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.medical_services, color: Colorz.primaryColor),
          ),
          title: Text(
            "Finalization",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colorz.primaryColor,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            if (hasEnteredValue(finalization.diagnosis))
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Diagnosis",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colorz.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      finalization.diagnosis ?? 'N/A',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const HeightSpacer(size: 10),
                  ],
                ),
              ),
            ...finalization.actions.map((action) => Column(
                  children: [
                    _buildActionContent(
                        context, action, finalization.medicine, examination),
                    const HeightSpacer(size: 10),
                    Divider(
                      color: Theme.of(context).dividerColor,
                    ),
                    const HeightSpacer(size: 10),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionContent(BuildContext context, Action action,
      List<Medicine>? medicines, ExaminationModel examination) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionSpecificContent(context, action, medicines, examination),
        if (action.eye != null) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              "Eye: ${action.eye?.toUpperCase()}",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildActionSpecificContent(BuildContext context, Action action,
      List<Medicine>? medicines, ExaminationModel examination) {
    switch (action.action?.toLowerCase()) {
      case 'prescribe glasses':
        return _buildGlassesContent(context, action, examination);
      case 'prescribe medications':
        return _buildMedicationContent(context, action, medicines, examination);
      case 'refer to investigations':
        return _buildInvestigationsContent(context, action, examination);
      case 'refer to lasers':
        return _buildLaserContent(context, action, examination);
      case 'keratoconus':
        return _buildKeratoconusContent(context, action, examination);
      case 'refer to or':
        return _buildORContent(context, action, examination);
      case 'book next appointment':
        return _buildAppointmentContent(context, action, examination);
      default:
        return const SizedBox.shrink();
    }
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
            color: Colorz.primaryColor,
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

  Widget _buildHistorySection(
      BuildContext context, ExaminationModel examinationModel) {
    final examination = examinationModel.examination;

    // Structured checklist entries (visible, non-empty fields per selected
    // category) followed by the legacy free-text notes.
    final historyData = <String, String>{};
    final history = examination?.history;
    if (history != null) {
      for (final catKey in history.selectedCategories) {
        for (final e in visibleHistoryEntries(catKey, history.values)) {
          historyData['${historyCategoryLabel(catKey)} — ${e.key}'] = e.value;
        }
      }
    }
    historyData.addAll(Map<String, String>.fromEntries({
      'Family History': examination?.history?.familyHistory,
      'Present Illness': examination?.history?.presentIllness,
      'Past History': examination?.history?.pastHistory,
      'Medication History': examination?.history?.medicationHistory,
    }
        .entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => MapEntry(entry.key, entry.value!))));

    // Structured complaint entries (visible fields per selected option; zero-field
    // options show as "Present") followed by legacy free-text complaints.
    final complaintsData = <String, String>{};
    final complain = examination?.complain;
    if (complain != null) {
      for (final optKey in complain.selectedComplaints) {
        final entries = visibleComplainEntries(optKey, complain.values);
        if (entries.isEmpty) {
          complaintsData[complainOptionLabel(optKey)] = 'Present';
        } else {
          for (final e in entries) {
            complaintsData['${complainOptionLabel(optKey)} — ${e.key}'] = e.value;
          }
        }
      }
    }
    complaintsData.addAll(Map<String, String>.fromEntries({
      'Complain One': examination?.complain?.complainOne,
      'Complain Two': examination?.complain?.complainTwo,
      'Complain Three': examination?.complain?.complainThree,
    }
        .entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => MapEntry(entry.key, entry.value!))));

    return Column(
      children: [
        const HeightSpacer(size: 0),
        if (historyData.isNotEmpty)
          _buildExpandableCard(
            context,
            title: 'Medical History',
            icon: Icons.history,
            content: historyData,
            color: Colorz.primaryColor,
            isHistoryCard: true,
          ),
        if (complaintsData.isNotEmpty)
          _buildExpandableCard(
            context,
            title: 'Chief Complaints',
            icon: Icons.medical_information,
            content: complaintsData,
            color: Colorz.primaryColor,
            isComplaintCard: true,
          ),
      ],
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required Widget leftChild,
    required Widget rightChild,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: rightChild),
          const SizedBox(width: 10),
          Expanded(child: leftChild),
        ],
      ),
    );
  }

  Widget _buildEyeLabel(bool isLeft) {
    return Text(
      isLeft ? '   Left Eye' : '   Right Eye',
      style: TextStyle(
          color: Colorz.primaryColor,
          fontWeight: FontWeight.w500,
          fontSize: 16),
    );
  }

  Widget _buildSectionComparison(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ExaminationModel examination,
    required bool isDark,
    required ThemeData theme,
    required int sectionIndex,
    required Map<String, dynamic> Function(bool isLeft) dataMapper,
  }) {
    // Only fields recorded in at least one eye; the section disappears when none
    // are. The eye without a value shows a dash so the rows stay lined up.
    final rightData = dataMapper(false);
    final leftData = dataMapper(true);
    final keys = rightData.keys
        .where((key) =>
            hasEnteredValue(rightData[key]) || hasEnteredValue(leftData[key]))
        .toList();
    if (keys.isEmpty) return const SizedBox.shrink();

    Map<String, dynamic> visible(Map<String, dynamic> data) => {
          for (final key in keys)
            key: hasEnteredValue(data[key]) ? data[key] : _emptyEyeValue,
        };

    return _buildComparisonRow(
      context,
      rightChild: _buildExaminationSection(
        context,
        title: title,
        icon: icon,
        isLeft: false,
        isDark: isDark,
        theme: theme,
        sectionIndex: sectionIndex,
        data: visible(rightData),
      ),
      leftChild: _buildExaminationSection(
        context,
        title: title,
        icon: icon,
        isLeft: true,
        isDark: isDark,
        theme: theme,
        sectionIndex: sectionIndex,
        data: visible(leftData),
      ),
    );
  }

  Widget _buildEyeComparisonSection(BuildContext context,
      {required ExaminationModel examination,
      required bool isDark,
      required ThemeData theme}) {
    if ((examination.examination?.measurements.isEmpty ?? true) ||
        !_hasAnyMeasurement(examination)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComparisonRow(
            context,
            rightChild: _buildEyeLabel(false),
            leftChild: _buildEyeLabel(true),
          ),
          const HeightSpacer(size: 12),
          if (_hasConfrontationReading(examination))
            _buildComparisonRow(
              context,
              rightChild: _buildQuadrantSection(context,
                  isLeft: false, examinationModel: examination),
              leftChild: _buildQuadrantSection(context,
                  isLeft: true, examinationModel: examination),
            ),
          _buildSectionComparison(
            context,
            title: 'Old Glasses',
            icon: Icons.remove_red_eye,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 0,
            dataMapper: (isLeft) => {
              'Spherical': isLeft
                  ? FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[0].oldSpherical) ??
                      '-'
                  : FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[1].oldSpherical) ??
                      '-',
              'Cylindrical': isLeft
                  ? FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[0].oldCylindrical) ??
                      '-'
                  : FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[1].oldCylindrical) ??
                      '-',
              'Axis': isLeft
                  ? examination.examination?.measurements[0].oldAxis
                  : examination.examination?.measurements[1].oldAxis,
              'VA': isLeft
                  ? examination.examination?.measurements[0].oldGlassesVa
                  : examination.examination?.measurements[1].oldGlassesVa,
            },
          ),
          _buildSectionComparison(
            context,
            title: 'Autorefraction',
            icon: Icons.remove_red_eye,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 0,
            dataMapper: (isLeft) => {
              'Spherical': isLeft
                  ? FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[0].autorefSpherical) ??
                      '-'
                  : FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[1].autorefSpherical) ??
                      '-',
              'Cylindrical': isLeft
                  ? FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[0].autorefCylindrical) ??
                      '-'
                  : FormatHelper.formatPositiveValue(examination
                          .examination?.measurements[1].autorefCylindrical) ??
                      '-',
              'Axis': isLeft
                  ? examination.examination?.measurements[0].autorefAxis
                  : examination.examination?.measurements[1].autorefAxis,
            },
          ),
          // Absent from almost every visit, so the block is skipped rather than
          // shown as a row of dashes.
          if (_hasCycloplegicReading(examination))
            _buildSectionComparison(
              context,
              title: 'Cycloplegic Refraction',
              icon: Icons.remove_red_eye_outlined,
              examination: examination,
              isDark: isDark,
              theme: theme,
              sectionIndex: 2,
              dataMapper: (isLeft) => {
                'Spherical': FormatHelper.formatPositiveValue(
                    examination.examination?.measurements[isLeft ? 0 : 1]
                        .cycloplegicSpherical),
                'Cylindrical': FormatHelper.formatPositiveValue(
                    examination.examination?.measurements[isLeft ? 0 : 1]
                        .cycloplegicCylindrical),
                'Axis': examination
                    .examination?.measurements[isLeft ? 0 : 1].cycloplegicAxis,
              },
            ),
          _buildSectionComparison(
            context,
            title: 'Refined Refraction',
            icon: Icons.science,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 2,
            dataMapper: (isLeft) => {
              'Spherical': isLeft
                  ? FormatHelper.formatPositiveValue(examination
                      .examination?.measurements[0].refinedRefractionSpherical)
                  : FormatHelper.formatPositiveValue(examination
                      .examination?.measurements[1].refinedRefractionSpherical),
              'Cylindrical': isLeft
                  ? FormatHelper.formatPositiveValue(examination.examination
                      ?.measurements[0].refinedRefractionCylindrical)
                  : FormatHelper.formatPositiveValue(examination.examination
                      ?.measurements[1].refinedRefractionCylindrical),
              'Axis': isLeft
                  ? examination
                      .examination?.measurements[0].refinedRefractionAxis
                  : examination
                      .examination?.measurements[1].refinedRefractionAxis,
              'Near Vision': isLeft
                  ? FormatHelper.formatPositiveValue(examination
                      .examination?.measurements[0].nearVisionAddition)
                  : FormatHelper.formatPositiveValue(examination
                      .examination?.measurements[1].nearVisionAddition),
            },
          ),
          _buildSectionComparison(
            context,
            title: 'Visual Acuity',
            icon: Icons.visibility,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 1,
            dataMapper: (isLeft) => {
              'UCVA': isLeft
                  ? examination.examination?.measurements[0].ucva
                  : examination.examination?.measurements[1].ucva,
              'BCVA': isLeft
                  ? examination.examination?.measurements[0].bcva
                  : examination.examination?.measurements[1].bcva,
            },
          ),
          _buildSectionComparison(
            context,
            title: 'IOP',
            icon: Icons.opacity,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 3,
            dataMapper: (isLeft) => {
              'IOP Value': isLeft
                  ? examination.examination?.measurements[0].iop
                  : examination.examination?.measurements[1].iop,
              'Measurement Method': isLeft
                  ? examination.examination?.measurements[0].meansOfMeasurement
                  : examination.examination?.measurements[1].meansOfMeasurement,
              'Acquire Another IOP Measurement': isLeft
                  ? examination
                      .examination?.measurements[0].acquireAnotherIopMeasurement
                  : examination.examination?.measurements[1]
                      .acquireAnotherIopMeasurement,
            },
          ),
          _buildSectionComparison(
            context,
            title: 'Pupils',
            icon: Icons.lens_blur,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 4,
            dataMapper: (isLeft) => {
              'Shape': isLeft
                  ? examination.examination?.measurements[0].pupilsShape
                  : examination.examination?.measurements[1].pupilsShape,
              'Light Reflex': isLeft
                  ? examination
                      .examination?.measurements[0].pupilsLightReflexTest
                  : examination
                      .examination?.measurements[1].pupilsLightReflexTest,
              'Near Reflex': isLeft
                  ? examination
                      .examination?.measurements[0].pupilsNearReflexTest
                  : examination
                      .examination?.measurements[1].pupilsNearReflexTest,
              'Swinging Flashlight': isLeft
                  ? examination
                      .examination?.measurements[0].pupilsSwingingFlashLightTest
                  : examination.examination?.measurements[1]
                      .pupilsSwingingFlashLightTest,
              'Other Disorders': isLeft
                  ? examination
                      .examination?.measurements[0].pupilsOtherDisorders
                  : examination
                      .examination?.measurements[1].pupilsOtherDisorders,
            },
          ),
          _buildSectionComparison(
            context,
            title: 'Eyelid & Physical',
            icon: Icons.visibility_outlined,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 5,
            dataMapper: (isLeft) => {
              'Eyelid Ptosis': isLeft
                  ? examination.examination?.measurements[0].eyelidPtosis
                  : examination.examination?.measurements[1].eyelidPtosis,
              'Lagophthalmos': isLeft
                  ? examination.examination?.measurements[0].eyelidLagophthalmos
                  : examination
                      .examination?.measurements[1].eyelidLagophthalmos,
              'Palpable Lymph Nodes': isLeft
                  ? examination.examination?.measurements[0].palpableLymphNodes
                  : examination.examination?.measurements[1].palpableLymphNodes,
              'Papable Temporal Artery': isLeft
                  ? examination
                      .examination?.measurements[0].palpableTemporalArtery
                  : examination
                      .examination?.measurements[1].palpableTemporalArtery,
              'Exophthalmometry': isLeft
                  ? examination.examination?.measurements[0].exophthalmometry
                  : examination.examination?.measurements[1].exophthalmometry,
            },
          ),
          _buildSectionComparison(
            context,
            title: 'Eye Structure',
            icon: Icons.add_circle_outline,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 7,
            dataMapper: (isLeft) => {
              'Corneal Findings': (isLeft
                      ? examination.examination?.measurements[0].cornea
                      : examination.examination?.measurements[1].cornea)
                  .join(', '),
              'Anterior Chamber': (isLeft
                      ? examination.examination?.measurements[0].anteriorChamber
                      : examination
                          .examination?.measurements[1].anteriorChamber)
                  .join(', '),
              'Iris Findings': (isLeft
                      ? examination.examination?.measurements[0].iris
                      : examination.examination?.measurements[1].iris)
                  .join(', '),
              'Lens Status': (isLeft
                      ? examination.examination?.measurements[0].lens
                      : examination.examination?.measurements[1].lens)
                  .join(', '),
              'Vitreous Status': (isLeft
                      ? examination
                          .examination?.measurements[0].anteriorVitreous
                      : examination
                          .examination?.measurements[1].anteriorVitreous)
                  .join(', '),
              if (((isLeft
                          ? examination
                              .examination?.measurements[0].vitreousHemorrhageGrade
                          : examination.examination?.measurements[1]
                              .vitreousHemorrhageGrade) ??
                      '')
                  .toString()
                  .isNotEmpty)
                'VH Grade': (isLeft
                    ? examination
                        .examination?.measurements[0].vitreousHemorrhageGrade
                    : examination
                        .examination?.measurements[1].vitreousHemorrhageGrade)!,
            },
          ),
          _buildSectionComparison(
            context,
            title: 'Fundus Examination',
            icon: Icons.center_focus_strong,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 8,
            dataMapper: (isLeft) => {
              'Disc Appearance': (isLeft
                      ? examination.examination?.measurements[0].fundusOpticDisc
                      : examination
                          .examination?.measurements[1].fundusOpticDisc)
                  .join(', '),
              if (((isLeft
                          ? examination.examination?.measurements[0].cupDiscRatio
                          : examination
                              .examination?.measurements[1].cupDiscRatio) ??
                      '')
                  .toString()
                  .isNotEmpty)
                'Cup Disc Ratio': (isLeft
                        ? examination.examination?.measurements[0].cupDiscRatio
                        : examination.examination?.measurements[1].cupDiscRatio)
                    .toString(),
              'Macular Findings': (isLeft
                      ? examination.examination?.measurements[0].fundusMacula
                      : examination.examination?.measurements[1].fundusMacula)
                  .join(', '),
              'Vessels': (isLeft
                      ? examination.examination?.measurements[0].fundusVessels
                      : examination.examination?.measurements[1].fundusVessels)
                  .join(', '),
              'Retina': (isLeft
                      ? examination.examination?.measurements[0].fundusPeriphery
                      : examination
                          .examination?.measurements[1].fundusPeriphery)
                  .join(', '),
            },
          ),
          _buildSectionComparison(
            context,
            title: 'External Features',
            icon: Icons.biotech,
            examination: examination,
            isDark: isDark,
            theme: theme,
            sectionIndex: 6,
            dataMapper: (isLeft) => {
              'Lids': isLeft
                  ? examination.examination?.measurements[0].lids
                  : examination.examination?.measurements[1].lids,
              'Lashes': isLeft
                  ? examination.examination?.measurements[0].lashes
                  : examination.examination?.measurements[1].lashes,
              'Lacrimal': isLeft
                  ? examination.examination?.measurements[0].lacrimalSystem
                  : examination.examination?.measurements[1].lacrimalSystem,
              'Conjunctiva': isLeft
                  ? examination.examination?.measurements[0].conjunctiva
                  : examination.examination?.measurements[1].conjunctiva,
              'Sclera': isLeft
                  ? examination.examination?.measurements[0].sclera
                  : examination.examination?.measurements[1].sclera,
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildExpandableCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Map<String, String> content,
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
              color: Colorz.primaryColor,
            ),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
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
                          color: Colorz.primaryColor,
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
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
