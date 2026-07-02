import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/shared/molecules/episode_tile.dart';

/// Daftar episode lengkap untuk halaman detail series.
class EpisodeList extends StatelessWidget {
  const EpisodeList({
    super.key,
    required this.episodes,
    this.activeEpisodeId,
    this.onEpisodeTap,
  });

  final List<
    ({
      int episodeNumber,
      String title,
      String? stillUrl,
      String? airDate,
      String episodeId,
    })
  >
  episodes;

  final String? activeEpisodeId;
  final void Function(String episodeId)? onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: episodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final ep = episodes[index];
        return EpisodeTile(
          episodeNumber: ep.episodeNumber,
          title: ep.title,
          stillUrl: ep.stillUrl,
          airDate: ep.airDate,
          isActive: ep.episodeId == activeEpisodeId,
          onTap: () => onEpisodeTap?.call(ep.episodeId),
        );
      },
    );
  }
}
