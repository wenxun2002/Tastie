import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/pages/index_page/widgets/card_item.dart';
import 'package:tastie/pages/index_page/widgets/card_item_skeleton.dart';
import 'package:tastie/pages/index_page/widgets/weather_banner.dart';
import 'package:tastie/pages/index_page/widgets/weather_selector.dart';
import 'package:tastie/pages/Search_Page/search_page.dart';
import 'package:tastie/services/recipe_analytics_service.dart';
import 'package:tastie/utils/recipe_weather_promoted_match.dart';
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
                    "assets/images/LogoTransparent.png",
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
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      size: 30,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      Get.to(() => const SearchPage());
                    },
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
    return const Center(child: Text("Follow Page\n(Coming Soon)"));
  }

  Widget _buildExplorePage(IndexController controller) {
    return _ExplorePageStateful(controller: controller);
  }

  Widget _buildShopPage(IndexController controller) {
    return const Center(child: Text("Shop Page\n(Coming Soon)"));
  }
}

/// Stable waterfall layout with pull-to-refresh + infinite scroll
class _ExplorePageStateful extends StatefulWidget {
  final IndexController controller;

  const _ExplorePageStateful({required this.controller});

  @override
  State<_ExplorePageStateful> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePageStateful> {
  final ScrollController _scrollController = ScrollController();
  bool _isPrecaching = false;
  // Keep skeleton until the first screen images are ready on every refresh.

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
        // After data is fetched, pre-cache first-screen images; keep skeleton until done.
        if (widget.controller.isInitialLoading &&
            widget.controller.isDataReady &&
            !_isPrecaching) {
          _isPrecaching = true;
          _precacheExploreImages(context).whenComplete(() {
            if (!mounted) return;
            _isPrecaching = false;
            widget.controller.finalizeInitialLoad();
          });
        }

        return RefreshIndicator(
          onRefresh: widget.controller.refreshPosts, // pull to refresh
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Weather banner + selector
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    WeatherBanner(
                      weatherData: widget.controller.currentWeather,
                      locationName: widget.controller.currentLocationName,
                    ),
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
                    if (widget.controller.isInitialLoading) {
                      return CardItemSkeleton(
                        key: ValueKey('skeleton-$index'),
                        millisecondsDelay: (index % 6) * 120,
                      );
                    }

                    final post = widget.controller.data[index];
                    return CardItem(
                      key: ValueKey(post.id),
                      cardData: post,
                      isLiked: widget.controller.isRecipeLiked(post.id),
                      onTap: () async {
                        final RecipeClickSource exploreClickSource =
                            recipeTagsIntersectPromotedTags(
                              post.tags,
                              widget.controller.exploreFilterPromotedTags,
                            )
                            ? RecipeClickSource.weatherPromoted
                            : RecipeClickSource.weatherNotPromoted;
                        final weatherSnapshot =
                            widget.controller.buildClickWeatherSnapshot();
                        final result = await Get.toNamed(
                          Pages.indexDetail,
                          arguments: <String, dynamic>{
                            'id': post.id,
                            'recordExploreDetailOpen': true,
                            'recipeClickSource': exploreClickSource,
                            if (weatherSnapshot != null &&
                                !weatherSnapshot.isEmpty)
                              'weatherSnapshot':
                                  weatherSnapshot.toArgumentsMap(),
                          },
                        );
                        await widget.controller.reloadLikedRecipeIds();
                        if (!context.mounted) return;
                        if (result == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recipe deleted successfully.'),
                            ),
                          );
                        }
                      },
                    );
                  },
                  childCount: widget.controller.isInitialLoading
                      ? 8
                      : widget.controller.data.length,
                ),
              ),

              // Infinite scroll: loading / end of feed
              SliverToBoxAdapter(
                child: _buildPaginationFooter(context, widget.controller),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _precacheExploreImages(BuildContext context) async {
    // Pre-cache a reasonable number of images for the first screen.
    // 优化：只预加载封面图，且最多 6 条，避免首屏等待过久。
    final posts = widget.controller.data;
    final int limit = posts.length < 6 ? posts.length : 6;
    final futures = <Future<void>>[];

    for (int i = 0; i < limit; i++) {
      final p = posts[i];
      futures.add(_precacheAnyImage(context, p.cover));
    }

    try {
      await Future.wait(futures);
    } catch (_) {
      // 忽略单张图片预加载失败，避免阻塞 skeleton。
    }
  }

  Widget _buildPaginationFooter(BuildContext context, IndexController c) {
    if (c.isInitialLoading) return const SizedBox.shrink();

    if (c.isFetchingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!c.hasMore && c.data.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No more posts',
            style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _precacheAnyImage(BuildContext context, String url) async {
    final ImageProvider provider;
    final isNetwork =
        url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('//');
    provider = isNetwork ? NetworkImage(url) : AssetImage(url);
    await precacheImage(provider, context);
  }
}
