import 'package:get/get.dart';

class HomeController extends GetxController {
  RxInt currentIndex = 0.obs;

  void onChangePage(int index) {
    if (index == 2) {
      // 中间按钮暂时不处理
      return;
    }
    currentIndex.value = index;
  }
}

