import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:han_music/app/core/utils/formatters.dart';
import 'package:han_music/app/services/timer_service.dart';

/// 睡眠定时面板：预设时长 / 自定义 / 播完当前歌曲后停止；活跃任务可顺延与取消。
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends StatefulWidget {
  const _SleepTimerSheet();

  @override
  State<_SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<_SleepTimerSheet> {
  final _customMinutesController = TextEditingController();

  @override
  void dispose() {
    _customMinutesController.dispose();
    super.dispose();
  }

  void _startMinutes(int minutes) {
    Get.find<TimerService>().startMinutes(minutes);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final timer = Get.find<TimerService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Obx(() {
        final active = timer.active;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('睡眠定时', style: Theme.of(context).textTheme.titleSmall),
              if (active) ...[
                const SizedBox(height: 12),
                _ActiveTaskRow(timer: timer),
                const Divider(height: 24),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in TimerService.presetMinutes)
                    ActionChip(
                      label: Text('$minutes 分钟'),
                      onPressed: () => _startMinutes(minutes),
                    ),
                  ActionChip(
                    label: const Text('播完当前歌曲'),
                    onPressed: () {
                      timer.startStopAfterCurrent();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '自定义（分钟）',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _submitCustomMinutes,
                    child: const Text('启动'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '到点后自动暂停播放；应用被系统结束后定时将失效。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _submitCustomMinutes() {
    final minutes = int.tryParse(_customMinutesController.text.trim());
    if (minutes == null || minutes <= 0) {
      Get.snackbar('无法启动', '请输入有效的分钟数');
      return;
    }
    _startMinutes(minutes);
  }
}

class _ActiveTaskRow extends StatelessWidget {
  const _ActiveTaskRow({required this.timer});

  final TimerService timer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.timer,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            timer.stopAfterCurrent.value
                ? '播完当前歌曲后停止'
                : '剩余 ${formatDuration(timer.remaining.value)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        TextButton(
          onPressed: timer.extendTenMinutes,
          child: const Text('顺延 10 分钟'),
        ),
        TextButton(
          onPressed: timer.cancel,
          child: const Text('取消'),
        ),
      ],
    );
  }
}
