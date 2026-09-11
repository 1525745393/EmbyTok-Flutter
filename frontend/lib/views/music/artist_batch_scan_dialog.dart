// 批量元数据扫描进度对话框（V1.2）
//
// 显示扫描进度、当前歌手名、成功/失败/跳过统计。
// 扫描完成后显示结果摘要，支持查看失败列表。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/artist_metadata_provider.dart';
import '../../services/artist_metadata_service.dart';

/// 批量扫描进度对话框
///
/// 使用方式：
/// ```dart
/// final result = await showDialog<BatchScanResult>(
///   context: context,
///   barrierDismissible: false,
///   builder: (context) => ArtistBatchScanDialog(
///     artistNames: artistNames,
///   ),
/// );
/// ```
class ArtistBatchScanDialog extends ConsumerStatefulWidget {
  /// 歌手名称列表
  final List<String> artistNames;

  /// 是否跳过已有完整元数据的歌手
  final bool skipExisting;

  /// 并发数
  final int concurrency;

  const ArtistBatchScanDialog({
    super.key,
    required this.artistNames,
    this.skipExisting = true,
    this.concurrency = 3,
  });

  @override
  ConsumerState<ArtistBatchScanDialog> createState() => _ArtistBatchScanDialogState();
}

class _ArtistBatchScanDialogState extends ConsumerState<ArtistBatchScanDialog> {
  /// 当前进度（已处理数量）
  int _current = 0;

  /// 总数
  int _total = 0;

  /// 当前正在处理的歌手名
  String _currentArtist = '';

  /// 成功数量
  int _success = 0;

  /// 失败数量
  int _failed = 0;

  /// 跳过数量
  int _skipped = 0;

  /// 是否完成
  bool _isCompleted = false;

  /// 扫描结果
  BatchScanResult? _result;

  /// 是否显示失败列表
  bool _showFailedList = false;

  @override
  void initState() {
    super.initState();
    _total = widget.artistNames.length;
    _startScan();
  }

  /// 开始扫描
  Future<void> _startScan() async {
    final service = ref.read(artistMetadataServiceProvider);

    try {
      final result = await service.batchScanArtists(
        artistNames: widget.artistNames,
        skipExisting: widget.skipExisting,
        concurrency: widget.concurrency,
        onProgress: (current, total, artistName) {
          if (mounted) {
            setState(() {
              _current = current;
              _total = total;
              _currentArtist = artistName;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isCompleted = true;
          _result = result;
          _success = result.success;
          _failed = result.failed;
          _skipped = result.skipped;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompleted = true;
          _result = BatchScanResult(
            total: _total,
            unique: _total,
            success: _success,
            failed: _total - _success - _skipped,
            skipped: _skipped,
            failedArtists: [],
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _total == 0 ? 0.0 : _current / _total;

    return AlertDialog(
      title: Text(_isCompleted ? '扫描完成' : '批量扫描歌手元数据'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度条
          LinearProgressIndicator(value: _isCompleted ? 1.0 : progress),
          const SizedBox(height: 12),
          // 进度文本
          Text(
            _isCompleted
                ? '已完成 $_current / $_total'
                : '正在扫描 $_current / $_total...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // 当前歌手
          if (!_isCompleted && _currentArtist.isNotEmpty)
            Text(
              '当前：$_currentArtist',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 16),
          // 统计信息
          _buildStats(scheme),
          // 失败列表（可展开）
          if (_isCompleted && _result != null && _result!.failedArtists.isNotEmpty)
            _buildFailedList(scheme),
        ],
      ),
      actions: [
        if (_isCompleted)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: const Text('关闭'),
          ),
      ],
    );
  }

  /// 构建统计信息
  Widget _buildStats(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem('成功', _success, Colors.green, scheme),
        _buildStatItem('失败', _failed, Colors.red, scheme),
        _buildStatItem('跳过', _skipped, Colors.grey, scheme),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, int value, Color color, ColorScheme scheme) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 构建失败列表
  Widget _buildFailedList(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _showFailedList = !_showFailedList),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showFailedList ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '查看失败列表（${_result!.failedArtists.length}）',
                style: TextStyle(color: scheme.primary, fontSize: 13),
              ),
            ],
          ),
        ),
        if (_showFailedList)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _result!.failedArtists.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${_result!.failedArtists[index]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
