import 'package:get/get.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/pages/auth/auth_gate_page.dart';
import 'package:tastie/pages/auth/login_page.dart';
import 'package:tastie/pages/home_page/home_page.dart';
import 'package:tastie/pages/index_page/index_detail_page/index_detail_page.dart';
import 'package:tastie/pages/report/report_reason_page.dart';
import 'package:tastie/pages/report/report_submission_page.dart';

class Routes {
  static final List<GetPage> getPages = [
    GetPage(name: Pages.init, page: () => const AuthGatePage()),
    GetPage(name: Pages.home, page: () => HomePage()),
    GetPage(name: Pages.login, page: () => const LoginPage()),
    GetPage(name: Pages.indexDetail, page: () => const IndexDetailPage()),
    GetPage(name: Pages.reportReason, page: () => const ReportReasonPage()),
    GetPage(name: Pages.reportSubmission, page: () => const ReportSubmissionPage()),
  ];
}
