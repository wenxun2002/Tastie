import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/create_post_page.dart';
import 'package:tastie/pages/index_page/index_page.dart';
import 'package:tastie/pages/me_page/me_page.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
  final HomeController homeController = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        extendBody: true,
        backgroundColor: ColorPlate.background,
        body: IndexedStack(
          index: homeController.currentIndex.value,
          children: [
            const IndexPage(), // Home tab shows IndexPage
            _buildPlaceholderPage("Video"),
            _buildPlaceholderPage("Add"),
            _buildPlaceholderPage("Challenges"),
            const MePage(),
          ],
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        floatingActionButton: SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            shape: const CircleBorder(),
            backgroundColor: ColorPlate.primary,
            elevation: 0,
            onPressed: () {
              Get.to(() => const CreatePostPage());
            },
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // 0.78 * 255 ≈ 199 (0xC7)
                color: const Color(0xC7FFFFFF),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: BottomAppBar(
                elevation: 0,
                color: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shape: const CircularNotchedRectangle(),
                notchMargin: 8,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        tooltip: 'Home',
                        onPressed: () => homeController.onChangePage(0),
                        icon: Icon(
                          Icons.home,
                          color: homeController.currentIndex.value == 0
                              ? ColorPlate.primary
                              : const Color(0xff999999),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Video',
                        onPressed: () => homeController.onChangePage(1),
                        icon: Icon(
                          Icons.video_library,
                          color: homeController.currentIndex.value == 1
                              ? ColorPlate.primary
                              : const Color(0xff999999),
                        ),
                      ),
                      const SizedBox(width: 48),
                      IconButton(
                        tooltip: 'Challenges',
                        onPressed: () => homeController.onChangePage(3),
                        icon: Icon(
                          Icons.emoji_events,
                          color: homeController.currentIndex.value == 3
                              ? ColorPlate.primary
                              : const Color(0xff999999),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Me',
                        onPressed: () => homeController.onChangePage(4),
                        icon: Icon(
                          Icons.person,
                          color: homeController.currentIndex.value == 4
                              ? ColorPlate.primary
                              : const Color(0xff999999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderPage(String title) {
    return Center(
      child: Text(
        "$title Page\n(Coming Soon)",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }
}
