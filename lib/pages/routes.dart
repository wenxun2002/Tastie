import 'package:tastie/constants/pages.dart';
import 'package:tastie/pages/home_page/home_page.dart';
import 'package:tastie/pages/index_page/index_detail_page/index_detail_page.dart';
import 'package:get/get.dart';

class Routes {
  static final List<GetPage> getPages = [
    GetPage(name: Pages.home, page: () => HomePage()),
    GetPage(name: Pages.indexDetail, page: () => const IndexDetailPage()),
  ];
}
