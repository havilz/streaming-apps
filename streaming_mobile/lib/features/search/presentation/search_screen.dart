import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/search/domain/search_provider.dart';
import 'package:streaming_mobile/shared/shared.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Debounce 500ms — tidak query setiap keystroke
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchProvider.notifier).search(value);
    });
  }

  void _onClear() {
    _controller.clear();
    ref.read(searchProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: true,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari film atau series...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon: state.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                          ),
                          onPressed: _onClear,
                        )
                      : null,
                ),
              ),
            ),

            // ── Hasil pencarian ──
            Expanded(child: _buildBody(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null) {
      return Center(
        child: AppText(
          state.error!,
          color: AppColors.textMuted,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!state.hasSearched) {
      return const Center(
        child: AppText(
          'Ketik untuk mencari film atau series',
          variant: AppTextVariant.body,
          color: AppColors.textMuted,
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: AppText(
          'Tidak ada hasil untuk "${state.query}"',
          variant: AppTextVariant.body,
          color: AppColors.textMuted,
          textAlign: TextAlign.center,
        ),
      );
    }

    final crossAxisCount = MediaQuery.sizeOf(context).width >= 600 ? 4 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2 / 3,
      ),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final item = state.results[index];
        return MovieCard(
          title: item.title,
          posterUrl: item.posterUrl ?? '',
          year: item.year,
          voteAverage: item.voteAverage,
          numberOfSeasons: item.numberOfSeasons,
          onTap: () => context.push(
            '/detail/${item.slug}',
            extra: {'isSeries': item.isSeries},
          ),
        );
      },
    );
  }
}
