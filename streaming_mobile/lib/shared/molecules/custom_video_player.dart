import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/data/stream_result.dart';

class PlayerSubtitle {
  final Duration start;
  final Duration end;
  final String text;

  PlayerSubtitle({
    required this.start,
    required this.end,
    required this.text,
  });
}

class CustomVideoPlayer extends StatefulWidget {
  const CustomVideoPlayer({
    super.key,
    required this.controller,
    required this.title,
    this.subtitles,
    this.subtitleTracks,
    this.currentSubtitleTrack,
    this.onSubtitleTrackChanged,
    this.isFullScreen = false,
    required this.onBack,
  });

  final VideoPlayerController controller;
  final String title;
  final List<PlayerSubtitle>? subtitles;
  final List<SubtitleTrack>? subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final ValueChanged<SubtitleTrack>? onSubtitleTrackChanged;
  final bool isFullScreen;
  final VoidCallback onBack;

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();

  // Helper static method to parse VTT content
  static List<PlayerSubtitle> parseVtt(String vttContent) {
    final List<PlayerSubtitle> list = [];
    final lines = vttContent.replaceAll('\r\n', '\n').split('\n');

    String? timestampLine;
    final List<String> textLines = [];

    Duration parseDuration(String s) {
      final parts = s.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = int.parse(secondsParts[1].padRight(3, '0').substring(0, 3));
        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = int.parse(secondsParts[1].padRight(3, '0').substring(0, 3));
        return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }
      throw FormatException("Invalid VTT duration: $s");
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (timestampLine != null && textLines.isNotEmpty) {
          try {
            final times = timestampLine.split('-->');
            if (times.length == 2) {
              final start = parseDuration(times[0].trim());
              final end = parseDuration(times[1].trim());
              list.add(PlayerSubtitle(
                start: start,
                end: end,
                text: textLines.join('\n'),
              ));
            }
          } catch (_) {}
          timestampLine = null;
          textLines.clear();
        }
        continue;
      }

      if (trimmed.startsWith('WEBVTT') || trimmed.startsWith('NOTE')) {
        continue;
      }

      if (trimmed.contains('-->')) {
        timestampLine = trimmed;
      } else if (timestampLine != null) {
        textLines.add(trimmed);
      }
    }

    if (timestampLine != null && textLines.isNotEmpty) {
      try {
        final times = timestampLine.split('-->');
        if (times.length == 2) {
          final start = parseDuration(times[0].trim());
          final end = parseDuration(times[1].trim());
          list.add(PlayerSubtitle(
            start: start,
            end: end,
            text: textLines.join('\n'),
          ));
        }
      } catch (_) {}
    }

    return list;
  }
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  BoxFit _videoFit = BoxFit.contain;
  bool _showControls = true;
  Timer? _hideTimer;

  // Aspect ratio floating text overlay
  String? _fitLabel;
  Timer? _fitLabelTimer;

  // Subtitle toggler
  bool _subtitlesEnabled = true;

  // Double tap seeking
  String? _skipOverlayText;
  bool _isLeftSkip = true;
  Timer? _skipOverlayTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fitLabelTimer?.cancel();
    _skipOverlayTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetHideTimer() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _startHideTimer();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _cycleVideoFit() {
    _resetHideTimer();
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
        _showFitOverlay("Zoom to Fill (Cover)");
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
        _showFitOverlay("Stretch to Screen (Fill)");
      } else {
        _videoFit = BoxFit.contain;
        _showFitOverlay("Original (Contain)");
      }
    });
  }

  void _showFitOverlay(String message) {
    _fitLabelTimer?.cancel();
    setState(() {
      _fitLabel = message;
    });
    _fitLabelTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _fitLabel = null;
        });
      }
    });
  }

  void _skip(Duration offset, {required bool isLeft}) {
    final current = widget.controller.value.position;
    final target = current + offset;
    widget.controller.seekTo(target);

    _resetHideTimer();

    _skipOverlayTimer?.cancel();
    setState(() {
      _skipOverlayText = offset.isNegative ? "-10s" : "+10s";
      _isLeftSkip = isLeft;
    });

    _skipOverlayTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _skipOverlayText = null;
        });
      }
    });
  }

  void _showSubtitleSelector() {
    _resetHideTimer();
    if (widget.subtitleTracks == null || widget.subtitleTracks!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Pilih Subtitle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.subtitleTracks!.length,
                  itemBuilder: (context, index) {
                    final track = widget.subtitleTracks![index];
                    final isSelected = widget.currentSubtitleTrack?.path == track.path;

                    return ListTile(
                      title: Text(
                        track.label,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (widget.onSubtitleTrackChanged != null) {
                          widget.onSubtitleTrackChanged!(track);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PlayerSubtitle? _getActiveSubtitle(Duration position) {
    if (widget.subtitles == null) return null;
    for (final sub in widget.subtitles!) {
      if (position >= sub.start && position <= sub.end) {
        return sub;
      }
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = widget.controller.value.isInitialized;

    if (!isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video Layer with dynamic scale ──
          Positioned.fill(
            child: FittedBox(
              fit: _videoFit,
              child: SizedBox(
                width: widget.controller.value.size.width > 0
                    ? widget.controller.value.size.width
                    : 1600,
                height: widget.controller.value.size.height > 0
                    ? widget.controller.value.size.height
                    : 900,
                child: VideoPlayer(widget.controller),
              ),
            ),
          ),

          // ── Subtitle Layer ──
          Positioned(
            bottom: _showControls ? (widget.isFullScreen ? 90.0 : 70.0) : 30.0,
            left: 30,
            right: 30,
            child: IgnorePointer(
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: widget.controller,
                  builder: (context, VideoPlayerValue value, child) {
                    final activeSub = _getActiveSubtitle(value.position);
                    if (activeSub == null || !_subtitlesEnabled) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.white10, width: 0.5),
                      ),
                      child: Text(
                        activeSub.text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.isFullScreen ? 18.0 : 14.0,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Double Tap Skip Detection Areas ──
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () => _skip(const Duration(seconds: -10), isLeft: true),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () => _skip(const Duration(seconds: 10), isLeft: false),
                  ),
                ),
              ],
            ),
          ),

          // ── Double Tap Visual Skip Ripple Overlay ──
          if (_skipOverlayText != null)
            Positioned(
              left: _isLeftSkip ? MediaQuery.of(context).size.width * 0.15 : null,
              right: !_isLeftSkip ? MediaQuery.of(context).size.width * 0.15 : null,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isLeftSkip ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
                          color: Colors.white,
                          size: widget.isFullScreen ? 36 : 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _skipOverlayText!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.isFullScreen ? 16 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Netflix Aspect Ratio Toggle visual indicator ──
          if (_fitLabel != null)
            IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(30.0),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    _fitLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // ── Netflix Control Overlay (Top & Bottom Controls) ──
          if (_showControls) ...[
            // Top Bar (Only in Fullscreen mode)
            if (widget.isFullScreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Subtitles selector button
                      if (widget.subtitleTracks != null && widget.subtitleTracks!.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.subtitles_rounded,
                            color: _subtitlesEnabled ? AppColors.primary : Colors.white60,
                          ),
                          onPressed: _showSubtitleSelector,
                        ),
                    ],
                  ),
                ),
              ),

            // Center Controls (Play/Pause/Skip buttons)
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isFullScreen) ...[
                    IconButton(
                      iconSize: 48,
                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                      onPressed: () => _skip(const Duration(seconds: -10), isLeft: true),
                    ),
                    const SizedBox(width: 32),
                  ],
                  ValueListenableBuilder(
                    valueListenable: widget.controller,
                    builder: (context, VideoPlayerValue value, child) {
                      final isPlaying = value.isPlaying;
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: IconButton(
                          iconSize: widget.isFullScreen ? 64 : 44,
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              widget.controller.pause();
                              _resetHideTimer();
                            } else {
                              widget.controller.play();
                              // Quickly hide controls after pressing play
                              _hideTimer?.cancel();
                              _hideTimer = Timer(const Duration(seconds: 1), () {
                                if (mounted) {
                                  setState(() => _showControls = false);
                                }
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                  if (widget.isFullScreen) ...[
                    const SizedBox(width: 32),
                    IconButton(
                      iconSize: 48,
                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                      onPressed: () => _skip(const Duration(seconds: 10), isLeft: false),
                    ),
                  ],
                ],
              ),
            ),

            // Bottom Control Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  bottom: widget.isFullScreen ? 20.0 : 8.0,
                  top: widget.isFullScreen ? 40.0 : 16.0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timeline Slider & Duration Labels
                    ValueListenableBuilder(
                      valueListenable: widget.controller,
                      builder: (context, VideoPlayerValue value, child) {
                        final position = value.position;
                        final duration = value.duration;
                        final double maxVal = duration.inSeconds.toDouble();
                        final double currentVal = position.inSeconds.toDouble().clamp(0.0, maxVal);

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: AppColors.primary,
                                trackHeight: widget.isFullScreen ? 4.0 : 2.5,
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: widget.isFullScreen ? 6.0 : 4.0,
                                ),
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: widget.isFullScreen ? 14.0 : 8.0,
                                ),
                              ),
                              child: Slider(
                                value: currentVal,
                                max: maxVal > 0 ? maxVal : 1.0,
                                onChanged: (val) {
                                  _resetHideTimer();
                                  widget.controller.seekTo(Duration(seconds: val.toInt()));
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: widget.isFullScreen ? 13.0 : 10.0,
                                  ),
                                ),
                                Text(
                                  '-${_formatDuration(duration - position)}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: widget.isFullScreen ? 13.0 : 10.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    // Bottom Row: Settings & Buttons
                    Row(
                      children: [
                        // Subtitle Toggle
                        IconButton(
                          iconSize: widget.isFullScreen ? 24 : 18,
                          icon: Icon(
                            _subtitlesEnabled ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _resetHideTimer();
                            setState(() {
                              _subtitlesEnabled = !_subtitlesEnabled;
                            });
                          },
                        ),
                        // Subtitle Selector Sheet (only in Fullscreen)
                        if (widget.isFullScreen && widget.subtitleTracks != null && widget.subtitleTracks!.isNotEmpty)
                          IconButton(
                            iconSize: 24,
                            icon: const Icon(Icons.settings_input_component_rounded, color: Colors.white),
                            onPressed: _showSubtitleSelector,
                          ),

                        const Spacer(),

                        // Dynamic Fullscreen / Aspect Ratio toggles
                        if (widget.isFullScreen) ...[
                          // Aspect Ratio scaling changer (only in fullscreen)
                          IconButton(
                            iconSize: 24,
                            icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
                            onPressed: _cycleVideoFit,
                          ),
                          const SizedBox(width: 8),
                          // Exit Fullscreen Button
                          IconButton(
                            iconSize: 24,
                            icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                            onPressed: widget.onBack,
                          ),
                        ] else ...[
                          // Enter Fullscreen Button
                          IconButton(
                            iconSize: 18,
                            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FullScreenPlayerPage(
                                    controller: widget.controller,
                                    title: widget.title,
                                    subtitles: widget.subtitles,
                                    subtitleTracks: widget.subtitleTracks,
                                    currentSubtitleTrack: widget.currentSubtitleTrack,
                                    onSubtitleTrackChanged: widget.onSubtitleTrackChanged,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Netflix Thin Progress Line (when controls are hidden) ──
          if (!_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                valueListenable: widget.controller,
                builder: (context, VideoPlayerValue value, child) {
                  final duration = value.duration;
                  final position = value.position;
                  double percent = 0.0;
                  if (duration.inMilliseconds > 0) {
                    percent = position.inMilliseconds / duration.inMilliseconds;
                  }
                  return Container(
                    height: 2.5,
                    alignment: Alignment.centerLeft,
                    color: Colors.white10,
                    child: FractionallySizedBox(
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(color: AppColors.primary),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Fullscreen Video Player Route Page ──
class FullScreenPlayerPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final List<PlayerSubtitle>? subtitles;
  final List<SubtitleTrack>? subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final ValueChanged<SubtitleTrack>? onSubtitleTrackChanged;

  const FullScreenPlayerPage({
    super.key,
    required this.controller,
    required this.title,
    this.subtitles,
    this.subtitleTracks,
    this.currentSubtitleTrack,
    this.onSubtitleTrackChanged,
  });

  @override
  State<FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<FullScreenPlayerPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomVideoPlayer(
        controller: widget.controller,
        title: widget.title,
        subtitles: widget.subtitles,
        subtitleTracks: widget.subtitleTracks,
        currentSubtitleTrack: widget.currentSubtitleTrack,
        onSubtitleTrackChanged: widget.onSubtitleTrackChanged,
        isFullScreen: true,
        onBack: () => Navigator.pop(context),
      ),
    );
  }
}
