import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/search/domain/search_provider.dart';
import 'package:streaming_mobile/shared/shared.dart';

class SearchModal extends ConsumerStatefulWidget {
  const SearchModal({super.key});

  @override
  ConsumerState<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends ConsumerState<SearchModal> {
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // BackdropFilter for the premium glass blur effect
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                ref.read(searchProvider.notifier).clear();
                Navigator.of(context).pop();
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),

          // Search Content
          SafeArea(
            child: Column(
              children: [
                // Top controls (Close / Search Field)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () {
                          ref.read(searchProvider.notifier).clear();
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
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
                    ],
                  ),
                ),

                // Search Results
                Expanded(
                  child: GestureDetector(
                    onTap: () {}, // prevent tap from closing dialog
                    child: _buildBody(context, state),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppText(
            state.error!,
            color: AppColors.textMuted,
            textAlign: TextAlign.center,
          ),
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
          onTap: () {
            // Close modal first
            ref.read(searchProvider.notifier).clear();
            Navigator.of(context).pop();
            // Then navigate to details
            context.push(
              '/detail/${item.slug}',
              extra: {'isSeries': item.isSeries},
            );
          },
        );
      },
    );
  }
}

void showSearchModal(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search',
    barrierColor: Colors.black12,
    pageBuilder: (context, anim1, anim2) {
      return const SearchModal();
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: child,
      );
    },
  );
}
