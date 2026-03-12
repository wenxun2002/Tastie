import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/constants/report_reasons.dart';
import 'package:tastie/pages/auth/auth_controller.dart';
import 'package:tastie/services/report_recipe_service.dart';

/// Page 2: Shows recipe info, editable reason, description field; submits to Firestore.
class ReportSubmissionPage extends StatefulWidget {
  const ReportSubmissionPage({super.key});

  @override
  State<ReportSubmissionPage> createState() => _ReportSubmissionPageState();
}

class _ReportSubmissionPageState extends State<ReportSubmissionPage> {
  static const String _argRecipeId = 'recipeId';
  static const String _argRecipeTitle = 'recipeTitle';
  static const String _argAuthorUsername = 'authorUsername';
  static const String _argCreatedAt = 'createdAt';
  static const String _argReason = 'reason';

  late String _recipeId;
  late String _recipeTitle;
  late String _authorUsername;
  String _recipePostTime = '';
  late String _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  final ReportRecipeService _reportService = ReportRecipeService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _recipeId = args[_argRecipeId] as String? ?? '';
    _recipeTitle = args[_argRecipeTitle] as String? ?? '';
    _authorUsername = args[_argAuthorUsername] as String? ?? '';
    _selectedReason = args[_argReason] as String? ?? ReportReasons.values.first;
    _recipePostTime = _formatRecipePostTime(args[_argCreatedAt]);
  }

  static String _formatRecipePostTime(dynamic createdAt) {
    if (createdAt == null) return '—';
    DateTime date;
    if (createdAt is Timestamp) {
      date = createdAt.toDate();
    } else if (createdAt is int) {
      date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else {
      return '—';
    }
    return DateFormat.yMMMd().add_Hm().format(date);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    final auth = Get.find<AuthController>();
    final User? user = auth.currentUser.value;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to report.')),
        );
      }
      return;
    }
    final reportedBy = user.uid;
    setState(() => _isSubmitting = true);
    try {
      await _reportService.submitReport(
        recipeId: _recipeId,
        recipeTitle: _recipeTitle,
        authorUsername: _authorUsername,
        reportedBy: reportedBy,
        reason: _selectedReason,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
      Get.back();
      Get.back();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReasonSelector() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: ColorPlate.backgroundWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorPlate.borderGrey.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Select reason', style: ColorPlate.heading2),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: ColorPlate.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: ReportReasons.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final reason = ReportReasons.values[index];
                      return Material(
                        color: ColorPlate.backgroundWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: ColorPlate.borderGrey.withOpacity(0.5),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedReason = reason);
                            Navigator.pop(ctx);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: ColorPlate.bodyText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (reason == _selectedReason)
                                  const Icon(Icons.check, color: ColorPlate.primary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorPlate.backgroundWhite,
      appBar: AppBar(
        title: Text('Submit Report', style: ColorPlate.heading2),
        backgroundColor: ColorPlate.backgroundWhite,
        foregroundColor: ColorPlate.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRecipeInfoSection(),
            const SizedBox(height: 24),
            Text('Reason', style: ColorPlate.heading3),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showReasonSelector,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: ColorPlate.borderGrey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedReason, style: ColorPlate.bodyText),
                    const Icon(Icons.arrow_drop_down, color: ColorPlate.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Additional details (optional)', style: ColorPlate.heading3),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe why you are reporting this recipe...',
                hintStyle: ColorPlate.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ColorPlate.borderGrey),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: ColorPlate.bodyText,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSubmitting ? null : _onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: ColorPlate.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : () => Get.back(),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorPlate.textPrimary,
                side: BorderSide(color: ColorPlate.borderGrey),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorPlate.background.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorPlate.borderGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recipe being reported', style: ColorPlate.caption),
          const SizedBox(height: 8),
          Text(_recipeTitle, style: ColorPlate.heading2),
          const SizedBox(height: 6),
          Text('Author: $_authorUsername', style: ColorPlate.bodyText),
          const SizedBox(height: 4),
          Text('Posted: $_recipePostTime', style: ColorPlate.caption),
        ],
      ),
    );
  }
}
