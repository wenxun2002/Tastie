import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/pages/index_page/widgets/card_item.dart';
import 'package:tastie/pages/index_page/widgets/weather_banner.dart';
import 'package:tastie/pages/index_page/widgets/weather_selector.dart';
import 'index_controller.dart';

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final IndexController controller = Get.put(IndexController());

    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xfff3f3f3),
        body: Column(
          children: [
            // Header Navigation Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    "assets/images/LogoT.png",
                    width: 30,
                    height: 30,
                  ),
                  SizedBox(
                    height: 30,
                    width: 200,
                    child: TabBar(
                      labelColor: Colors.black,
                      dividerColor: Colors.transparent,
                      indicatorColor: ColorPlate.primary,
                      controller: controller.tabController,
                      tabs: const [
                        Tab(text: "Follow"),
                        Tab(text: "Explore"),
                        Tab(text: "Shop"),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.search,
                    size: 30,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              child: TabBarView(
                controller: controller.tabController,
                children: [
                  _buildFollowPage(controller),
                  _buildExplorePage(controller),
                  _buildShopPage(controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowPage(IndexController controller) {
    return const Center(
      child: Text("Follow Page\n(Coming Soon)"),
    );
  }

  Widget _buildExplorePage(IndexController controller) {
    return _ExplorePageStateful(controller: controller);
  }

  Widget _buildShopPage(IndexController controller) {
    return const Center(
      child: Text("Shop Page\n(Coming Soon)"),
    );
  }
}

/// Stable waterfall layout with pull-to-refresh + infinite scroll
class _ExplorePageStateful extends StatefulWidget {
  final IndexController controller;

  const _ExplorePageStateful({
    required this.controller,
  });

  @override
  State<_ExplorePageStateful> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePageStateful> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Detect bottom for infinite loading
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        widget.controller.loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<IndexController>(
      id: 'post_list',
      builder: (_) {
        return RefreshIndicator(
          onRefresh: widget.controller.refreshPosts, // pull to refresh
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Weather banner + selector
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    WeatherBanner(
                        weatherData: widget.controller.currentWeather),
                    const SizedBox(height: 12),
                    WeatherSelector(controller: widget.controller),
                  ],
                ),
              ),

              // Waterfall layout
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemBuilder: (context, index) {
                    final post = widget.controller.data[index];
                    return CardItem(
                      key: ValueKey(post.id),
                      cardData: post,
                      onTap: () => widget.controller.openPost(post.id),
                    );
                  },
                  childCount: widget.controller.data.length,
                ),
              ),

              // Loading indicator for infinite scroll
              SliverToBoxAdapter(
                child: widget.controller.isLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
