import 'dart:developer';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_intl_phone_field/flutter_intl_phone_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:ocurithm/core/utils/auth_service.dart';
import 'package:ocurithm/core/utils/capability_keys.dart';
import 'package:ocurithm/core/utils/constant.dart';
import 'package:ocurithm/core/utils/egypt_locations.dart';
import 'package:ocurithm/core/utils/services_locator.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';
import 'package:ocurithm/core/widgets/DropdownPackage.dart';
import 'package:ocurithm/core/widgets/custom_freeze_loading.dart';
import 'package:ocurithm/core/widgets/height_spacer.dart';
import 'package:ocurithm/core/widgets/manage_capabilities.dart';
import 'package:ocurithm/generated/l10n.dart';
import 'package:ocurithm/modules/Branch/data/model/branches_model.dart';
import 'package:ocurithm/modules/Branch/presentation/manager/get_branches_cubit/get_branches_cubit.dart';
import 'package:ocurithm/modules/Clinics/data/model/clinics_model.dart';
import 'package:ocurithm/modules/Clinics/presentation/manager/get_clinics_cubit/get_clinics_cubit.dart';
import 'package:ocurithm/modules/Patient/data/model/nationality_model.dart';
import 'package:ocurithm/modules/Patient/data/model/patient_examination.dart';
import 'package:ocurithm/modules/Patient/data/model/patients_model.dart';
import 'package:ocurithm/modules/Patient/presentation/manager/get_patient_examinations_cubit/get_patient_examinations_cubit.dart';
import 'package:ocurithm/modules/Patient/presentation/manager/get_single_patient_cubit/get_single_patient_cubit.dart';
import 'package:ocurithm/modules/Patient/presentation/manager/patient_actions_cubit/patient_actions_cubit.dart';
import 'package:ocurithm/modules/Patient/presentation/views/widgets/transfer_patient_bottom_sheet.dart';
import 'package:ocurithm/modules/Patient/presentation/views/patient_form/address_picker_fields.dart';
import 'package:password_generator/password_generator.dart';

import '../../../../../core/widgets/no_internet.dart';
import '../../../../Analysis/presentation/views/analysis_view.dart';
import '../../../../Make_Appointment/presentation/views/make_appointment_view.dart';
import '../examination_view/one_examination_view.dart';
import '../examination_view/scan_form_page.dart';
import '../examination_view/scanned_list_page.dart';

enum PatientFormMode { add, edit, view }

class PatientFormPage extends StatelessWidget {
  final PatientFormMode mode;
  final String? patientId;

  const PatientFormPage({
    super.key,
    required this.mode,
    this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<PatientActionsCubit>()),
        if (mode != PatientFormMode.add) ...[
          BlocProvider(
            create: (_) => sl<GetSinglePatientCubit>()
              ..add(GetPatientByIdEvent(patientId!)),
          ),
          BlocProvider(
            create: (_) =>
                sl<GetPatientExaminationsCubit>()..getExaminations(patientId!),
          ),
        ],
        if (AuthService.showClinicSelection)
          BlocProvider(
              create: (_) => sl<GetClinicsCubit>()
                ..add(GetAllClinicsEvent(noPagination: true))),
        BlocProvider(
          create: (_) => sl<GetBranchesCubit>()
            ..add(SetClinicFilterEvent(AuthService.getEffectiveClinic()?.id)),
        ),
      ],
      child: PatientFormView(mode: mode, patientId: patientId),
    );
  }
}

class PatientFormView extends StatefulWidget {
  final PatientFormMode mode;
  final String? patientId;

  const PatientFormView({super.key, required this.mode, this.patientId});

  @override
  State<PatientFormView> createState() => _PatientFormViewState();
}

class _PatientFormViewState extends State<PatientFormView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _addressController;
  late TextEditingController _nationalIdController;

  String? _phoneNumber;

  // Registration's structured address; joined with the details text
  // (_addressController) into the single `address` the API stores.
  String _governorate = EgyptLocations.defaultGovernorate;
  String? _area;

  bool get _isAddMode => widget.mode == PatientFormMode.add;

  String get _composedAddress => EgyptLocations.compose(
        governorate: _governorate,
        area: _area,
        details: _addressController.text,
      );
  DateTime? _birthDate;
  String? _selectedGender;
  Nationality? _selectedNationality;

  Clinic? selectedClinic;
  Branch? _selectedBranch;

  bool _obscurePassword = true;
  late bool _isReadOnlyState;
  Patient? _loadedPatient;

  final _passwordGenerator = PasswordGenerator(
    length: 8,
    hasCapitalLetters: true,
    hasNumbers: true,
    hasSmallLetters: true,
    hasSymbols: true,
  );

  bool _isBirthDateValid = true;
  bool _isGenderValid = true;
  bool _isClinicValid = true;
  bool _isBranchValid = true;
  bool _isNationalityValid = true;

  @override
  void initState() {
    super.initState();
    _isReadOnlyState = widget.mode == PatientFormMode.view;
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _addressController = TextEditingController();
    _nationalIdController = TextEditingController();

    if (!AuthService.isAdmin) {
      selectedClinic = AuthService.userClinic;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  void _showPostAddDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline,
                      color: theme.primaryColor, size: 50),
                ),
                const SizedBox(height: 24),
                Text(
                  "Patient Added!",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Successfully added ${patient.name}. Would you like to schedule an appointment for them now?",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(this.context, true);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: theme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text("Later",
                            style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(this.context, true);
                          Get.to(() => MakeAppointmentView(patient: patient));
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Appointment",
                            style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _populateForm(Patient patient) {
    _loadedPatient = patient;
    _nameController.text = patient.name ?? '';
    _emailController.text = patient.email ?? '';
    _addressController.text = patient.address ?? '';
    _nationalIdController.text = patient.nationalId ?? '';
    _phoneNumber = patient.phone;
    _birthDate = patient.birthDate;
    _selectedGender = patient.gender;

    if (patient.nationality != null) {
      try {
        _selectedNationality = nationalities.firstWhere((n) =>
            n.value.toLowerCase() == patient.nationality?.toLowerCase() ||
            n.name == patient.nationality);
      } catch (e) {
        // ignore
      }
    }

    if (patient.clinic != null) {
      selectedClinic = patient.clinic!;
      if (context.mounted) {
        context
            .read<GetBranchesCubit>()
            .add(SetClinicFilterEvent(selectedClinic?.id));
      }
    }

    _selectedBranch = patient.branch;

    if (!AuthService.isAdmin) {
      selectedClinic = AuthService.userClinic;
    } else {
      selectedClinic = patient.clinic;
    }

    setState(() {});
  }

  String get _pageTitle {
    switch (widget.mode) {
      case PatientFormMode.add:
        return 'Add Patient';
      case PatientFormMode.edit:
        return 'Edit Patient';
      case PatientFormMode.view:
        return 'Patient Details';
    }
  }

  bool get _isReadOnly => _isReadOnlyState;

  String _getNationalityDisplayName(String? nationalityValue) {
    if (nationalityValue == null || nationalityValue.isEmpty) return 'N/A';
    try {
      final nationality = nationalities.firstWhere((n) =>
          n.value.toLowerCase() == nationalityValue.toLowerCase() ||
          n.name == nationalityValue);
      return nationality.name;
    } catch (_) {
      return nationalityValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Widget bodyContent = AuthService.showClinicSelection
        ? BlocBuilder<GetClinicsCubit, GetClinicsState>(
            builder: (context, clinicsState) {
              if (clinicsState.noConnection) {
                return NoInternet(
                  fromTop: 0,
                  onPressed: () => context
                      .read<GetClinicsCubit>()
                      .add(GetAllClinicsEvent(noPagination: true)),
                );
              }
              if (clinicsState.isError) {
                return Center(child: Text(clinicsState.errorMessage ?? ''));
              }
              return _buildMainContent(context, theme, isDark);
            },
          )
        : _buildMainContent(context, theme, isDark);

    return GestureDetector(
      onTap: () => WidgetsBinding.instance.focusManager.primaryFocus!.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
          elevation: 0,
          actions: [
            if (widget.mode != PatientFormMode.add)
              manageCapability(
                capability: CapabilityKeys.managePatients,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isReadOnlyState = !_isReadOnlyState;
                      if (_isReadOnlyState && _loadedPatient != null) {
                        _populateForm(_loadedPatient!);
                      }
                    });
                  },
                  icon: Icon(_isReadOnly ? Icons.edit : Icons.close),
                ),
              ),
            if (widget.mode != PatientFormMode.add && widget.patientId != null)
              IconButton(
                onPressed: () {
                  Get.to(() =>
                      AnalysisView(patientId: widget.patientId.toString()));
                },
                icon: const Icon(Icons.analytics_outlined),
              ),
            // Matches web's canTransferPatient gate (manageCapability ||
            // managePatients) — CapabilityServices already ORs manageCapability.
            if (widget.mode != PatientFormMode.add && widget.patientId != null)
              manageCapability(
                capability: CapabilityKeys.managePatients,
                child: IconButton(
                  onPressed: () => _handleTransfer(context),
                  icon: const Icon(Icons.swap_horiz),
                ),
              ),
          ],
        ),
        body: MultiBlocListener(
          listeners: [
            if (widget.mode != PatientFormMode.add)
              BlocListener<GetSinglePatientCubit, GetSinglePatientState>(
                listener: (context, state) {
                  if (state.isSuccess && state.patient != null) {
                    _populateForm(state.patient!);
                  }
                },
              ),
            BlocListener<PatientActionsCubit, PatientActionsState>(
              listener: (context, state) {
                if (state.isLoading) {
                  customLoading(
                      context,
                      (state.actionType == PatientActionType.add)
                          ? "Adding Patient..."
                          : "Updating Patient...");
                } else if (state.isSuccess) {
                  // Pop the loading dialog
                  Navigator.pop(context);

                  SnackbarService.showSuccess(
                    context,
                    message: state.successMessage ?? 'Success',
                  );
                  if (state.actionType == PatientActionType.add &&
                      state.patient != null) {
                    _showPostAddDialog(context, state.patient!);
                  } else if (state.actionType == PatientActionType.update &&
                      state.patient != null) {
                    _populateForm(state.patient!);
                    setState(() {
                      _isReadOnlyState = true;
                    });
                  } else {
                    Navigator.pop(context, true);
                  }
                } else if (state.isError || state.noConnection) {
                  // Pop the loading dialog
                  Navigator.pop(context);

                  SnackbarService.showError(
                    context,
                    message: state.errorMessage ?? 'Error',
                  );
                }
              },
            )
          ],
          child: bodyContent,
        ),
        bottomNavigationBar:
            (!_isReadOnly || widget.mode == PatientFormMode.add)
                ? _buildBottomBar(context, theme)
                : null,
      ),
    );
  }

  Widget _buildPatientDetailView(ThemeData theme, bool isDark) {
    if (_loadedPatient == null) return const SizedBox.shrink();
    final p = _loadedPatient!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildDetailHeader(p, theme, isDark),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(
                  title: 'Personal Information',
                  items: [
                    _InfoItemData(
                        label: 'Gender',
                        value: p.gender ?? 'N/A',
                        icon: Icons.person_outline),
                    _InfoItemData(
                        label: 'Birth Date',
                        value: p.birthDate != null
                            ? DateFormat('MMM dd, yyyy').format(p.birthDate!)
                            : 'N/A',
                        icon: Icons.cake_outlined),
                    _InfoItemData(
                        label: 'Nationality',
                        value: _getNationalityDisplayName(p.nationality),
                        icon: Icons.flag_outlined),
                  ],
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildInfoSection(
                  title: 'Contact & ID',
                  items: [
                    _InfoItemData(
                        label: 'Email',
                        value: p.email ?? 'N/A',
                        icon: Icons.email_outlined),
                    _InfoItemData(
                        label: 'Phone',
                        value: p.phone ?? 'N/A',
                        icon: Icons.phone_outlined),
                    _InfoItemData(
                        label: 'National ID',
                        value: p.nationalId ?? 'N/A',
                        icon: Icons.badge_outlined),
                    _InfoItemData(
                        label: 'Serial Number',
                        value: p.serialNumber ?? 'N/A',
                        icon: Icons.numbers_outlined),
                  ],
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildInfoSection(
                  title: 'Location & Affiliation',
                  items: [
                    _InfoItemData(
                        label: 'Address',
                        value: p.address ?? 'N/A',
                        icon: Icons.location_on_outlined),
                    _InfoItemData(
                        label: 'Clinic',
                        value: p.clinic?.name ?? 'N/A',
                        icon: Icons.local_hospital_outlined),
                    _InfoItemData(
                        label: 'Branch',
                        value: p.branch?.name ?? 'N/A',
                        icon: Icons.business_outlined),
                  ],
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Get.to(() => ScanFormPage(patientId: p.id ?? '')),
                        icon: const Icon(Icons.qr_code_scanner, size: 20),
                        label: const Text("Scan"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(() => ScannedListPage(
                            patientId: p.id ?? '', patientName: p.name)),
                        icon: const Icon(Icons.image_outlined, size: 20),
                        label: const Text("Show Scanned"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildExaminationsList(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(Patient p, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [theme.primaryColor.withValues(alpha: 0.2), theme.cardColor]
              : [
                  theme.primaryColor.withValues(alpha: 0.1),
                  theme.primaryColor.withValues(alpha: 0.02)
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                p.name?.isNotEmpty == true ? p.name![0].toUpperCase() : 'P',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p.name ?? 'Unknown Patient',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (p.serialNumber != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'SN: ${p.serialNumber}',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<_InfoItemData> items,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildInfoRow(item, theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(_InfoItemData item, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: theme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (AuthService.showClinicSelection &&
                widget.mode == PatientFormMode.add)
              _buildClinicDropdown(theme),
            _buildBranchDropdown(theme),
            const HeightSpacer(size: 20),
            _buildLabel(S.of(context).fullName, theme),
            _buildCustomTextField(
              controller: _nameController,
              hintText: S.of(context).fullName,
              icon: 'assets/icons/profile.svg',
              showBorder: true,
              validator: (v) => v!.isEmpty ? S.of(context).mustUsername : null,
              onChanged: (value) {
                if (!_isReadOnly && value.isNotEmpty) {
                  context.read<PatientActionsCubit>().add(
                        CheckDuplicateNameEvent(value),
                      );
                }
              },
            ),
            BlocBuilder<PatientActionsCubit, PatientActionsState>(
              builder: (context, state) {
                if (state.isCheckingDuplicateName) {
                  return const Padding(
                    padding: EdgeInsets.only(left: 10, top: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Checking name...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                if (state.isNameDuplicate == true) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'This patient name already exists',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const HeightSpacer(size: 20),
            _buildLabel(S.of(context).emailAddress, theme),
            _buildCustomTextField(
                controller: _emailController,
                hintText: S.of(context).emailAddress,
                icon: 'assets/icons/email.svg',
                keyboardType: TextInputType.emailAddress,
                showBorder: true,
                required: false,
                validator: (v) {
                  if (v!.isNotEmpty &&
                      !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return S.of(context).invalidEmail;
                  }
                  return null;
                }),
            const HeightSpacer(size: 20),
            _buildLabel(S.of(context).phone, theme),
            _buildPhoneField(theme),
            const HeightSpacer(size: 20),
            if (widget.mode == PatientFormMode.add) ...[
              _buildLabel(S.of(context).password, theme),
              _buildPasswordField(theme, isDark),
              const HeightSpacer(size: 20),
            ] else if (_loadedPatient?.serialNumber != null) ...[
              _buildSerialNumber(theme),
              const HeightSpacer(size: 20),
            ],
            _buildLabel(S.of(context).address, theme),
            if (_isAddMode) ...[
              // Registration picks governorate and area; editing keeps the one
              // free-text address the API stores.
              PatientAddressPicker(
                governorate: _governorate,
                area: _area,
                onGovernorateChanged: (value) => setState(() {
                  _governorate = value;
                  // Areas belong to Alexandria.
                  _area = null;
                }),
                onAreaChanged: (value) => setState(() => _area = value),
              ),
              const HeightSpacer(size: 12),
            ],
            _buildCustomTextField(
              controller: _addressController,
              hintText:
                  _isAddMode ? 'Street, building, floor' : S.of(context).address,
              icon: 'assets/icons/home.svg',
              showBorder: true,
              // Always bordered as per request
              required: false,
              validator: (v) => null,
              onChanged: _isAddMode ? (_) => setState(() {}) : null,
            ),
            if (_isAddMode && _composedAddress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Saved as: $_composedAddress',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
            ],
            const HeightSpacer(size: 20),
            _buildLabel(S.of(context).nationalId, theme),
            _buildCustomTextField(
              controller: _nationalIdController,
              hintText: S.of(context).nationalId,
              icon: 'assets/icons/national_id.svg',
              keyboardType: TextInputType.number,
              showBorder: true,
              // Always bordered
              validator: (v) => v!.isEmpty ? S.of(context).mustNotEmpty : null,
            ),
            const HeightSpacer(size: 20),
            _buildLabel("Nationality", theme),
            _buildNationalityDropdown(theme),
            const HeightSpacer(size: 20),
            _buildBirthDatePicker(context, theme, isDark),
            const HeightSpacer(size: 20),
            _buildLabel(S.of(context).gender, theme),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text(S.of(context).male),
                    value: 'Male',
                    groupValue: _selectedGender,
                    onChanged: _isReadOnly
                        ? null
                        : (v) => setState(() => _selectedGender = v),
                    activeColor: theme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text(S.of(context).female),
                    value: 'Female',
                    groupValue: _selectedGender,
                    onChanged: _isReadOnly
                        ? null
                        : (v) => setState(() => _selectedGender = v),
                    activeColor: theme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (!_isGenderValid)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(S.of(context).mustNotEmpty,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            if (widget.mode != PatientFormMode.add) ...[
              const HeightSpacer(size: 20),
              Divider(color: theme.dividerColor),
              const HeightSpacer(size: 20),
              _buildExaminationsList(theme),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSerialNumber(ThemeData theme) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: theme.cardColor,
          border: Border.all(color: theme.primaryColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_loadedPatient?.serialNumber ?? "N/A",
                style: theme.textTheme.bodyLarge),
            SvgPicture.asset("assets/icons/password.svg"),
          ],
        ));
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required String icon,
    bool required = true,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    bool showBorder = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    final borderColor = showBorder ? theme.primaryColor : Colors.transparent;

    return TextFormField(
      controller: controller,
      readOnly: _isReadOnly,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: theme.cardColor,
        contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red)),
        suffixIcon: suffixIcon ??
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: SvgPicture.asset(icon, height: 20, width: 20)),
      ),
    );
  }

  Widget _buildExaminationsList(ThemeData theme) {
    return BlocBuilder<GetPatientExaminationsCubit,
        GetPatientExaminationsState>(builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.examinations == null ||
          (state.examinations?.examinations.isEmpty ?? true)) {
        return const SizedBox.shrink();
      }
      final list = state.examinations!.examinations;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text("Examinations",
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: theme.primaryColor, shape: BoxShape.circle),
            child: Text('${list.length}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]),
        const SizedBox(height: 10),
        ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final exam = list[index];
              return _buildExaminationCard(exam, theme);
            })
      ]);
    });
  }

  Widget _buildExaminationCard(Examination exam, ThemeData theme) {
    return Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: InkWell(
            onTap: () async {
              if (exam.id != null) {
                final deleted = await Get.to<bool>(
                    () => OneExaminationView(id: exam.id!));
                if (deleted == true &&
                    mounted &&
                    widget.patientId != null) {
                  context
                      .read<GetPatientExaminationsCubit>()
                      .getExaminations(widget.patientId!);
                }
              }
            },
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.visibility_outlined,
                        color: theme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exam.type?.name ?? 'N/A',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_formatDateTime(exam.createdAt?.toString()),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ]))));
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (_) {
      return dateTimeStr;
    }
  }

  Widget _buildPhoneField(ThemeData theme) {
    return IntlPhoneField(
      key: ValueKey(_phoneNumber),
      // Force rebuild when phone number changes
      initialValue: _phoneNumber ?? '',
      decoration: InputDecoration(
        hintText: S.of(context).phone,
        fillColor: theme.cardColor,
        filled: true,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 15.w),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.red)),
        suffixIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SvgPicture.asset("assets/icons/phone_number.svg",
              height: 15, width: 15),
        ),
      ),
      // A stored international number ("+963…") carries its own country; passing
      // 'EG' would make the field keep Egypt and show "+963…" as the local part.
      initialCountryCode:
          (_phoneNumber ?? '').trim().startsWith('+') ? null : 'EG',
      dropdownIconPosition: IconPosition.leading,
      languageCode: "en",
      enabled: !_isReadOnly,
      onChanged: (phone) {
        _phoneNumber = phone.completeNumber;
      },
    );
  }

  Widget _buildPasswordField(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _buildCustomTextField(
            controller: _passwordController,
            hintText: S.of(context).password,
            icon: 'assets/icons/password.svg',
            obscureText: _obscurePassword,
            showBorder: true,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility),
              color: theme.primaryColor,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return S.of(context).mustPassword;
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
        ),
        if (!_isReadOnly) ...[
          SizedBox(width: 8.w),
          Expanded(
            flex: 1,
            child: _buildPasswordGeneratorButton(theme, isDark),
          ),
        ]
      ],
    );
  }

  Widget _buildPasswordGeneratorButton(ThemeData theme, bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: theme.cardColor),
        child: IconButton(
          onPressed: () {
            final generated = _passwordGenerator.generatePassword();
            if (generated.checkStrength() >= 28) {
              setState(() => _passwordController.text = generated);
            }
          },
          icon: SvgPicture.asset('assets/icons/password.svg'),
        ),
      ),
    );
  }

  Widget _buildClinicDropdown(ThemeData theme) {
    return BlocBuilder<GetClinicsCubit, GetClinicsState>(
        builder: (context, state) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Clinic", theme),
          DropdownItem(
            radius: 30,
            color: theme.cardColor,
            isShadow: false,
            border: theme.primaryColor,
            iconData:
                Icon(Icons.arrow_drop_down_circle, color: theme.primaryColor),
            items: state.clinics?.clinics ?? [],
            isValid: _isClinicValid,
            validateText: 'Must select Clinic',
            selectedValue: selectedClinic?.name,
            hintText: 'Select Clinic',
            itemAsString: (item) => item.name.toString(),
            onItemSelected: (item) {
              setState(() {
                selectedClinic = item;
                _selectedBranch = null;
              });
              context
                  .read<GetBranchesCubit>()
                  .add(SetClinicFilterEvent(selectedClinic?.id));
            },
            readOnly: _isReadOnly,
            isLoading: state.isLoading,
          ),
          const HeightSpacer(size: 20),
        ],
      );
    });
  }

  Widget _buildBranchDropdown(ThemeData theme) {
    return BlocBuilder<GetBranchesCubit, GetBranchesState>(
        builder: (context, state) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Branch", theme),
          DropdownItem(
            radius: 30,
            color: theme.cardColor,
            isShadow: false,
            border: theme.primaryColor,
            iconData:
                Icon(Icons.arrow_drop_down_circle, color: theme.primaryColor),
            items: state.branches?.branches ?? [],
            isValid: _isBranchValid,
            validateText: S.of(context).mustBranch,
            selectedValue: _selectedBranch?.name,
            hintText: 'Select Branch',
            itemAsString: (item) => item.name.toString(),
            onItemSelected: (item) => setState(() => _selectedBranch = item),
            readOnly: _isReadOnly,
            isLoading: state.isLoading,
          ),
        ],
      );
    });
  }

  Widget _buildNationalityDropdown(ThemeData theme) {
    return DropdownItem<Nationality>(
      radius: 30,
      color: theme.cardColor,
      isShadow: false,
      border: theme.primaryColor,
      iconData: Icon(Icons.arrow_drop_down_circle, color: theme.primaryColor),
      items: nationalities,
      isValid: _isNationalityValid,
      validateText: 'Nationality must not be Empty',
      selectedValue: _selectedNationality?.name,
      hintText: 'Select Nationality',
      itemAsString: (item) => item.name,
      onItemSelected: (item) {
        setState(() => _selectedNationality = item);
      },
      readOnly: _isReadOnly,
      isLoading: false,
    );
  }

  Widget _buildBirthDatePicker(
      BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(S.of(context).dateOfBirth, theme),
        InkWell(
          onTap: _isReadOnly
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: theme.copyWith(
                        colorScheme: isDark
                            ? ColorScheme.dark(
                                primary: theme.primaryColor,
                                onPrimary: Colors.white,
                                surface: theme.cardColor,
                                onSurface: Colors.white,
                              )
                            : ColorScheme.light(
                                primary: theme.primaryColor,
                                onPrimary: Colors.white,
                                surface: theme.cardColor,
                                onSurface: Colors.black87,
                              ),
                        dialogBackgroundColor: theme.cardColor,
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) {
                    setState(() {
                      _birthDate = date;
                      _isBirthDateValid = true;
                    });
                  }
                },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: _isBirthDateValid ? theme.primaryColor : Colors.red),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Center(
                        child: Text(
                            _birthDate != null
                                ? '${_birthDate!.day}'
                                : S.of(context).dd,
                            style: theme.textTheme.titleMedium))),
                Container(
                    width: 2,
                    height: 30,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(30))),
                Expanded(
                    child: Center(
                        child: Text(
                            _birthDate != null
                                ? '${_birthDate!.month}'
                                : S.of(context).mm,
                            style: theme.textTheme.titleMedium))),
                Container(
                    width: 2,
                    height: 30,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(30))),
                Expanded(
                    child: Center(
                        child: Text(
                            _birthDate != null
                                ? '${_birthDate!.year}'
                                : S.of(context).yy,
                            style: theme.textTheme.titleMedium))),
              ],
            ),
          ),
        ),
        if (!_isBirthDateValid)
          Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(S.of(context).mustBirth,
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: EdgeInsets.symmetric(vertical: 16.h),
          ),
          child: Text(
            widget.mode == PatientFormMode.add
                ? S.of(context).add
                : S.of(context).confirm,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    // Validate
    if (!_formKey.currentState!.validate()) return;

    // Manual Validation
    setState(() {
      _isClinicValid =
          selectedClinic != null || !AuthService.showClinicSelection;
      _isBranchValid = _selectedBranch != null;
      _isNationalityValid = _selectedNationality != null;
      _isBirthDateValid = _birthDate != null;
      _isGenderValid = _selectedGender != null;
    });

    if (!_isClinicValid ||
        !_isBranchValid ||
        !_isNationalityValid ||
        !_isBirthDateValid ||
        !_isGenderValid) {
      return;
    }

    final patient = Patient(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneNumber,
      password: _passwordController.text,
      address: _isAddMode ? _composedAddress : _addressController.text,
      nationalId: _nationalIdController.text,
      nationality: _selectedNationality?.value,
      birthDate: _birthDate,
      gender: _selectedGender,
      clinic: widget.mode == PatientFormMode.add ? selectedClinic : null,
      branch: _selectedBranch,
    );

    if (widget.mode == PatientFormMode.add) {
      context.read<PatientActionsCubit>().add(AddPatientEvent(patient));
    } else {
      context
          .read<PatientActionsCubit>()
          .add(UpdatePatientEvent(widget.patientId!, patient));
    }
  }

  Future<void> _handleTransfer(BuildContext context) async {
    if (widget.patientId == null) return;
    final result = await TransferPatientBottomSheet.show(
      context,
      sourceId: widget.patientId!,
      sourceName: _loadedPatient?.name,
    );
    if (result == null || !mounted) return;
    // The source patient may no longer exist — replace rather than push, so
    // "back" never lands on a deleted record.
    Get.off(() => PatientFormPage(
        mode: PatientFormMode.view, patientId: result.targetId));
  }

  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDark) {
    return CustomMaterialIndicator(
      onRefresh: () async {
        try {
          if (widget.mode != PatientFormMode.add && widget.patientId != null) {
            context
                .read<GetSinglePatientCubit>()
                .add(GetPatientByIdEvent(widget.patientId!));
            context
                .read<GetPatientExaminationsCubit>()
                .getExaminations(widget.patientId!);
          }
          if (AuthService.showClinicSelection) {
            context
                .read<GetClinicsCubit>()
                .add(GetAllClinicsEvent(noPagination: true));
          }
        } catch (e) {
          log(e.toString());
        }
      },
      indicatorBuilder: (BuildContext context, IndicatorController controller) {
        return const Image(image: AssetImage("assets/icons/logo.png"));
      },
      child: widget.mode == PatientFormMode.add
          ? _buildForm(context, theme, isDark)
          : BlocBuilder<GetSinglePatientCubit, GetSinglePatientState>(
              builder: (context, singleState) {
                if (singleState.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (singleState.noConnection) {
                  return NoInternet(
                    fromTop: 0,
                    onPressed: () {
                      context.read<GetSinglePatientCubit>().add(
                            GetPatientByIdEvent(widget.patientId!),
                          );
                    },
                  );
                }

                if (singleState.isError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(singleState.errorMessage ??
                            'Failed to load patient details'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<GetSinglePatientCubit>().add(
                                  GetPatientByIdEvent(widget.patientId!),
                                );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isReadOnly
                      ? _buildPatientDetailView(theme, isDark)
                      : _buildForm(context, theme, isDark),
                );
              },
            ),
    );
  }
}

class _InfoItemData {
  final String label;
  final String value;
  final IconData icon;

  _InfoItemData({required this.label, required this.value, required this.icon});
}
