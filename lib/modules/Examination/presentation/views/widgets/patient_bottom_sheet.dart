import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:ocurithm/core/utils/colors.dart';
import 'package:ocurithm/core/utils/format_helper.dart';
import 'package:ocurithm/core/utils/services_locator.dart';
import 'package:ocurithm/modules/Examination/data/model/patient_overview_model.dart';
import 'package:ocurithm/modules/Examination/presentation/manager/patient_overview_cubit/patient_overview_cubit.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/examination_details_bottom_sheet.dart';
import 'package:shimmer/shimmer.dart';

class PatientDetailsBottomSheet extends StatelessWidget {
  final String patientId;

  const PatientDetailsBottomSheet({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<PatientOverviewCubit>()..getPatientOverview(patientId),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.fromLTRB(10.w, 20.h, 10.w, 0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 10.h),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Patient Profile',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .disabledColor
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Content
            Expanded(
              child: BlocBuilder<PatientOverviewCubit, PatientOverviewState>(
                builder: (context, state) {
                  if (state is PatientOverviewLoading) {
                    return _buildShimmerLoading(context);
                  } else if (state is PatientOverviewError) {
                    return Center(
                      child: Text(state.error),
                    );
                  } else if (state is PatientOverviewSuccess) {
                    return _PatientOverviewContent(
                      overview: state.overview,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 140.h,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            SizedBox(height: 16.h),
            ...List.generate(
              4,
              (index) => Container(
                margin: EdgeInsets.only(bottom: 12.h),
                width: double.infinity,
                height: 70.h,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientOverviewContent extends StatelessWidget {
  final PatientOverviewModel overview;

  const _PatientOverviewContent({required this.overview});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Info Card
          if (overview.patient != null)
            _PatientInfoCard(patient: overview.patient!),

          SizedBox(height: 25.h),

          // Patient Details Section
          if (overview.patient != null)
            _PatientDetailsSection(patient: overview.patient!),

          SizedBox(height: 25.h),

          // Appointments Section
          _AppointmentsSection(appointments: overview.appointments),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  final PatientOverviewInfo patient;

  const _PatientInfoCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colorz.primaryColor.withValues(alpha: 0.9),
            Colorz.primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colorz.primaryColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            color: Colors.white70, size: 16.sp),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: Text(
                            patient.email ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  "assets/icons/patient.svg",
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn),
                  height: 24.h,
                  width: 24.w,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoItem(
                icon: Icons.phone_rounded,
                value: patient.phone ?? 'N/A',
              ),
              _buildInfoItem(
                icon: Icons.cake_rounded,
                value: _calculateAge(patient.birthDate),
              ),
              _buildInfoItem(
                icon: Icons.wc_rounded,
                value: patient.gender ?? 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null) return 'N/A';
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return '$age Yrs';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildInfoItem({required IconData icon, required String value}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16.sp),
        ),
        SizedBox(width: 8.w),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PatientDetailsSection extends StatelessWidget {
  final PatientOverviewInfo patient;

  const _PatientDetailsSection({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Details",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color:
                    Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color:
                    Theme.of(context).shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDetailRow(context, Icons.flag_rounded, "Nationality",
                  patient.nationality ?? 'N/A'),
              _buildDivider(context),
              _buildDetailRow(context, Icons.badge_rounded, "National ID",
                  patient.nationalId ?? 'N/A'),
              _buildDivider(context),
              _buildDetailRow(context, Icons.location_on_rounded, "Address",
                  patient.address ?? 'N/A'),
              _buildDivider(context),
              _buildDetailRow(context, Icons.local_hospital_rounded,
                  "Clinic", patient.clinicName ?? 'N/A'),
              _buildDivider(context),
              _buildDetailRow(context, Icons.business_rounded, "Branch",
                  patient.branchName ?? 'N/A'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colorz.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colorz.primaryColor, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
      height: 1,
    );
  }
}

class _AppointmentsSection extends StatelessWidget {
  final List<PatientAppointment> appointments;

  const _AppointmentsSection({required this.appointments});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Appointments",
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colorz.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${appointments.length}',
                style: TextStyle(
                  color: Colorz.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 15.h),
        if (appointments.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 50.sp, color: Colors.grey[300]),
                SizedBox(height: 10.h),
                Text(
                  "No appointments found",
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 14.sp),
                ),
              ],
            ),
          )
        else
          ...appointments
              .map((appointment) =>
                  _buildAppointmentItem(context, appointment))
              ,
      ],
    );
  }

  Widget _buildAppointmentItem(
      BuildContext context, PatientAppointment appointment) {
    final statusColor = _getStatusColor(appointment.status);
    // Only a visit that produced an examination has details to open.
    final canOpen = appointment.examinationId != null;

    return GestureDetector(
      onTap: canOpen
          ? () => showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ExaminationDetailsBottomSheet(
                  examinationId: appointment.examinationId!,
                ),
              )
          : null,
      child: Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canOpen
              ? Colorz.primaryColor.withValues(alpha: 0.35)
              : Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 100.w,
              height: 100.h,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  center: Alignment.topRight,
                  radius: 1,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: statusColor,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  appointment.typeName ?? 'General Visit',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  // A parked visit also names why: "SAVED · Dilation".
                                  child: Text.rich(
                                    TextSpan(
                                      text: appointment.status?.toUpperCase() ??
                                          'N/A',
                                      children: [
                                        if (appointment.saveReasonName != null)
                                          TextSpan(
                                            text:
                                                ' · ${appointment.saveReasonName}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _formatDate(appointment.date),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (appointment.description != null &&
                    appointment.description!.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(top: 15.h),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .disabledColor
                            .withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 14.sp, color: Colorz.primaryColor),
                              SizedBox(width: 6.w),
                              Text(
                                "Clinical Notes",
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colorz.primaryColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            appointment.description!,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (appointment.actions.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 15.h),
                    child: Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: appointment.actions
                          .map((action) => _buildActionChip(context, action))
                          .toList(),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 15.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: Colorz.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline_rounded,
                            size: 14.sp, color: Colorz.primaryColor),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Attending Physician: ',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                      Text(
                        'Dr. ${appointment.doctorName ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// One decision taken on that visit, e.g. "Prescribe glasses - Right".
  Widget _buildActionChip(BuildContext context, PatientAppointmentAction action) {
    final label = FormatHelper.capitalizeFirstLetter(action.action ?? '');
    if (label.isEmpty) return const SizedBox.shrink();

    final eye = action.eye?.trim();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colorz.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colorz.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        eye == null || eye.isEmpty
            ? label
            : '$label · ${FormatHelper.capitalizeFirstLetter(eye)}',
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: Colorz.primaryColor,
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'in progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd MMM, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
