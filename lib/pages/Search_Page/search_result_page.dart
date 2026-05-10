import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:tastie/constants/color_plate.dart';
import 'package:tastie/constants/pages.dart';
import 'package:tastie/models/card_data.dart';
import 'package:tastie/models/recipe_firestore.dart';
import 'package:tastie/pages/Search_Page/search_models.dart';
import 'package:tastie/pages/Search_Page/search_page.dart';
import 'package:tastie/pages/index_page/widgets/card_item.dart';
import 'package:tastie/pages/index_page/widgets/card_item_skeleton.dart';
import 'package:tastie/repositories/firestore_recipe_repository.dart';
import 'package:tastie/services/recipe_analytics_service.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({
    super.key,
    required this.initialCriteria,
  });

  final SearchCriteria initialCriteria;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  static const double _hotWeight = 1.4;
  static const double _freshWeight = 1.1;
  static const double _recencyHalfLifeHours = 72;
  static const double _scoreTieThreshold = 0.15;

  final FirestoreRecipeRepository _recipeRepository = FirestoreRecipeRepository();

  late SearchCriteria _criteria;
  bool _isLoading = true;
  List<_RankedRecipe> _results = <_RankedRecipe>[];

  @override
  void initState() {
    super.initState();
    _criteria = widget.initialCriteria;
    _runSearch();
  }

  Future<void> _runSearch() async {
    setState(() => _isLoading = true);

    final start = DateTime.now();
    final allRecipes = await _recipeRepository.getAll();
    final ranked = _rankRecipes(allRecipes, _criteria);

    final elapsedMs = DateTime.now().difference(start).inMilliseconds;
    if (elapsedMs < 350) {
      await Future<void>.delayed(Duration(milliseconds: 350 - elapsedMs));
    }

    if (!mounted) return;
    setState(() {
      _results = ranked;
      _isLoading = false;
    });
  }

  List<_RankedRecipe> _rankRecipes(List<RecipeFirestore> all, SearchCriteria criteria) {
    final hasTextOrFilters =
        criteria.query.trim().isNotEmpty || criteria.hasIngredientOrTagCriteria;
    final ranked = <_RankedRecipe>[];

    for (final recipe in all) {
      final calories = _extractCalories(recipe);
      final includeByCalories = shouldIncludeRecipeByCalories(
        calories: calories,
        criteria: criteria,
      );
      if (!includeByCalories) continue;

      final ingredients = recipe.ingredients
          .map((item) => (item['name'] ?? '').toString())
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);

      final score = scoreRecipe(
        criteria: criteria,
        title: recipe.title,
        content: recipe.content,
        tags: recipe.tags,
        ingredientNames: ingredients,
      );

      if (hasTextOrFilters && !score.hasAnyMatch) continue;

      ranked.add(
        _RankedRecipe(
          recipe: recipe,
          searchScore: score,
          hotScore: _calculateHotScore(recipe.likeCount),
          freshnessScore: _calculateFreshnessScore(recipe.createdAt),
        ),
      );
    }

    ranked.sort((a, b) {
      final scoreDelta = b.totalScore - a.totalScore;
      if (scoreDelta.abs() >= _scoreTieThreshold) {
        return scoreDelta > 0 ? 1 : -1;
      }

      final createdCompare = _extractCreatedAt(b.recipe.createdAt)
          .compareTo(_extractCreatedAt(a.recipe.createdAt));
      if (createdCompare != 0) return createdCompare;

      final likeCompare = b.recipe.likeCount.compareTo(a.recipe.likeCount);
      if (likeCompare != 0) return likeCompare;
      return b.recipe.favCount.compareTo(a.recipe.favCount);
    });

    return ranked;
  }

  int _extractCalories(RecipeFirestore recipe) {
    final dynamic raw = recipe.nutrition?['calories'];
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  double _calculateHotScore(int likeCount) {
    return math.log(1 + likeCount) * _hotWeight;
  }

  double _calculateFreshnessScore(dynamic createdAtRaw) {
    final createdAt = _extractCreatedAt(createdAtRaw);
    final age = DateTime.now().difference(createdAt);
    final ageHours = age.inMinutes <= 0 ? 0.0 : age.inMinutes / 60.0;
    return math.exp(-(ageHours / _recencyHalfLifeHours)) * _freshWeight;
  }

  DateTime _extractCreatedAt(dynamic createdAtRaw) {
    if (createdAtRaw is DateTime) return createdAtRaw;

    if (createdAtRaw is int) {
      return DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    }

    final dynamic candidateToDate = createdAtRaw;
    if (candidateToDate != null) {
      try {
        final converted = candidateToDate.toDate();
        if (converted is DateTime) return converted;
      } catch (_) {}
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _editSearchCriteria() async {
    final edited = await Navigator.of(context).push<SearchCriteria>(
      MaterialPageRoute<SearchCriteria>(
        builder: (_) => SearchPage(
          initialCriteria: _criteria,
          editorMode: true,
        ),
      ),
    );

    if (edited == null || edited == _criteria) return;
    _criteria = edited;
    await _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f3f3),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonGrid()
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : _buildResultGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _editSearchCriteria,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ColorPlate.disabled, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: ColorPlate.disabled),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _criteria.summaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: ColorPlate.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search),
            color: ColorPlate.primary,
            onPressed: _runSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemBuilder: (context, index) => CardItemSkeleton(
              key: ValueKey('search-skeleton-$index'),
              millisecondsDelay: (index % 6) * 120,
            ),
            childCount: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildResultGrid() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${_results.length} recipes found',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorPlate.textSecondary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemBuilder: (context, index) {
              final ranked = _results[index];
              return CardItem(
                key: ValueKey('search-result-${ranked.recipe.id}'),
                cardData: ranked.toCardData(),
                isLiked: false,
                onTap: () {
                  Get.toNamed(
                    Pages.indexDetail,
                    arguments: <String, dynamic>{
                      'id': ranked.recipe.id,
                      'recordExploreDetailOpen': true,
                      'recipeClickSource': RecipeClickSource.search,
                    },
                  );
                },
              );
            },
            childCount: _results.length,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No recipes matched your search.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting ingredients, tags, or calories.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorPlate.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ColorPlate.primary,
              ),
              onPressed: _editSearchCriteria,
              child: const Text('Edit filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankedRecipe {
  final RecipeFirestore recipe;
  final RecipeSearchScore searchScore;
  final double hotScore;
  final double freshnessScore;

  const _RankedRecipe({
    required this.recipe,
    required this.searchScore,
    required this.hotScore,
    required this.freshnessScore,
  });

  double get totalScore => searchScore.totalScore + hotScore + freshnessScore;

  CardData toCardData() {
    return CardData(
      id: recipe.id ?? '',
      uid: recipe.userId,
      cover: recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : '',
      title: recipe.title,
      content: recipe.content,
      avatar: recipe.authorAvatar,
      nickname: recipe.authorNickname,
      fav: recipe.favCount,
      like: recipe.likeCount,
      comment: recipe.commentCount,
      tags: recipe.tags,
    );
  }
}
