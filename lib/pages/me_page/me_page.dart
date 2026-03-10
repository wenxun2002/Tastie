import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/pages/index_page/widgets/card_item.dart';
import 'package:tastie/pages/index_page/widgets/card_item_skeleton.dart';
import 'package:tastie/pages/me_page/settings_screen.dart';
import 'package:tastie/repositories/firestore_index_repository.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  late final Future<List<CardData>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _cardsFuture = FirestoreIndexRepository().getAll();
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
                child: FutureBuilder<List<CardData>>(
                  future: _cardsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Skeleton grid while loading
                      return _buildSkeletonGrid(context);
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load data',
                          style: const TextStyle(
                            color: ColorPlate.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data ?? <CardData>[];
                    final myRecipe = List<CardData>.from(data);

                    final like = List<CardData>.from(data)
                      ..sort((a, b) => b.like.compareTo(a.like));

                    final collection = List<CardData>.from(data)
                      ..sort((a, b) => b.fav.compareTo(a.fav));

                    return TabBarView(
                      children: [
                        _buildRecipeGrid(context, myRecipe),
                        _buildRecipeGrid(context, like),
                        _buildRecipeGrid(context, collection),
                      ],
                    );
                  },
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
  Widget _buildRecipeGrid(BuildContext context, List<CardData> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          "No recipes yet",
          style: TextStyle(color: ColorPlate.textTertiary, fontSize: 14),
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
                onTap: () {
                  // TODO: navigate to detail or handle tap
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
