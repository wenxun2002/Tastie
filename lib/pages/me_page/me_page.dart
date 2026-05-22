import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/models/card_data.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/pages/index_page/widgets/card_item.dart';
import 'package:tastie/pages/index_page/widgets/card_item_skeleton.dart';
import 'package:tastie/pages/me_page/settings_screen.dart';
import 'package:tastie/repositories/firestore_recipe_repository.dart';
import 'package:tastie/repositories/recipe_engagement_repository.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/services/recipe_analytics_service.dart';
import 'package:tastie/utils/recipe_click_weather_context.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final RecipeEngagementRepository _engagement = RecipeEngagementRepository();

  CardData _cardFromRecipe(RecipeFirestore r) {
    return CardData(
      id: r.id ?? '',
      uid: r.userId,
      cover: r.imageUrls.isNotEmpty ? r.imageUrls.first : '',
      title: r.title,
      content: r.content,
      avatar: r.authorAvatar,
      nickname: r.authorNickname,
      fav: r.favCount,
      like: r.likeCount,
      comment: r.commentCount,
      tags: r.tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ColorPlate.background,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top AppBar - "TasTie" centered, left/right reserved
              _buildTopBar(context),
              // 2. User profile section
              _buildUserProfileSection(context),
              // 3. TabBar - My Recipe, Like, Collection
              _buildTabBar(context),
              // 4. TabBarView - grid content for each tab
              Expanded(
                child: TabBarView(
                  children: [
                    Builder(
                      builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          return const Center(
                            child: Text(
                              'Please sign in to see your recipes',
                              style: TextStyle(
                                color: ColorPlate.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        return StreamBuilder<Set<String>>(
                          stream: _engagement.watchLikedRecipeIdSet(user.uid),
                          builder: (context, likedSnap) {
                            final likedIds = likedSnap.data ?? {};
                            return StreamBuilder<List<RecipeFirestore>>(
                              stream: FirestoreRecipeRepository()
                                  .watchByUserId(user.uid),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildSkeletonGrid(context);
                                }
                                if (snapshot.hasError) {
                                  // ignore: avoid_print
                                  print(
                                    'MyRecipe stream error: ${snapshot.error}',
                                  );
                                  final msg = snapshot.error.toString();
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        'Failed to load My Recipe\n\n$msg',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: ColorPlate.textTertiary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final recipes =
                                    snapshot.data ?? const <RecipeFirestore>[];
                                final myData =
                                    recipes.map(_cardFromRecipe).toList();
                                return _buildRecipeGrid(
                                  context,
                                  myData,
                                  forceLiked: false,
                                  likedIds: likedIds,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          return const Center(
                            child: Text(
                              'Please sign in to see liked recipes',
                              style: TextStyle(
                                color: ColorPlate.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        return StreamBuilder<List<RecipeFirestore>>(
                          stream: _engagement.watchLikedRecipes(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildSkeletonGrid(context);
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    'Failed to load likes\n${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ColorPlate.textTertiary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final recipes =
                                snapshot.data ?? const <RecipeFirestore>[];
                            final cards =
                                recipes.map(_cardFromRecipe).toList();
                            return _buildRecipeGrid(
                              context,
                              cards,
                              forceLiked: true,
                              emptyMessage: 'No liked recipes yet',
                            );
                          },
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          return const Center(
                            child: Text(
                              'Please sign in to see saved recipes',
                              style: TextStyle(
                                color: ColorPlate.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        return StreamBuilder<Set<String>>(
                          stream: _engagement.watchLikedRecipeIdSet(user.uid),
                          builder: (context, likedSnap) {
                            final likedIds = likedSnap.data ?? {};
                            return StreamBuilder<List<RecipeFirestore>>(
                              stream: _engagement.watchCollectedRecipes(
                                user.uid,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildSkeletonGrid(context);
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Text(
                                        'Failed to load collection\n${snapshot.error}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: ColorPlate.textTertiary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final recipes =
                                    snapshot.data ?? const <RecipeFirestore>[];
                                final cards =
                                    recipes.map(_cardFromRecipe).toList();
                                return _buildRecipeGrid(
                                  context,
                                  cards,
                                  forceLiked: false,
                                  likedIds: likedIds,
                                  emptyMessage: 'No saved recipes yet',
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left reserved space for future icon
          const SizedBox(width: 40, height: 40),
          const Expanded(
            child: Center(
              child: Text(
                "TasTie",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ColorPlate.textPrimary,
                ),
              ),
            ),
          ),
          // Right reserved space for future icon
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }

  Widget _buildUserProfileSection(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String displayName =
        (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : 'Tastie User';
    final String subtitle = user?.email != null && user!.email!.isNotEmpty
        ? user.email!
        : 'ID: ${user?.uid ?? 'Not signed in'}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: ColorPlate.secondary,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? ClipOval(
                    child: Image.asset(
                      'assets/images/LogoTransparent.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ColorPlate.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ColorPlate.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
            color: ColorPlate.textGrey,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        labelColor: ColorPlate.primary,
        unselectedLabelColor: ColorPlate.textTertiary,
        indicatorColor: ColorPlate.primary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: "My Recipe"),
          Tab(text: "Like"),
          Tab(text: "Collection"),
        ],
      ),
    );
  }

  /// Reuses same grid structure as Index Explore: SliverMasonryGrid + CardItem
  Widget _buildRecipeGrid(
    BuildContext context,
    List<CardData> data, {
    bool forceLiked = false,
    Set<String> likedIds = const {},
    String emptyMessage = 'No recipes yet',
  }) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            color: ColorPlate.textTertiary,
            fontSize: 14,
          ),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemBuilder: (context, index) {
              final post = data[index];
              return CardItem(
                key: ValueKey(post.id),
                cardData: post,
                isLiked: forceLiked || likedIds.contains(post.id),
                onTap: () async {
                  final weatherSnapshot = tryRecipeClickWeatherSnapshot();
                  final result = await Get.toNamed(
                    Pages.indexDetail,
                    arguments: <String, dynamic>{
                      'id': post.id,
                      'recordExploreDetailOpen': true,
                      'recipeClickSource': RecipeClickSource.normalBrowse,
                      if (weatherSnapshot != null && !weatherSnapshot.isEmpty)
                        'weatherSnapshot': weatherSnapshot.toArgumentsMap(),
                    },
                  );
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
            childCount: data.length,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonGrid(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemBuilder: (context, index) {
              return CardItemSkeleton(
                key: ValueKey('me-skeleton-$index'),
                millisecondsDelay: (index % 6) * 120,
              );
            },
            childCount: 8,
          ),
        ),
      ],
    );
  }
}
