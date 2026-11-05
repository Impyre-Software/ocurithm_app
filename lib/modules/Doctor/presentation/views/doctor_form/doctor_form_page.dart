import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' as getx;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ocurithm/Services/whatsapp_confirmation.dart';
import 'package:ocurithm/core/Network/shared.dart';
import 'package:ocurithm/core/utils/auth_service.dart';
import 'package:ocurithm/core/utils/services_locator.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';
import 'package:ocurithm/core/widgets/capabilities_section.dart';
import 'package:ocurithm/core/widgets/height_spacer.dart';
import 'package:ocurithm/core/utils/capability_keys.dart';
import 'package:ocurithm/core/widgets/manage_capabilities.dart';
import 'package:ocurithm/core/widgets/text_field.dart';
import 'package:ocurithm/generated/l10n.dart';
import 'package:ocurithm/modules/Branch/presentation/manager/get_branches_cubit/get_branches_cubit.dart';
import 'package:ocurithm/modules/Clinics/presentation/manager/get_clinics_cubit/get_clinics_cubit.dart';
import 'package:ocurithm/modules/Doctor/presentation/manager/doctor_actions_cubit/doctor_actions_cubit.dart';
import 'package:ocurithm/modules/Doctor/presentation/manager/get_single_doctor_cubit/get_single_doctor_cubit.dart';
import 'package:ocurithm/modules/Receptionist/presentation/manager/get_capabilities_cubit/get_capabilities_cubit.dart';
import 'package:password_generator/password_generator.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../../modules/Login/data/model/login_response.dart';
import '../../../../../core/widgets/DropdownPackage.dart';
import '../../../../../core/widgets/confirmation_popuo.dart';
import '../../../../../core/widgets/fullscreen_image_viewer.dart';
import '../../../../../core/widgets/no_internet.dart';
import '../../../../Clinics/data/model/clinics_model.dart';
import '../../../data/model/doctor_model.dart';
import '../../manager/doctor_branch_actions_cubit/doctor_branch_actions_cubit.dart';
import '../../manager/get_doctor_examinations_cubit/get_doctor_examinations_cubit.dart';
import 'widgets/add_doctor_branch_dialog.dart';
import 'widgets/doctor_examinations_section.dart';

// Helper class for info items
class _InfoItemData {
  final String label;
  final String value;
  final IconData icon;

  _InfoItemData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

/// Form mode enum
enum DoctorFormMode { add, edit, view }

/// Unified Doctor Form Page
/// Handles add, edit, and view modes in a single page
class DoctorFormPage extends StatelessWidget {
  final DoctorFormMode mode;
  final String? doctorId;

  const DoctorFormPage({
    super.key,
    required this.mode,
    this.doctorId,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<DoctorActionsCubit>(),
        ),
        if (mode != DoctorFormMode.add)
          BlocProvider(
            create: (_) =>
                sl<GetSingleDoctorCubit>()..add(GetDoctorByIdEvent(doctorId!)),
          ),
        if (AuthService.showClinicSelection)
          BlocProvider(
            create: (_) => sl<GetClinicsCubit>()
              ..add(GetAllClinicsEvent(noPagination: true)),
          ),
        BlocProvider(
          create: (_) => sl<DoctorBranchActionsCubit>(),
        ),
        BlocProvider(
          create: (_) => sl<GetBranchesCubit>(),
        ),
        // Fetch capabilities for doctors as well
        BlocProvider(
          create: (_) =>
              sl<GetCapabilitiesCubit>()..add(GetAllCapabilitiesEvent()),
        ),
      ],
      child: DoctorFormView(mode: mode, doctorId: doctorId),
    );
  }
}

class DoctorFormView extends StatefulWidget {
  final DoctorFormMode mode;
  final String? doctorId;

  const DoctorFormView({
    super.key,
    required this.mode,
    this.doctorId,
  });

  @override
  State<DoctorFormView> createState() => _DoctorFormViewState();
}

class _DoctorFormViewState extends State<DoctorFormView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _qualificationsController;
  late TextEditingController _commissionController;

  // Form state
  String? _imageUrl;
  DateTime? _birthDate;
  String? _selectedClinicId;
  List<Capability> _selectedCapabilities = [];
  bool _isConsultant = false;

  bool _obscurePassword = true;
  late bool _isReadOnlyState;
  Doctor? _loadedDoctor;

  // Validation flags
  bool _isNameValid = true;
  bool _isPhoneValid = true;
  bool _isBirthDateValid = true;

  // Password generator
  final _passwordGenerator = PasswordGenerator(
    length: 8,
    hasCapitalLetters: true,
    hasNumbers: true,
    hasSmallLetters: true,
    hasSymbols: true,
  );

  @override
  void initState() {
    super.initState();
    _isReadOnlyState = widget.mode == DoctorFormMode.view;
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _qualificationsController = TextEditingController();
    _commissionController = TextEditingController();

    // Load data for edit/view modes
    if (widget.mode != DoctorFormMode.add) {
      _loadDoctorData();
    }

    if (!AuthService.isAdmin) {
      _selectedClinicId = AuthService.userClinic?.id;
    }
  }

  void _loadDoctorData() {
    if (widget.doctorId != null) {
      context
          .read<GetSingleDoctorCubit>()
          .add(GetDoctorByIdEvent(widget.doctorId!));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _qualificationsController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  bool get _isReadOnly => _isReadOnlyState;

  bool get _isAddMode => widget.mode == DoctorFormMode.add;

  String get _pageTitle {
    switch (widget.mode) {
      case DoctorFormMode.add:
        return 'Add Doctor';
      case DoctorFormMode.edit:
        return 'Edit Doctor';
      case DoctorFormMode.view:
        return 'Doctor Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => WidgetsBinding.instance.focusManager.primaryFocus!.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // Edit button in view mode
            if (widget.mode != DoctorFormMode.add)
              manageCapability(
                capability: CapabilityKeys.manageDoctors,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isReadOnlyState = !_isReadOnlyState;
                      // If reverting to read-only, reset form data
                      if (_isReadOnlyState && _loadedDoctor != null) {
                        _populateForm(_loadedDoctor!);
                      }
                    });
                  },
                  icon: Icon(
                    _isReadOnly ? Icons.edit : Icons.close,
                  ),
                ),
              ),
            // Add Branch button
            if (widget.mode != DoctorFormMode.add &&
                CacheHelper.getStringList(key: "capabilities")
                    .contains(CapabilityKeys.manageDoctors) &&
                _loadedDoctor != null)
              IconButton(
                onPressed: () {
                  _showAddBranchDialog(context);
                },
                icon: SvgPicture.asset(
                  "assets/icons/add_branch.svg",
                  colorFilter: ColorFilter.mode(
                      isDark ? Colors.white : Colors.black, BlendMode.srcIn),
                ),
              ),
          ],
        ),
        body: MultiBlocListener(
          listeners: [
            // Listen to single doctor fetch (for edit/view)
            if (widget.mode != DoctorFormMode.add)
              BlocListener<GetSingleDoctorCubit, GetSingleDoctorState>(
                listener: (context, state) {
                  if (state.isSuccess && state.doctor != null) {
                    _populateForm(state.doctor!);
                  }
                },
              ),
            // Listen to capabilities fetch to map them if doctor is already loaded
            if (widget.mode != DoctorFormMode.add)
              BlocListener<GetCapabilitiesCubit, GetCapabilitiesState>(
                listener: (context, state) {
                  if (state.isSuccess &&
                      state.capabilities != null &&
                      _loadedDoctor != null) {
                    _mapCapabilities(_loadedDoctor!, state.capabilities!);
                  }
                },
              ),
            // Listen to actions (add/update)
            BlocListener<DoctorActionsCubit, DoctorActionsState>(
              listener: (context, state) async {
                if (state.isSuccess &&
                    (state.actionType == DoctorActionType.add ||
                        state.actionType == DoctorActionType.update)) {
                  // Send WhatsApp message only for add success
                  if (state.actionType == DoctorActionType.add && _isAddMode) {
                    await WhatsAppConfirmation().sendWhatsAppMessage(
                      _phoneController.text,
                      "Welcome to our clinics ❤️ .\n You can now sign in, by downloading Ocurithm application. \n Your credentials: \n username: ${_phoneController.text} \n password: ${_passwordController.text} \n Thank you.",
                    );
                  }

                  SnackbarService.showSuccess(
                    context,
                    message: state.successMessage ?? 'Success',
                  );

                  // Refresh list if manager is available in context (it might not be if we popped)
                  // But usually we return result
                  Navigator.of(context).pop(true);
                } else if (state.isError) {
                  SnackbarService.showError(
                    context,
                    message: state.errorMessage ?? 'Error occurred',
                  );
                }
              },
            ),
            BlocListener<DoctorBranchActionsCubit, DoctorBranchActionsState>(
              listener: (context, state) {
                if (state.isSuccess) {
                  // Refresh doctor data
                  _loadDoctorData();
                  SnackbarService.showSuccess(
                    context,
                    message:
                        state.successMessage ?? "Branch operation successful",
                  );
                } else if (state.isError) {
                  SnackbarService.showError(
                    context,
                    message: state.errorMessage ?? "An error occurred",
                  );
                }
              },
            ),
          ],
          child: AuthService.showClinicSelection
              ? BlocBuilder<GetClinicsCubit, GetClinicsState>(
                  builder: (context, clinicsState) {
                    return BlocBuilder<GetCapabilitiesCubit,
                        GetCapabilitiesState>(
                      builder: (context, capabilitiesState) {
                        // If any critical dependency has NO CONNECTION, show NoInternet
                        if (clinicsState.noConnection ||
                            capabilitiesState.noConnection) {
                          return NoInternet(
                            fromTop: 0,
                            onPressed: () {
                              if (clinicsState.noConnection) {
                                context.read<GetClinicsCubit>().add(
                                    GetAllClinicsEvent(noPagination: true));
                              }
                              if (capabilitiesState.noConnection) {
                                context
                                    .read<GetCapabilitiesCubit>()
                                    .add(GetAllCapabilitiesEvent());
                              }
                              if (widget.mode != DoctorFormMode.add) {
                                context.read<GetSingleDoctorCubit>().add(
                                      GetDoctorByIdEvent(widget.doctorId!),
                                    );
                              }
                            },
                          );
                        }

                        // If any critical dependency has an ERROR (not noConnection), show error view
                        if (clinicsState.isError || capabilitiesState.isError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(clinicsState.errorMessage ??
                                    capabilitiesState.errorMessage ??
                                    'Failed to load required data'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    if (clinicsState.isError) {
                                      context.read<GetClinicsCubit>().add(
                                          GetAllClinicsEvent(
                                              noPagination: true));
                                    }
                                    if (capabilitiesState.isError) {
                                      context
                                          .read<GetCapabilitiesCubit>()
                                          .add(GetAllCapabilitiesEvent());
                                    }
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }

                        return _buildMainContent(context, theme, isDark);
                      },
                    );
                  },
                )
              : BlocBuilder<GetCapabilitiesCubit, GetCapabilitiesState>(
                  builder: (context, capabilitiesState) {
                    if (capabilitiesState.noConnection) {
                      return NoInternet(
                        fromTop: 0,
                        onPressed: () {
                          context
                              .read<GetCapabilitiesCubit>()
                              .add(GetAllCapabilitiesEvent());
                          if (widget.mode != DoctorFormMode.add) {
                            context.read<GetSingleDoctorCubit>().add(
                                  GetDoctorByIdEvent(widget.doctorId!),
                                );
                          }
                        },
                      );
                    }
                    if (capabilitiesState.isError) {
                      return Center(
                        child: Text(capabilitiesState.errorMessage ?? 'Error'),
                      );
                    }
                    return _buildMainContent(context, theme, isDark);
                  },
                ),
        ),
        bottomNavigationBar:
            _isReadOnly ? null : _buildBottomBar(context, theme, isDark),
      ),
    );
  }

  Widget _buildShimmer(Widget child, ThemeData theme, bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[700]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[600]! : Colors.grey[100]!,
      child: child,
    );
  }

  Widget _buildFormWithShimmer(
      BuildContext context, ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image Shimmer
          Center(
            child: _buildShimmer(
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.cardColor,
                ),
              ),
              theme,
              isDark,
            ),
          ),
          const HeightSpacer(size: 24),

          // Name Field Shimmer
          _buildShimmer(
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: theme.cardColor,
              ),
            ),
            theme,
            isDark,
          ),
          const HeightSpacer(size: 20),

          // Phone Field Shimmer
          _buildShimmer(
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: theme.cardColor,
              ),
            ),
            theme,
            isDark,
          ),
          const HeightSpacer(size: 20),

          // Qualifications Field Shimmer
          _buildShimmer(
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.cardColor,
              ),
            ),
            theme,
            isDark,
          ),
          const HeightSpacer(size: 20),

          // Clinic Dropdown Shimmer (if user has permission)
          if (AuthService.showClinicSelection)
            _buildShimmer(
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: theme.cardColor,
                ),
              ),
              theme,
              isDark,
            ),
          if (AuthService.showClinicSelection) const HeightSpacer(size: 20),

          // Capabilities Shimmer
          _buildShimmer(
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: theme.cardColor,
              ),
            ),
            theme,
            isDark,
          ),
          const HeightSpacer(size: 20),

          // Birth Date Shimmer
          _buildShimmer(
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: theme.cardColor,
              ),
            ),
            theme,
            isDark,
          ),
          const HeightSpacer(size: 24),
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
            // Profile Image
            Center(
              child: ProfileImagePicker(
                initialImageUrl: _imageUrl,
                readOnly: _isReadOnly,
                onDelete: () {
                  setState(() {
                    _imageUrl = null;
                  });
                },
                onImageUploaded: (String url) {
                  setState(() {
                    _imageUrl = url;
                  });
                },
              ),
            ),
            const HeightSpacer(size: 24),

            // Name Field
            _buildTextField(
              controller: _nameController,
              hintText: S.of(context).fullName,
              icon: 'assets/icons/profile.svg',
              isValid: _isNameValid,
              readOnly: _isReadOnly,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  setState(() => _isNameValid = false);
                  return S.of(context).mustUsername;
                }
                setState(() => _isNameValid = true);
                return null;
              },
            ),
            const HeightSpacer(size: 20),

            // Phone Field
            _buildTextField(
              controller: _phoneController,
              hintText: S.of(context).phone,
              icon: 'assets/icons/phone_number.svg',
              keyboardType: TextInputType.phone,
              isValid: _isPhoneValid,
              readOnly: _isReadOnly,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  setState(() => _isPhoneValid = false);
                  return S.of(context).mustPhone;
                } else if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(value)) {
                  setState(() => _isPhoneValid = false);
                  return S.of(context).invalidPhoneNumber;
                }
                setState(() => _isPhoneValid = true);
                return null;
              },
            ),
            const HeightSpacer(size: 20),

            // Password Field (Add mode only)
            if (_isAddMode) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildPasswordField(theme),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 1,
                    child: _buildPasswordGeneratorButton(theme, isDark),
                  ),
                ],
              ),
              const HeightSpacer(size: 20),
            ],

            // Qualifications Field (Multi-line text field)
            _buildQualificationsField(theme),
            const HeightSpacer(size: 20),

            // Appointment Commission (%)
            _buildCommissionField(theme),
            const HeightSpacer(size: 20),

            // Is Consultant Checkbox
            _buildIsConsultantCheckbox(theme, isDark),
            const HeightSpacer(size: 20),

            // Clinic Dropdown (if user has permission)
            if (_isAddMode && AuthService.showClinicSelection)
              _buildClinicDropdown(context, theme, isDark),

            // Capabilities Multi-Select (hidden in add mode)
            if (!_isAddMode)
              _buildCapabilitiesSection(context, theme, isDark,
                  capabilities: GetSingleDoctorCubit.get(context)
                      .state
                      .doctor
                      ?.capabilities),
            if (!_isAddMode) const HeightSpacer(size: 20),

            // Birth Date Picker
            _buildBirthDatePicker(context, theme, isDark),
            const HeightSpacer(size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String icon,
    required bool isValid,
    required String? Function(String?) validator,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hintText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const HeightSpacer(size: 8),
        TextField2(
          controller: controller,
          required: true,
          type: keyboardType,
          hintText: hintText,
          fillColor: theme.cardColor,
          borderColor: primaryColor,
          border: primaryColor,
          radius: 30,
          readOnly: readOnly,
          suffixIcon: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
            child: SvgPicture.asset(
              icon,
              color: primaryColor,
            ),
          ),
          isShadow: false,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).password,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const HeightSpacer(size: 8),
        TextField2(
          controller: _passwordController,
          required: true,
          hintText: S.of(context).password,
          fillColor: theme.cardColor,
          borderColor: theme.primaryColor,
          border: theme.primaryColor,
          radius: 30,
          isPassword: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
            ),
            color: theme.primaryColor,
          ),
          isShadow: false,
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
      ],
    );
  }

  Widget _buildPasswordGeneratorButton(ThemeData theme, bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              spreadRadius: 2,
              blurRadius: 3,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () {
            final generatedPassword = _passwordGenerator.generatePassword();
            final entropy = generatedPassword.checkStrength();
            if (entropy >= 28) {
              setState(() {
                _passwordController.text = generatedPassword;
              });
              SnackbarService.showSuccess(
                context,
                message: "Password generated successfully",
              );
            }
          },
          icon: SvgPicture.asset(
            'assets/icons/password.svg',
            color: theme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQualificationsField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Qualifications",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const HeightSpacer(size: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _qualificationsController,
            readOnly: _isReadOnly,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Qualifications',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Qualifications are required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  /// Per-doctor override for the appointment commission split — the first
  /// level of the cascade, before branch then clinic. Matches web's
  /// DoctorForm: plain 0-100 number field, empty meaning "not set".
  Widget _buildCommissionField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Appointment Commission (%)",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const HeightSpacer(size: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _commissionController,
            readOnly: _isReadOnly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Defaults to branch / clinic',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final parsed = num.tryParse(value.trim());
              if (parsed == null) return 'Enter a valid number';
              if (parsed < 0 || parsed > 100) {
                return 'Must be between 0 and 100';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIsConsultantCheckbox(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: CheckboxListTile(
        value: _isConsultant,
        onChanged: _isReadOnly
            ? null
            : (bool? value) {
                setState(() {
                  _isConsultant = value ?? false;
                });
              },
        title: Text(
          'Is Consultant',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _isReadOnly
                ? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)
                : null,
          ),
        ),
        subtitle: Text(
          'Mark this doctor as a consultant',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        activeColor: theme.primaryColor,
        checkColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildClinicDropdown(
      BuildContext context, ThemeData theme, bool isDark) {
    return BlocBuilder<GetClinicsCubit, GetClinicsState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(bottom: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Clinic",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const HeightSpacer(size: 8),
              DropdownItem(
                radius: 30,
                color: theme.cardColor,
                border: theme.primaryColor,
                isShadow: false,
                iconData: Icon(
                  Icons.arrow_drop_down_circle,
                  color: theme.primaryColor,
                ),
                items: state.clinics?.clinics ?? [],
                isValid: true,
                validateText: 'Clinic must not be empty',
                selectedValue: _selectedClinicId != null
                    ? state.clinics?.clinics
                        .firstWhere((c) => c.id == _selectedClinicId)
                        .name
                    : null,
                hintText: 'Select Clinic',
                itemAsString: (item) => item.name.toString(),
                readOnly: _isReadOnly,
                onItemSelected: (item) {
                  setState(() {
                    _selectedClinicId = item.id;
                  });
                  // Load branches for selected clinic
                  context.read<GetBranchesCubit>().add(
                        SetClinicFilterEvent(_selectedClinicId),
                      );
                },
                isLoading: state.isLoading,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCapabilitiesSection(
      BuildContext context, ThemeData theme, bool isDark,
      {List<Capability>? capabilities}) {
    return BlocBuilder<GetCapabilitiesCubit, GetCapabilitiesState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: theme.primaryColor),
            ),
          );
        }

        if (state.isSuccess && state.capabilities != null) {
          return CapabilitiesSection(
            capabilities: state.capabilities!,
            catalog: state.catalog,
            readOnly: _isReadOnly,
            initialSelectedCapabilities: capabilities ?? [],
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedCapabilities = newSelection;
              });
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBirthDatePicker(
      BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(thickness: 0.4, color: theme.dividerColor),
        const HeightSpacer(size: 16),
        Text(
          S.of(context).dateOfBirth,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const HeightSpacer(size: 12),
        InkWell(
          onTap: _isReadOnly
              ? null
              : () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate:
                        DateTime.now().subtract(const Duration(days: 6570)),
                    // 18 years
                    builder: (context, child) {
                      return Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: theme.primaryColor,
                            onPrimary: Colors.white,
                            surface: theme.cardColor,
                            onSurface: theme.textTheme.bodyLarge?.color,
                          ),
                          dialogBackgroundColor: theme.cardColor,
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (selectedDate != null) {
                    setState(() {
                      _birthDate = selectedDate;
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
                color: _isBirthDateValid ? theme.primaryColor : Colors.red,
              ),
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
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 30,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _birthDate != null
                          ? '${_birthDate!.month}'
                          : S.of(context).mm,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: 30,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _birthDate != null
                          ? '${_birthDate!.year}'
                          : S.of(context).yy,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ThemeData theme, bool isDark) {
    return BlocBuilder<DoctorActionsCubit, DoctorActionsState>(
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade300,
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: state.isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: state.isLoading
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isAddMode ? 'Add Doctor' : 'Update Doctor',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate birth date
    if (_birthDate == null) {
      setState(() => _isBirthDateValid = false);
      SnackbarService.showError(
        context,
        message: 'Please select birth date',
      );
      return;
    }

    // Validate clinic selection (if user has permission)
    if (_isAddMode &&
        AuthService.showClinicSelection &&
        _selectedClinicId == null) {
      SnackbarService.showError(
        context,
        message: 'Please select a clinic',
      );
      return;
    }

    // Create Doctor object
    final doctor = Doctor(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _isAddMode ? _passwordController.text : null,
      qualifications: _qualificationsController.text.trim(),
      birthDate: _birthDate,
      image: _imageUrl,
      clinic: (_isAddMode && _selectedClinicId != null)
          ? Clinic(id: _selectedClinicId, name: null)
          : null,
      capability: _selectedCapabilities.map((c) => c.id).toList(),
      isConsultant: _isConsultant,
      // Empty means "not set" — omitted by the repo (matches the pattern
      // already used for qualifications/image/isConsultant here), so leaving
      // this untouched never wipes an existing override.
      appointmentCommissionPercentage: _commissionController.text.trim().isEmpty
          ? null
          : num.tryParse(_commissionController.text.trim()),
    );

    // Dispatch appropriate event
    if (_isAddMode) {
      context.read<DoctorActionsCubit>().add(AddDoctorEvent(doctor));
    } else {
      context.read<DoctorActionsCubit>().add(
            UpdateDoctorEvent(
              doctorId: widget.doctorId!,
              doctor: doctor,
            ),
          );
    }
  }

  void _populateForm(Doctor doctor) {
    setState(() {
      _loadedDoctor = doctor;
      _nameController.text = doctor.name ?? '';
      _phoneController.text = doctor.phone ?? '';
      _qualificationsController.text = doctor.qualifications ?? '';
      _commissionController.text =
          doctor.appointmentCommissionPercentage?.toString() ?? '';
      _birthDate = doctor.birthDate;
      _imageUrl = doctor.image;

      if (!AuthService.isAdmin) {
        _selectedClinicId = AuthService.userClinic?.id;
      } else {
        _selectedClinicId = doctor.clinic?.id;
      }

      _isConsultant = doctor.isConsultant ?? false;

      // Load branches if clinic is selected
      if (_selectedClinicId != null) {
        context.read<GetBranchesCubit>().add(
              SetClinicFilterEvent(_selectedClinicId),
            );
      }
    });

    // Map capabilities if they're available
    final capabilitiesState = context.read<GetCapabilitiesCubit>().state;
    if (capabilitiesState.isSuccess && capabilitiesState.capabilities != null) {
      _mapCapabilities(doctor, capabilitiesState.capabilities!);
    }
  }

  void _mapCapabilities(Doctor doctor, List<Capability> allCapabilities) {
    if (doctor.capabilities == null || doctor.capabilities!.isEmpty) {
      return;
    }

    setState(() {
      _selectedCapabilities = allCapabilities.where((cap) {
        return doctor.capabilities!.any((docCap) {
          // Robust ID matching
          return docCap.id.toString() == cap.id.toString();
        });
      }).toList();
    });
  }

  void _showAddBranchDialog(BuildContext context,
      {BranchElement? branchToEdit}) {
    if (_loadedDoctor?.clinic?.id == null) {
      SnackbarService.showError(
        context,
        message: "Doctor clinic not found",
      );
      return;
    }

    getx.Get.dialog(
      BlocProvider.value(
        value: context.read<DoctorBranchActionsCubit>(),
        child: BlocProvider.value(
          value: context.read<GetBranchesCubit>(),
          child: AddDoctorBranchDialog(
            doctorId: widget.doctorId!,
            clinicId: _loadedDoctor!.clinic!.id!,
            existingBranches: _loadedDoctor!.branches ?? [],
            initialBranch: branchToEdit,
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBranch(BuildContext context, BranchElement branch) {
    showConfirmationDialog(
      context: context,
      title: "Delete Branch",
      message: "Are you sure you want to remove this branch?",
      confirmText: "Delete",
      confirmColor: Colors.red,
      icon: Icons.delete_outline,
      onConfirm: () {
        context.read<DoctorBranchActionsCubit>().add(
              DeleteDoctorBranchEvent(
                doctorId: widget.doctorId!,
                branchId:
                    branch.branch?.id?.toString() ?? branch.branchId ?? '',
              ),
            );
      },
    );
  }

  // Build Branches Section
  List<Widget> _buildBranchesSection(
      BuildContext context, ThemeData theme, bool isDark) {
    return [
      Divider(
        thickness: 0.4,
        color: theme.dividerColor,
      ),
      const HeightSpacer(size: 20),
      Text(
        'Branches',
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      const HeightSpacer(size: 10),
      BlocBuilder<GetSingleDoctorCubit, GetSingleDoctorState>(
        builder: (context, state) {
          if (state.isLoading || _loadedDoctor == null) {
            return _buildShimmer(
              Container(
                width: MediaQuery.sizeOf(context).width,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.cardColor,
                ),
              ),
              theme,
              isDark,
            );
          }

          final branches = _loadedDoctor!.branches ?? [];

          if (branches.isEmpty) {
            return Center(
              child: Column(
                children: [
                  const HeightSpacer(size: 20),
                  SvgPicture.asset(
                    "assets/icons/branch.svg",
                    colorFilter: ColorFilter.mode(
                      theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.5) ??
                          Colors.grey,
                      BlendMode.srcIn,
                    ),
                    width: 50,
                    height: 50,
                  ),
                  const HeightSpacer(size: 12),
                  Text(
                    "No Branches Available",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const HeightSpacer(size: 20),
                ],
              ),
            );
          }

          // Display branches inline (without old cubit dependency)
          return ListView.builder(
            padding: const EdgeInsets.all(0),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: branches.length,
            itemBuilder: (context, index) {
              final branchData = branches[index];
              final branch = branchData.branch;
              final availableDays = List<String>.from(branchData.availableDays);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branch header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              branch?.code ?? 'N/A',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              branch?.name ?? 'N/A',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          // Edit/Delete Menu
                          if (widget.mode != DoctorFormMode.add &&
                              CacheHelper.getStringList(key: "capabilities")
                                  .contains(CapabilityKeys.manageDoctors))
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showAddBranchDialog(context,
                                      branchToEdit: branchData);
                                } else if (value == 'delete') {
                                  _confirmDeleteBranch(context, branchData);
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit,
                                            size: 20,
                                            color: theme.primaryColor),
                                        const SizedBox(width: 8),
                                        const Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Branch hours
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 20,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Branch Hours:',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${branch?.openTime ?? ""} - ${branch?.closeTime ?? ""}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Available hours
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 20,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Available Hours:',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${branchData.availableFrom ?? ""} - ${branchData.availableTo ?? ""}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Working days
                      Text(
                        'Working Days:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<String>.from(branch?.workDays ?? [])
                            .map((day) {
                          final isAvailable = availableDays.contains(day);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? theme.primaryColor
                                  : theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              day.substring(0, 1).toUpperCase() +
                                  day.substring(1),
                              style: TextStyle(
                                color: isAvailable
                                    ? Colors.white
                                    : theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      const HeightSpacer(size: 20),
    ];
  }

  Widget _buildDoctorDetailView(ThemeData theme, bool isDark) {
    if (_loadedDoctor == null) return const SizedBox.shrink();
    final doctor = _loadedDoctor!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildDetailHeader(doctor, theme, isDark),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(
                  title: 'Personal Information',
                  items: [
                    _InfoItemData(
                      label: 'Phone',
                      value: doctor.phone ?? 'N/A',
                      icon: Icons.phone_outlined,
                    ),
                    _InfoItemData(
                      label: 'Birth Date',
                      value: doctor.birthDate != null
                          ? DateFormat('MMM dd, yyyy').format(doctor.birthDate!)
                          : 'N/A',
                      icon: Icons.cake_outlined,
                    ),
                    _InfoItemData(
                      label: 'Is Consultant',
                      value: doctor.isConsultant == true ? 'Yes' : 'No',
                      icon: Icons.work_outline,
                    ),
                  ],
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildInfoSection(
                  title: 'Professional Information',
                  items: [
                    _InfoItemData(
                      label: 'Qualifications',
                      value: doctor.qualifications ?? 'N/A',
                      icon: Icons.school_outlined,
                    ),
                    _InfoItemData(
                      label: 'Clinic',
                      value: doctor.clinic?.name ?? 'N/A',
                      icon: Icons.local_hospital_outlined,
                    ),
                  ],
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                // Branches Section
                ..._buildBranchesSection(context, theme, isDark),

                // Examinations Section (Only for Consultants)
                if (doctor.isConsultant == true) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  BlocProvider(
                    create: (_) => sl<GetDoctorExaminationsBloc>()
                      ..add(SetDoctorIdEvent(doctor.id!)),
                    child: const DoctorExaminationsSection(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(Doctor doctor, ThemeData theme, bool isDark) {
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
            child: ClipOval(
              child: doctor.image != null && doctor.image!.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        if (doctor.image != null && doctor.image!.isNotEmpty) {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (context, _, __) =>
                                  FullscreenImageViewer(
                                imageUrls: [doctor.image!],
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: doctor.image!,
                        child: Image.network(
                          doctor.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                doctor.name?.isNotEmpty == true
                                    ? doctor.name![0].toUpperCase()
                                    : 'D',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        doctor.name?.isNotEmpty == true
                            ? doctor.name![0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            doctor.name ?? 'Unknown Doctor',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              doctor.isConsultant == true ? 'Consultant' : 'Doctor',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
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

  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDark) {
    return CustomMaterialIndicator(
      onRefresh: () async {
        try {
          if (widget.mode != DoctorFormMode.add && widget.doctorId != null) {
            context
                .read<GetSingleDoctorCubit>()
                .add(GetDoctorByIdEvent(widget.doctorId!));
          }
          if (AuthService.showClinicSelection) {
            context
                .read<GetClinicsCubit>()
                .add(GetAllClinicsEvent(noPagination: true));
          }
          context.read<GetCapabilitiesCubit>().add(GetAllCapabilitiesEvent());
        } catch (e) {
          log(e.toString());
        }
      },
      indicatorBuilder: (BuildContext context, IndicatorController controller) {
        return const Image(image: AssetImage("assets/icons/logo.png"));
      },
      child: _isAddMode
          ? _buildForm(context, theme, isDark)
          : BlocBuilder<GetSingleDoctorCubit, GetSingleDoctorState>(
              builder: (context, singleState) {
                if (singleState.isLoading) {
                  return _buildFormWithShimmer(context, theme, isDark);
                }

                if (singleState.noConnection) {
                  return NoInternet(
                    fromTop: 0,
                    onPressed: () {
                      context.read<GetSingleDoctorCubit>().add(
                            GetDoctorByIdEvent(widget.doctorId!),
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
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(singleState.errorMessage ??
                            'Failed to load doctor'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<GetSingleDoctorCubit>().add(
                                  GetDoctorByIdEvent(widget.doctorId!),
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
                      ? _buildDoctorDetailView(theme, isDark)
                      : _buildForm(context, theme, isDark),
                );
              },
            ),
    );
  }
}

// Profile Image Picker Widget (reused from existing code)
class ProfileImagePicker extends StatefulWidget {
  final Function(String) onImageUploaded;
  final String? initialImageUrl;
  final bool? readOnly;
  final Function() onDelete;

  const ProfileImagePicker({
    super.key,
    required this.onImageUploaded,
    this.initialImageUrl,
    this.readOnly = false,
    required this.onDelete,
  });

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isImageDeleted = false;

  void _handleDelete() {
    setState(() {
      _imageFile = null;
      _isImageDeleted = true;
    });
    widget.onDelete();
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final url = await CloudinaryService.uploadImage(_imageFile!);

      if (url != null) {
        widget.onImageUploaded(url);
      } else {
        _showError('Failed to upload image');
      }
    } catch (e) {
      _showError('Error uploading image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showError(String message) {
    SnackbarService.showError(
      context,
      message: message,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final sizeInBytes = await file.length();
        final sizeInMb = sizeInBytes / (1024 * 1024);

        if (sizeInMb > 10) {
          _showError('Image size should be less than 10MB');
          return;
        }

        setState(() {
          _imageFile = file;
        });
        await _uploadImage();
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _isUploading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: theme.primaryColor),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading...',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ClipOval(
                  child: _imageFile != null
                      ? GestureDetector(
                          onTap: () {
                            if (_imageFile != null) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (context, _, __) =>
                                      FullscreenImageViewer(
                                    imageUrls: [_imageFile!],
                                  ),
                                ),
                              );
                            }
                          },
                          child: Hero(
                            tag: _imageFile!,
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                          ),
                        )
                      : (!_isImageDeleted && widget.initialImageUrl != null)
                          ? GestureDetector(
                              onTap: () {
                                if (widget.initialImageUrl != null) {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: false,
                                      pageBuilder: (context, _, __) =>
                                          FullscreenImageViewer(
                                        imageUrls: [widget.initialImageUrl!],
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Hero(
                                tag: widget.initialImageUrl!,
                                child: Image.network(
                                  widget.initialImageUrl!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.person,
                                          size: 60, color: Colors.grey),
                                ),
                              ),
                            )
                          : const Icon(Icons.person,
                              size: 60, color: Colors.grey),
                ),
        ),
        if (!_isUploading && widget.readOnly != true)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _showImageSourceDialog(_handleDelete),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showImageSourceDialog(Function() onDelete) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Image Source'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Choose from Gallery'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Take a Photo'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete, color: CupertinoColors.activeBlue),
                SizedBox(width: 8),
                Text('Delete Photo'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: CupertinoColors.destructiveRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Cloudinary Service (reused from existing code)
class CloudinaryService {
  static const String cloudName = 'dxsrhu3ku';
  static const String uploadPreset = 'ocurithm';
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1/$cloudName';

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse('$_baseUrl/image/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'public';
      request.fields['timestamp'] =
          DateTime.now().millisecondsSinceEpoch.toString();

      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['secure_url'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      return null;
    }
  }
}
