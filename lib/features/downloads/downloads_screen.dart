import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/downloads/download_manager.dart';
import 'package:meditator/shared/widgets/custom_icons.dart';
import 'package:meditator/shared/widgets/glass_card.dart';
import 'package:meditator/shared/widgets/glow_button.dart';
import 'package:meditator/shared/widgets/gradient_bg.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dm = DownloadManager.instance;

    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(S.s, S.s, S.s, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: MIcon(MIconType.arrowBack, size: 24, color: context.cText),
                    ),
                    Expanded(
                      child: Text('Загрузки', textAlign: TextAlign.center, style: t.headlineMedium),
                    ),
                    ValueListenableBuilder(
                      valueListenable: dm.downloads,
                      builder: (_, downloads, __) => downloads.isEmpty
                          ? const SizedBox(width: 48)
                          : IconButton(
                              onPressed: () => _confirmClearAll(context),
                              tooltip: 'Удалить все',
                              icon: MIcon(MIconType.delete, size: 22, color: context.cTextSec),
                            ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: Anim.normal),

              const SizedBox(height: S.m),

              ValueListenableBuilder(
                valueListenable: dm.downloads,
                builder: (_, downloads, __) {
                  if (downloads.isEmpty) {
                    return Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(S.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, size: 64, color: context.cTextDim),
                              const SizedBox(height: S.m),
                              Text('Нет загруженных медитаций', style: t.titleMedium, textAlign: TextAlign.center),
                              const SizedBox(height: S.s),
                              Text(
                                'Загрузи медитации из библиотеки, чтобы слушать без интернета',
                                style: t.bodyMedium?.copyWith(color: context.cTextSec),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: S.l),
                              GlowButton(
                                onPressed: () => context.push('/library'),
                                width: 200,
                                child: const Text('Открыть библиотеку'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final items = downloads.values.toList()
                    ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

                  return Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: S.m),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${items.length} медитаци${_pluralSuffix(items.length)}',
                                style: t.bodyMedium?.copyWith(color: context.cTextSec),
                              ),
                              Text(
                                dm.totalSizeFormatted,
                                style: t.bodySmall?.copyWith(color: context.cTextDim),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: S.s),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(S.m, 0, S.m, 100),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: S.s),
                            itemBuilder: (_, i) {
                              final d = items[i];
                              return _DownloadedTile(downloaded: d)
                                  .animate(delay: (i * 40).ms)
                                  .fadeIn(duration: Anim.normal)
                                  .slideX(begin: 0.03);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pluralSuffix(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'й';
    if (mod10 == 1) return 'я';
    if (mod10 >= 2 && mod10 <= 4) return 'и';
    return 'й';
  }

  void _confirmClearAll(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Удалить все загрузки?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: S.s),
              Text(
                'Все скачанные медитации будут удалены с устройства',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: S.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: S.m),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        DownloadManager.instance.removeAll();
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(backgroundColor: C.error),
                      child: const Text('Удалить все'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadedTile extends StatelessWidget {
  const _DownloadedTile({required this.downloaded});
  final DownloadedMeditation downloaded;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey(downloaded.meditationId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: C.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(R.l),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: S.l),
        child: const MIcon(MIconType.delete, size: 28, color: C.error),
      ),
      onDismissed: (_) => DownloadManager.instance.removeDownload(downloaded.meditationId),
      child: GlassCard(
        showBorder: true,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/play?id=${downloaded.meditationId}');
        },
        padding: const EdgeInsets.all(S.m),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.m),
                gradient: C.gradientPrimary,
              ),
              child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: S.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    downloaded.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${downloaded.durationMinutes} мин  •  ${_formatSize(downloaded.sizeBytes)}',
                    style: t.bodySmall?.copyWith(color: context.cTextSec),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_done_rounded, size: 20, color: C.accent),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
