class ToolCallItem {
  final String id;
  final String type; // 'bash' | 'edit' | 'search' | 'read'
  final String title;
  final String detail;
  final String? filePath;
  final int addedLines;
  final int removedLines;
  final String statusText;
  final List<String> shellTail;
  final String? diffPreview;
  final String status; // 'done' | 'running' | 'pending'

  const ToolCallItem({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    this.filePath,
    this.addedLines = 0,
    this.removedLines = 0,
    this.statusText = '',
    this.shellTail = const [],
    this.diffPreview,
    this.status = 'done',
  });

  ToolCallItem copyWith({
    String? status,
    String? statusText,
    List<String>? shellTail,
  }) {
    return ToolCallItem(
      id: id,
      type: type,
      title: title,
      detail: detail,
      filePath: filePath,
      addedLines: addedLines,
      removedLines: removedLines,
      statusText: statusText ?? this.statusText,
      shellTail: shellTail ?? this.shellTail,
      diffPreview: diffPreview,
      status: status ?? this.status,
    );
  }

  factory ToolCallItem.fromJson(Map<String, dynamic> json) {
    final rawTail = (json['shellTail'] as List?) ?? const [];
    return ToolCallItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'bash').toString(),
      title: (json['title'] ?? 'Tool Execution').toString(),
      detail: (json['detail'] ?? '').toString(),
      filePath: json['filePath']?.toString(),
      addedLines: int.tryParse((json['addedLines'] ?? 0).toString()) ?? 0,
      removedLines: int.tryParse((json['removedLines'] ?? 0).toString()) ?? 0,
      statusText: (json['statusText'] ?? '').toString(),
      shellTail: rawTail.map((e) => e.toString()).toList(),
      diffPreview: json['diffPreview']?.toString(),
      status: (json['status'] ?? 'done').toString(),
    );
  }
}

class AgentChatTurn {
  final String id;
  final bool isUser;
  final String modelName;
  final String timestamp;
  final String thinking;
  final String thinkingDuration;
  final bool thinkingActive;
  final String content;
  final String? translatedContent;
  final List<ToolCallItem> toolCalls;
  final List<String> codeBlocks;
  final String tokenStats;
  final int branchIndex;
  final int branchTotal;

  const AgentChatTurn({
    required this.id,
    required this.isUser,
    this.modelName = 'Gemini 4 Argon',
    this.timestamp = '刚刚',
    this.thinking = '',
    this.thinkingDuration = '2.8s',
    this.thinkingActive = false,
    required this.content,
    this.translatedContent,
    this.toolCalls = const [],
    this.codeBlocks = const [],
    this.tokenStats = '1,420 tok · 52.4 t/s',
    this.branchIndex = 1,
    this.branchTotal = 1,
  });

  AgentChatTurn copyWith({
    String? content,
    String? translatedContent,
    bool? thinkingActive,
    List<ToolCallItem>? toolCalls,
    int? branchIndex,
    int? branchTotal,
  }) {
    return AgentChatTurn(
      id: id,
      isUser: isUser,
      modelName: modelName,
      timestamp: timestamp,
      thinking: thinking,
      thinkingDuration: thinkingDuration,
      thinkingActive: thinkingActive ?? this.thinkingActive,
      content: content ?? this.content,
      translatedContent: translatedContent ?? this.translatedContent,
      toolCalls: toolCalls ?? this.toolCalls,
      codeBlocks: codeBlocks,
      tokenStats: tokenStats,
      branchIndex: branchIndex ?? this.branchIndex,
      branchTotal: branchTotal ?? this.branchTotal,
    );
  }

  factory AgentChatTurn.fromJson(Map<String, dynamic> json) {
    final rawTools = (json['toolCalls'] as List?) ?? const [];
    final rawCodes = (json['codeBlocks'] as List?) ?? const [];
    return AgentChatTurn(
      id: (json['id'] ?? '').toString(),
      isUser: json['role'] == 'user',
      modelName: (json['modelName'] ?? 'Gemini 4 Argon').toString(),
      timestamp: (json['timestamp'] ?? '刚刚').toString(),
      thinking: (json['thinking'] ?? '').toString(),
      thinkingDuration: (json['thinkingDuration'] ?? '2.8s').toString(),
      thinkingActive: json['thinkingActive'] == true,
      content: (json['content'] ?? '').toString(),
      toolCalls: rawTools
          .whereType<Map<String, dynamic>>()
          .map(ToolCallItem.fromJson)
          .toList(),
      codeBlocks: rawCodes.map((e) => e.toString()).toList(),
      tokenStats: (json['tokenStats'] ?? '1,420 tok · 52.4 t/s').toString(),
    );
  }
}

class PendingApprovalRequest {
  final bool pending;
  final String commandOrFile;
  final String summary;
  final String approveLabel;
  final String denyLabel;

  const PendingApprovalRequest({
    this.pending = false,
    this.commandOrFile = '',
    this.summary = '',
    this.approveLabel = '允许执行',
    this.denyLabel = '拒绝',
  });

  factory PendingApprovalRequest.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['pending'] != true) {
      return const PendingApprovalRequest(pending: false);
    }
    return PendingApprovalRequest(
      pending: true,
      commandOrFile: (json['commandOrFile'] ?? 'Tool Action').toString(),
      summary: (json['summary'] ?? '').toString(),
      approveLabel: (json['approveLabel'] ?? '允许执行').toString(),
      denyLabel: (json['denyLabel'] ?? '拒绝').toString(),
    );
  }
}

class RemoteSessionInfo {
  final String id;
  final String title;
  final String repo;
  final String branch;
  final String status; // 'running' | 'approval' | 'idle'
  final int additions;
  final int deletions;
  final List<AgentChatTurn> turns;
  final PendingApprovalRequest approval;

  const RemoteSessionInfo({
    required this.id,
    required this.title,
    required this.repo,
    required this.branch,
    required this.status,
    this.additions = 0,
    this.deletions = 0,
    this.turns = const [],
    this.approval = const PendingApprovalRequest(pending: false),
  });

  RemoteSessionInfo copyWith({
    String? title,
    String? repo,
    String? branch,
    String? status,
    int? additions,
    int? deletions,
    List<AgentChatTurn>? turns,
    PendingApprovalRequest? approval,
  }) {
    return RemoteSessionInfo(
      id: id,
      title: title ?? this.title,
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      status: status ?? this.status,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      turns: turns ?? this.turns,
      approval: approval ?? this.approval,
    );
  }
}

class RemoteHostPreset {
  final String id;
  final String name;
  final String subtitle;
  final String url;

  const RemoteHostPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.url,
  });

  static const List<RemoteHostPreset> all = [
    RemoteHostPreset(
      id: 'agy_remote',
      name: 'Antigravity Remote Agents',
      subtitle: 'antigravity.google · 官方远端 Agent 控制台',
      url: 'https://antigravity.google/remote-agents',
    ),
    RemoteHostPreset(
      id: 'google_login',
      name: 'Google 账号统一登录中心',
      subtitle: 'accounts.google.com · 优先登录个人 Pro/Ultra 账号',
      url: 'https://accounts.google.com/ServiceLogin?continue=https://antigravity.google/remote-agents',
    ),
    RemoteHostPreset(
      id: 'project_idx',
      name: 'Google Project IDX 云端工作区',
      subtitle: 'idx.google.com · 云端全栈容器与 Agent 环境',
      url: 'https://idx.google.com',
    ),
    RemoteHostPreset(
      id: 'agy_docs',
      name: 'Antigravity Remote Agents 文档与入口',
      subtitle: 'antigravity.google/docs/remote-agents',
      url: 'https://antigravity.google/docs/remote-agents',
    ),
  ];
}
