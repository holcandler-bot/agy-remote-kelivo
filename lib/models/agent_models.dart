class AgyModelSpec {
  final String id;
  final String name;
  final String subtitle;
  final String badge;
  final List<String> thinkingLevels;
  final String defaultThinking;

  const AgyModelSpec({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.thinkingLevels,
    required this.defaultThinking,
  });
}

class AgyModelCatalog {
  static const String defaultModelName = 'Gemini 4 Argon';
  static const String defaultThinkingLevel = 'High';

  static const List<AgyModelSpec> models = [
    AgyModelSpec(
      id: 'gemini_4_argon',
      name: 'Gemini 4 Argon',
      subtitle: 'Google DeepMind 主力旗舰推理模型 · 支持 Low / Medium / High 思考深度',
      badge: 'Pro / Ultra 默认',
      thinkingLevels: ['Low', 'Medium', 'High'],
      defaultThinking: 'High',
    ),
    AgyModelSpec(
      id: 'gemini_3_8_flash',
      name: 'Gemini 3.8 Flash',
      subtitle: 'Google 高速全能推理模型 · 支持 Fast / Low / Medium / High 四档调节',
      badge: '高速推理',
      thinkingLevels: ['Fast', 'Low', 'Medium', 'High'],
      defaultThinking: 'High',
    ),
    AgyModelSpec(
      id: 'claude_opus_5_5',
      name: 'Claude Opus 5.5 (Thinking)',
      subtitle: 'Anthropic 旗舰深度架构与复杂调试模型 · 付费 Pro / Ultra 专享',
      badge: '深度思考',
      thinkingLevels: ['Low', 'Medium', 'High'],
      defaultThinking: 'High',
    ),
    AgyModelSpec(
      id: 'claude_sonnet_5_5',
      name: 'Claude Sonnet 5.5 (Thinking)',
      subtitle: 'Anthropic 高效代码重构与多步工程模型 · 付费 Pro / Ultra 专享',
      badge: '敏捷工程',
      thinkingLevels: ['Low', 'Medium', 'High'],
      defaultThinking: 'High',
    ),
  ];

  static AgyModelSpec byName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final m in models) {
      if (m.name.toLowerCase() == normalized ||
          normalized.contains(m.name.toLowerCase())) {
        return m;
      }
    }
    return models.first;
  }

  static String normalizeModelName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.contains('3.8') || lower.contains('flash')) {
      return 'Gemini 3.8 Flash';
    }
    if (lower.contains('opus')) {
      return 'Claude Opus 5.5 (Thinking)';
    }
    if (lower.contains('sonnet')) {
      return 'Claude Sonnet 5.5 (Thinking)';
    }
    return defaultModelName;
  }

  static String normalizeThinkingLevel(String modelName, String level) {
    final spec = byName(modelName);
    final cleaned = (level == 'Med') ? 'Medium' : level;
    if (spec.thinkingLevels.contains(cleaned)) {
      return cleaned;
    }
    return spec.defaultThinking;
  }
}

class AgySlashCommand {
  final String command;
  final String title;
  final String description;
  final String templateSuffix;
  final bool autoSend;

  const AgySlashCommand({
    required this.command,
    required this.title,
    required this.description,
    this.templateSuffix = '',
    this.autoSend = false,
  });
}

class AgySlashCommandCatalog {
  /// 2026.11 Antigravity Remote Agents 官方真实支持的 11 个核心 Slash 指令
  /// （严禁包含 Remote Agent 不支持的 /diff、/fork、/rewind、/codesearch、/test、/compact）
  static const List<AgySlashCommand> all = [
    AgySlashCommand(
      command: '/plan',
      title: '制定实现计划 (Implementation Plan)',
      description: '先梳理架构并生成可审阅的计划 Artifact，确认 Proceed 后再执行',
      templateSuffix: '请先为以下需求制定分步实现计划：',
    ),
    AgySlashCommand(
      command: '/goal',
      title: '长时自治目标 (Autonomous Goal)',
      description: '设定终极验收目标，让云端 Agent 持续自主迭代直至完全达成',
      templateSuffix: '请持续自主完成以下目标并验证通过：',
    ),
    AgySlashCommand(
      command: '/boost',
      title: '深度多视角思考 (Deep Boost)',
      description: '开启战略规划、多视角推演与严密验证模式解决复杂工程难题',
      templateSuffix: '请深度分析并解决以下复杂问题：',
    ),
    AgySlashCommand(
      command: '/teamwork',
      title: '多子代理协同 (Multi-Agent Teamwork)',
      description: '组建多个自治 Subagent 并行分工处理大型仓库任务',
      templateSuffix: '请启动多子代理协作完成以下模块：',
    ),
    AgySlashCommand(
      command: '/grill-me',
      title: '架构对齐访谈 (Interactive Grill)',
      description: '让 Agent 通过交互式提问帮你理清模糊需求与边界条件',
      templateSuffix: '我想设计以下功能，请先向我提问以对齐所有设计决策：',
    ),
    AgySlashCommand(
      command: '/effort',
      title: '调节推理思考力度 (Thinking Effort)',
      description: '动态切换当前会话的思考深度 (Low / Medium / High)',
      templateSuffix: 'high',
    ),
    AgySlashCommand(
      command: '/permissions',
      title: '云端权限策略 (Permission Preset)',
      description: '配置 always-proceed (turbo)、default 或 request review 权限规则',
      autoSend: true,
    ),
    AgySlashCommand(
      command: '/plugin',
      title: '云端插件中心 (Marketplace Plugins)',
      description: '连接与管理 GitHub、Google Drive、Google Docs、Sheets 等插件',
      autoSend: true,
    ),
    AgySlashCommand(
      command: '/usage',
      title: '查看订阅配额余量 (View Usage)',
      description: '查看 Gemini 与 Claude 的 5 小时限额 (Five Hour) 与周限额 (Weekly)',
      autoSend: true,
    ),
    AgySlashCommand(
      command: '/credits',
      title: '查询 AI Credits 额度',
      description: '查看当前 Google AI Pro / Ultra 账号的 AI Credits 状态',
      autoSend: true,
    ),
    AgySlashCommand(
      command: '/resume',
      title: '恢复云端历史会话 (Resume Session)',
      description: '从云端项目中选择并恢复之前的 Remote Agent 对话',
      autoSend: true,
    ),
  ];
}

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'detail': detail,
      'filePath': filePath,
      'addedLines': addedLines,
      'removedLines': removedLines,
      'statusText': statusText,
      'shellTail': shellTail,
      'diffPreview': diffPreview,
      'status': status,
    };
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
    this.modelName = AgyModelCatalog.defaultModelName,
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
    String? modelName,
    String? content,
    String? translatedContent,
    bool? thinkingActive,
    List<ToolCallItem>? toolCalls,
    int? branchIndex,
    int? branchTotal,
    String? tokenStats,
  }) {
    return AgentChatTurn(
      id: id,
      isUser: isUser,
      modelName: modelName ?? this.modelName,
      timestamp: timestamp,
      thinking: thinking,
      thinkingDuration: thinkingDuration,
      thinkingActive: thinkingActive ?? this.thinkingActive,
      content: content ?? this.content,
      translatedContent: translatedContent ?? this.translatedContent,
      toolCalls: toolCalls ?? this.toolCalls,
      codeBlocks: codeBlocks,
      tokenStats: tokenStats ?? this.tokenStats,
      branchIndex: branchIndex ?? this.branchIndex,
      branchTotal: branchTotal ?? this.branchTotal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': isUser ? 'user' : 'agent',
      'modelName': modelName,
      'timestamp': timestamp,
      'thinking': thinking,
      'thinkingDuration': thinkingDuration,
      'thinkingActive': thinkingActive,
      'content': content,
      'translatedContent': translatedContent,
      'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
      'codeBlocks': codeBlocks,
      'tokenStats': tokenStats,
      'branchIndex': branchIndex,
      'branchTotal': branchTotal,
    };
  }

  factory AgentChatTurn.fromJson(Map<String, dynamic> json) {
    final rawTools = (json['toolCalls'] as List?) ?? const [];
    final rawCodes = (json['codeBlocks'] as List?) ?? const [];
    return AgentChatTurn(
      id: (json['id'] ?? '').toString(),
      isUser: json['role'] == 'user' || json['isUser'] == true,
      modelName: AgyModelCatalog.normalizeModelName(
        (json['modelName'] ?? AgyModelCatalog.defaultModelName).toString(),
      ),
      timestamp: (json['timestamp'] ?? '刚刚').toString(),
      thinking: (json['thinking'] ?? '').toString(),
      thinkingDuration: (json['thinkingDuration'] ?? '2.8s').toString(),
      thinkingActive: json['thinkingActive'] == true,
      content: (json['content'] ?? '').toString(),
      translatedContent: json['translatedContent']?.toString(),
      toolCalls: rawTools
          .whereType<Map>()
          .map((e) => ToolCallItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      codeBlocks: rawCodes.map((e) => e.toString()).toList(),
      tokenStats: (json['tokenStats'] ?? '1,420 tok · 52.4 t/s').toString(),
      branchIndex: int.tryParse((json['branchIndex'] ?? 1).toString()) ?? 1,
      branchTotal: int.tryParse((json['branchTotal'] ?? 1).toString()) ?? 1,
    );
  }
}

class PendingApprovalRequest {
  final bool pending;
  final String approvalType; // 'plan' | 'tool'
  final String commandOrFile;
  final String summary;
  final String approveLabel;
  final String denyLabel;

  const PendingApprovalRequest({
    this.pending = false,
    this.approvalType = 'tool',
    this.commandOrFile = '',
    this.summary = '',
    this.approveLabel = 'Proceed · 批准继续',
    this.denyLabel = '拒绝',
  });

  bool get isPlanReview => approvalType == 'plan';

  Map<String, dynamic> toJson() {
    return {
      'pending': pending,
      'approvalType': approvalType,
      'commandOrFile': commandOrFile,
      'summary': summary,
      'approveLabel': approveLabel,
      'denyLabel': denyLabel,
    };
  }

  factory PendingApprovalRequest.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['pending'] != true) {
      return const PendingApprovalRequest(pending: false);
    }
    return PendingApprovalRequest(
      pending: true,
      approvalType: (json['approvalType'] ?? 'tool').toString(),
      commandOrFile: (json['commandOrFile'] ?? 'Implementation Plan / Tool').toString(),
      summary: (json['summary'] ?? '').toString(),
      approveLabel: (json['approveLabel'] ?? 'Proceed · 批准继续').toString(),
      denyLabel: (json['denyLabel'] ?? '拒绝').toString(),
    );
  }
}

class RemoteControlLinkInfo {
  final String instanceId;
  final String? conversationId;
  final String normalizedUrl;

  const RemoteControlLinkInfo({
    required this.instanceId,
    this.conversationId,
    required this.normalizedUrl,
  });
}

class RemoteSessionInfo {
  final String id;
  final String title;
  final String repo;
  final String branch;
  final String mode; // 'remote_agent' | 'remote_control'
  final String? instanceId;
  final String? remoteUrl;
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
    this.mode = 'remote_agent',
    this.instanceId,
    this.remoteUrl,
    required this.status,
    this.additions = 0,
    this.deletions = 0,
    this.turns = const [],
    this.approval = const PendingApprovalRequest(pending: false),
  });

  bool get isRemoteControl => mode == 'remote_control';

  static RemoteControlLinkInfo? tryParseRemoteControlUrl(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // 匹配完整 URL 如 https://antigravity.google.com/r/host-swift-falcon?p=c%2F1234
    final urlMatch = RegExp(
      r'https?://antigravity\.google\.com/r/([a-zA-Z0-9._-]+)([^\s]*)',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (urlMatch != null) {
      final instanceId = urlMatch.group(1)!;
      final fullUrl = urlMatch.group(0)!;
      String? convId;
      final decoded = Uri.decodeFull(fullUrl);
      final convMatch = RegExp(r'[?&]p=c/([a-zA-Z0-9._-]+)').firstMatch(decoded);
      if (convMatch != null) {
        convId = convMatch.group(1);
      }
      return RemoteControlLinkInfo(
        instanceId: instanceId,
        conversationId: convId,
        normalizedUrl: fullUrl,
      );
    }

    // 支持直接粘贴 /r/<instance-id>
    final pathMatch = RegExp(r'^/?r/([a-zA-Z0-9._-]+)(.*)$').firstMatch(trimmed);
    if (pathMatch != null) {
      final instanceId = pathMatch.group(1)!;
      final suffix = pathMatch.group(2) ?? '';
      return RemoteControlLinkInfo(
        instanceId: instanceId,
        normalizedUrl: 'https://antigravity.google.com/r/$instanceId$suffix',
      );
    }

    return null;
  }

  RemoteSessionInfo copyWith({
    String? title,
    String? repo,
    String? branch,
    String? mode,
    String? instanceId,
    String? remoteUrl,
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
      mode: mode ?? this.mode,
      instanceId: instanceId ?? this.instanceId,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      status: status ?? this.status,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      turns: turns ?? this.turns,
      approval: approval ?? this.approval,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'repo': repo,
      'branch': branch,
      'mode': mode,
      'instanceId': instanceId,
      'remoteUrl': remoteUrl,
      'status': status,
      'additions': additions,
      'deletions': deletions,
      'turns': turns.map((t) => t.toJson()).toList(),
      'approval': approval.toJson(),
    };
  }

  factory RemoteSessionInfo.fromJson(Map<String, dynamic> json) {
    final rawTurns = (json['turns'] as List?) ?? const [];
    final rawApproval = json['approval'];
    return RemoteSessionInfo(
      id: (json['id'] ?? 's_default').toString(),
      title: (json['title'] ?? '默认云端工作区').toString(),
      repo: (json['repo'] ?? 'antigravity.google.com').toString(),
      branch: (json['branch'] ?? 'main').toString(),
      mode: (json['mode'] ?? 'remote_agent').toString(),
      instanceId: json['instanceId']?.toString(),
      remoteUrl: json['remoteUrl']?.toString(),
      status: (json['status'] ?? 'idle').toString(),
      additions: int.tryParse((json['additions'] ?? 0).toString()) ?? 0,
      deletions: int.tryParse((json['deletions'] ?? 0).toString()) ?? 0,
      turns: rawTurns
          .whereType<Map>()
          .map((e) => AgentChatTurn.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      approval: rawApproval is Map
          ? PendingApprovalRequest.fromJson(
              Map<String, dynamic>.from(rawApproval),
            )
          : const PendingApprovalRequest(pending: false),
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

  static const String officialWebUrl = 'https://antigravity.google.com/';
  static const String officialRemoteControlUrl =
      'https://antigravity.google.com/';
  static const String officialLoginUrl =
      'https://accounts.google.com/ServiceLogin?passive=1209600&continue=https://antigravity.google.com/&followup=https://antigravity.google.com/&ec=GAZAgQY';

  static const List<RemoteHostPreset> all = [
    RemoteHostPreset(
      id: 'agy_remote',
      name: 'Remote Agents 云端独立工作台',
      subtitle: 'antigravity.google.com · Google 托管隔离云端沙盒 (推荐)',
      url: officialWebUrl,
    ),
    RemoteHostPreset(
      id: 'agy_remote_control',
      name: 'Remote Control 远程接管本机电脑',
      subtitle: 'antigravity.google.com/r/<instance> · 控制桌面端或 CLI 守护进程',
      url: officialRemoteControlUrl,
    ),
    RemoteHostPreset(
      id: 'google_login',
      name: 'Google 账号官方 OAuth 登录入口',
      subtitle: 'accounts.google.com · 登录后自动返回 antigravity.google.com',
      url: officialLoginUrl,
    ),
    RemoteHostPreset(
      id: 'agy_docs',
      name: 'Antigravity Remote Agents 官方文档',
      subtitle: 'antigravity.google/docs/remote-agents',
      url: 'https://antigravity.google/docs/remote-agents',
    ),
  ];
}
