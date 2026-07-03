import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/shared/atoms/atoms.dart';
import 'package:streaming_mobile/shared/molecules/movie_card.dart';

/// Grid konten film/series 2 kolom (mobile) atau 3 kolom (tablet).
class ContentGrid extends StatelessWidget {
  const ContentGrid({
    super.key,
    required this.items,
    this.isLoading = false,
    this.onItemTap,
  });

  final List<({
    String title,
    String posterUrl,
    String slug,
    String? year,
    double? voteAverage,
    int? numberOfSeasons,
  })> items;
  final bool isLoading;
  final void Function(String slug)? onItemTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 600 ? 3 : 2;

    if (isLoading) {
      return _ShimmerGrid(crossAxisCount: crossAxisCount);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2 / 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return MovieCard(
          title: item.title,
          posterUrl: item.posterUrl,
          year: item.year,
          voteAverage: item.voteAverage,
          numberOfSeasons: item.numberOfSeasons,
          onTap: () => onItemTap?.call(item.slug),
        );
      },
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid({required this.crossAxisCount});
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2 / 3,
      ),
      itemCount: 10,
      itemBuilder: (_, __) =>
          const AppShimmer(width: double.infinity, height: double.infinity),
    );
  }
}
