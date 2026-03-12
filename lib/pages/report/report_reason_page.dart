import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/constants/report_reasons.dart';

/// Page 1: User selects a report reason from a list, then navigates to submission page.
class ReportReasonPage extends StatelessWidget {
  const ReportReasonPage({super.key});

  static const String _argRecipeId = 'recipeId';
  static const String _argRecipeTitle = 'recipeTitle';
  static const String _argAuthorUsername = 'authorUsername';
  static const String _argCreatedAt = 'createdAt';

  /// Expected arguments: recipeId, recipeTitle, authorUsername, createdAt (dynamic).
  static Map<String, dynamic> getReportArguments({
    required String recipeId,
    required String recipeTitle,
    required String authorUsername,
    required dynamic createdAt,
  }) {
    return {
      _argRecipeId: recipeId,
      _argRecipeTitle: recipeTitle,
      _argAuthorUsername: authorUsername,
      _argCreatedAt: createdAt,
    };
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null ||
        args[_argRecipeId] == null ||
        args[_argRecipeTitle] == null ||
        args[_argAuthorUsername] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Recipe')),
        body: const Center(child: Text('Missing recipe data.')),
      );
    }

    return Scaffold(
      backgroundColor: ColorPlate.backgroundWhite,
      appBar: AppBar(
        title: Text('Report Recipe', style: ColorPlate.heading2),
        backgroundColor: ColorPlate.backgroundWhite,
        foregroundColor: ColorPlate.textPrimary,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: ReportReasons.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final reason = ReportReasons.values[index];
          return Material(
            color: ColorPlate.backgroundWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: ColorPlate.borderGrey.withOpacity(0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Get.toNamed(
                  Pages.reportSubmission,
                  arguments: <String, dynamic>{
                    ...args,
                    'reason': reason,
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    const Icon(
                      Icons.chevron_right,
                      color: ColorPlate.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
