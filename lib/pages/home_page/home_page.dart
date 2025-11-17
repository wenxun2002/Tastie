import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/create_post_page.dart';
import 'package:tastie/pages/index_page/index_page.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
  final HomeController homeController = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: homeController.currentIndex.value,
          children: [
            const IndexPage(), // Home tab shows IndexPage
            _buildPlaceholderPage("Video"),
            _buildPlaceholderPage("Add"),
            _buildPlaceholderPage("Message"),
            _buildPlaceholderPage("Me"),
          ],
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            elevation: 0,
            iconSize: 24,
            backgroundColor: ColorPlate.secondary,
            selectedItemColor: ColorPlate.primary,
            unselectedItemColor: const Color(0xff999999),
            type: BottomNavigationBarType.fixed,
            currentIndex: homeController.currentIndex.value,
            unselectedFontSize: 16,
            selectedFontSize: 18,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.video_library),
                label: "Video",
              ),
              BottomNavigationBarItem(
                icon: _CreateNavButton(
                  isActive: homeController.currentIndex.value == 2,
                ),
                label: "",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.message),
                label: "Msg",
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Me",
              ),
            ],
            onTap: (index) {
              if (index == 2) {
                Get.to(() => const CreatePostPage());
                return;
              }
              homeController.onChangePage(index);
            },
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

class _CreateNavButton extends StatelessWidget {
  final bool isActive;

  const _CreateNavButton({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [ColorPlate.primary, Color(0xffF15454)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40E23E3E),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
        // border: Border.all(color: Colors.white, width: isActive ? 3 : 2),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.add, color: Colors.white, size: 26),
    );
  }
}
