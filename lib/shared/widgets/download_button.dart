import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meditator/app/theme.dart';
import 'package:meditator/core/downloads/download_manager.dart';
import 'package:meditator/shared/models/meditation.dart';

class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    required this.meditation,
    this.size = 36,
    this.iconSize = 20,
  });

  final Meditation meditation;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final dm = DownloadManager.instance;
    final notifier = dm.progressOf(meditation.id);

    return ValueListenableBuilder<DownloadProgress>(
      valueListenable: notifier,
      builder: (context, progress, _) {
        return GestureDetector(
          onTap: () => _handleTap(context, progress),
          child: SizedBox(
            width: size,
            height: size,
            child: _buildContent(context, progress),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, DownloadProgress progress) {
    final dm = DownloadManager.instance;
    switch (progress.status) {
      case DownloadStatus.idle:
      case DownloadStatus.error:
        HapticFeedback.mediumImpact();
        if (meditation.audioUrl == null || meditation.audioUrl!.isEmpty) return;
        dm.download(
          meditationId: meditation.id,
          audioUrl: meditation.audioUrl!,
          title: meditation.title,
          durationMinutes: meditation.durationMinutes,
          category: meditation.category.name,
        );
      case DownloadStatus.downloading:
        HapticFeedback.lightImpact();
        dm.cancelDownload(meditation.id);
      case DownloadStatus.completed:
        HapticFeedback.lightImpact();
        _showRemoveDialog(context);
    }
  }

  void _showRemoveDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.l, S.m, S.l, S.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Удалить загрузку?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: S.s),
              Text(
                meditation.title,
                style: Theme.of(context).textTheme.bodyMedium,
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
                        DownloadManager.instance.removeDownload(meditation.id);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(backgroundColor: C.error),
                      child: const Text('Удалить'),
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

  Widget _buildContent(BuildContext context, DownloadProgress progress) {
    switch (progress.status) {
      case DownloadStatus.idle:
        return Icon(
          Icons.download_rounded,
          size: iconSize,
          color: context.cTextSec,
        );
      case DownloadStatus.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size - 4,
              height: size - 4,
              child: CircularProgressIndicator(
                value: progress.progress > 0 ? progress.progress : null,
                strokeWidth: 2,
                color: C.primary,
              ),
            ),
            Icon(Icons.close_rounded, size: iconSize * 0.7, color: C.primary),
          ],
        );
      case DownloadStatus.completed:
        return Icon(
          Icons.download_done_rounded,
          size: iconSize,
          color: C.accent,
        );
      case DownloadStatus.error:
        return Icon(
          Icons.error_outline_rounded,
          size: iconSize,
          color: C.error,
        );
    }
  }
}
