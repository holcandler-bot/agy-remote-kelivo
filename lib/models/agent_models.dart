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
    this.toolCalls = const [],
    this.codeBlocks = const [],
    this.tokenStats = '1,420 tok · 52.4 t/s',
    this.branchIndex = 2,
    this.branchTotal = 2,
  });

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

  const RemoteSessionInfo({
    required this.id,
    required this.title,
    required this.repo,
    required this.branch,
    required this.status,
    this.additions = 0,
    this.deletions = 0,
  });
}
