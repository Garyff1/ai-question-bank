import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai_guard/ai_request_guard.dart';

class ApiUsageRecordsPage extends StatefulWidget {
  const ApiUsageRecordsPage({super.key});

  @override
  State<ApiUsageRecordsPage> createState() => _ApiUsageRecordsPageState();
}

class _ApiUsageRecordsPageState extends State<ApiUsageRecordsPage> {
  final _guard = AiRequestGuard.instance;
  late Future<List<AiUsageRecord>> _records = _guard.loadRecords();
  AiGuardPreferences _preferences = const AiGuardPreferences();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final value = await _guard.loadPreferences();
    if (mounted) setState(() => _preferences = value);
  }

  Future<void> _save(AiGuardPreferences value) async {
    setState(() => _preferences = value);
    await _guard.savePreferences(value);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空 API 使用记录？'),
        content: const Text('只会删除本机脱敏记录，不会删除 API Key、资料或题目。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _guard.clearRecords();
    if (mounted) setState(() => _records = _guard.loadRecords());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 使用保护'),
        actions: [
          IconButton(
            tooltip: '清空本地记录',
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Cost Guard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '阻止重复请求、限制自动重试，并在本机记录脱敏的调用凭证。记录不包含 API Key、完整资料或完整 Prompt。',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (_guard.circuitOpen) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        _guard.resumeAfterCircuitBreak();
                        setState(() {});
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('检查后恢复 AI 调用'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('自动重试'),
                  subtitle: const Text('仅临时网络错误，最多自动重试 1 次'),
                  value: _preferences.autoRetry,
                  onChanged: (value) =>
                      _save(_preferences.copyWith(autoRetry: value)),
                ),
                SwitchListTile(
                  title: const Text('大任务提醒'),
                  subtitle: const Text('题量或资料较大时，生成前提醒可能消耗更多额度'),
                  value: _preferences.largeTaskWarning,
                  onChanged: (value) =>
                      _save(_preferences.copyWith(largeTaskWarning: value)),
                ),
                SwitchListTile(
                  title: const Text('普通 AI 操作确认'),
                  subtitle: const Text('首次重新生成等操作前提示会产生新的 API 调用'),
                  value: _preferences.confirmRegularAi,
                  onChanged: (value) =>
                      _save(_preferences.copyWith(confirmRegularAi: value)),
                ),
                SwitchListTile(
                  title: const Text('显示本地使用记录'),
                  subtitle: const Text('关闭后停止在此页面展示；模型商账单仍以其控制台为准'),
                  value: _preferences.showUsageRecords,
                  onChanged: (value) =>
                      _save(_preferences.copyWith(showUsageRecords: value)),
                ),
                ListTile(
                  title: const Text('每日任务提醒阈值'),
                  subtitle: const Text('达到阈值后每天提醒一次，不会强制限制使用'),
                  trailing: DropdownButton<int>(
                    value: _preferences.dailyReminderThreshold,
                    items: const [10, 20, 40, 80]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value 次'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _save(
                          _preferences.copyWith(dailyReminderThreshold: value),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '本机任务记录',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (!_preferences.showUsageRecords)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('本地使用记录展示已关闭。'),
              ),
            )
          else
            FutureBuilder<List<AiUsageRecord>>(
              future: _records,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data ?? const [];
                if (records.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('还没有 AI 调用记录。'),
                    ),
                  );
                }
                return Column(
                  children: records
                      .map((record) => _recordCard(record))
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 12),
          Text(
            '本记录仅表示 AI题库 发起的请求，不代表模型服务商最终账单。最终费用请以服务商控制台为准。',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(AiUsageRecord record) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = switch (record.status) {
      AiTaskStatus.success => scheme.tertiary,
      AiTaskStatus.cancelled => scheme.onSurfaceVariant,
      AiTaskStatus.failed => scheme.error,
      AiTaskStatus.blocked => scheme.error,
    };
    final shortId = record.taskId.length > 12
        ? '${record.taskId.substring(0, 4)}••••${record.taskId.substring(record.taskId.length - 4)}'
        : record.taskId;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: .12),
          child: Icon(Icons.bolt_rounded, color: statusColor),
        ),
        title: Text('${record.taskType} · ${record.provider}'),
        subtitle: Text(
          '${record.model}\n请求 ${record.requestCount} 次 · 自动重试 ${record.retryCount} 次'
          '${record.inputTokens == null ? '\nToken 数据不可用' : '\nToken 输入 ${record.inputTokens} / 输出 ${record.outputTokens ?? 0}'}\n任务 $shortId',
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: '复制脱敏任务记录',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            final report = [
              'App: AI题库',
              'Task: ${record.taskId}',
              'Type: ${record.taskType}',
              'Provider: ${record.provider}',
              'Model: ${record.model}',
              'Requests: ${record.requestCount}',
              'Retries: ${record.retryCount}',
              'Status: ${record.status.name}',
              'Error: ${record.errorCategory ?? 'none'}',
              'DO NOT POST API KEYS.',
            ].join('\n');
            await Clipboard.setData(ClipboardData(text: report));
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制脱敏任务记录')));
            }
          },
        ),
      ),
    );
  }
}
