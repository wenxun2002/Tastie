import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import 'package:tastie/constants/color_plate.dart';
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.video_library),
                label: "Video",
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.add_box,
                  size: 32, 
                  color: ColorPlate.primary
                ),
                label: "",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.message),
                label: "Msg",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Me",
              ),
            ],
            onTap: (index) {
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
        style: const TextStyle(
          fontSize: 18,
          color: Colors.grey,
        ),
      ),
    );
  }
}

