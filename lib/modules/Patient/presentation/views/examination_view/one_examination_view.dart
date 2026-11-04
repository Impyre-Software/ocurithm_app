import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:ocurithm/core/utils/capability_keys.dart';
import 'package:ocurithm/core/utils/capability_services.dart';
import 'package:ocurithm/core/utils/services_locator.dart';
import 'package:ocurithm/core/utils/colors.dart';
import 'package:ocurithm/core/utils/snackbar_service.dart';
import 'package:ocurithm/modules/Examination/presentation/manager/examination_actions_cubit/examination_actions_cubit.dart';
import 'package:ocurithm/modules/Examination/presentation/views/widgets/examination_pdf_service.dart';
import 'package:ocurithm/modules/Patient/presentation/manager/get_one_examination_cubit/get_one_examination_cubit.dart';
import 'package:ocurithm/modules/Patient/presentation/views/examination_view/one_examination_content.dart';

class OneExaminationView extends StatefulWidget {
  const OneExaminationView({Key? key, required this.id}) : super(key: key);

  final String id;

  @override
  State<OneExaminationView> createState() => _OneExaminationViewState();
}

class _OneExaminationViewState extends State<OneExaminationView> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (BuildContext context) =>
              sl<GetOneExaminationCubit>()..getExamination(widget.id),
        ),
        BlocProvider(
            create: (BuildContext context) => sl<ExaminationActionsCubit>()),
      ],
      child: BlocBuilder<GetOneExaminationCubit, GetOneExaminationState>(
        builder: (BuildContext context, state) => Scaffold(
          appBar: AppBar(
            centerTitle: true,
            backgroundColor: Colorz.primaryColor,
            title: const Text("Examination Details"),
            actions: [
              if (state.examination != null && !state.isLoading) ...[
                IconButton(
                  onPressed: () {
                    ExaminationPdfService.generateAndPrintOneExamination(
                        state.examination!);
                  },
                  icon: const Icon(Icons.print_outlined, color: Colors.white),
                ),
                // Matches web's canDeleteExamination gate
                // (manageCapability || deleteExaminations).
                if (CapabilityServices.hasCapability(
                    CapabilityKeys.deleteExaminations))
                  IconButton(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
              ],
            ],
          ),
          body: state.isLoading || state.examination == null
              ? Center(
                  child: CircularProgressIndicator(
                  color: Colorz.primaryColor,
                ))
              : OneExaminationContent(examination: state.examination!),
        ),
      ),
    );
  }

  /// The dialog owns the whole delete — it collects the password, runs the
  /// request and shows any failure inline — and closes only once the record is
  /// gone, so the page is popped after the dialog rather than racing it.
  Future<void> _confirmDelete(BuildContext context) async {
    final actionsCubit = context.read<ExaminationActionsCubit>();
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DeleteExaminationDialog(
        onDelete: (password) =>
            actionsCubit.deleteExamination(widget.id, password: password),
      ),
    );

    if (deleted == true && context.mounted) {
      SnackbarService.showSuccess(context,
          message: "Examination deleted successfully");
      // The record no longer exists — return to the caller's list so it
      // isn't left pointing at a deleted examination.
      Get.back(result: true);
    }
  }
}

/// Delete confirmation that asks for the user's own password. Wording mirrors
/// web's confirmation (PatientDetails.tsx).
class _DeleteExaminationDialog extends StatefulWidget {
  const _DeleteExaminationDialog({required this.onDelete});

  /// Runs the delete; resolves to null on success, otherwise the error to show.
  final Future<String?> Function(String password) onDelete;

  @override
  State<_DeleteExaminationDialog> createState() =>
      _DeleteExaminationDialogState();
}

class _DeleteExaminationDialogState extends State<_DeleteExaminationDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    final error = await widget.onDelete(password);
    if (!mounted) return;

    if (error == null) {
      Navigator.pop(context, true);
      return;
    }

    final isWrongPassword = error.toLowerCase() == 'incorrect password';
    setState(() {
      _isDeleting = false;
      _error =
          isWrongPassword ? 'Incorrect password. Please try again.' : error;
      if (isWrongPassword) _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Delete examination?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              "This will soft-delete the examination and its related data from normal views."),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            enabled: !_isDeleting,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: "Enter your password to confirm",
              errorText: _error,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? "Show password" : "Hide password",
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => TextButton(
            onPressed:
                _isDeleting || value.text.isEmpty ? null : () => _submit(),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.red),
                  )
                : const Text("Delete"),
          ),
        ),
      ],
    );
  }
}
