class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.website,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String website;
}

abstract final class AiProviderCatalog {
  static const presets = <AiProviderPreset>[
    AiProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash',
      website: 'https://platform.deepseek.com',
    ),
    AiProviderPreset(
      id: 'qwen',
      name: 'Qwen / 阿里百炼',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen-plus',
      website: 'https://bailian.console.aliyun.com',
    ),
    AiProviderPreset(
      id: 'zhipu',
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-5.2',
      website: 'https://open.bigmodel.cn',
    ),
    AiProviderPreset(
      id: 'siliconflow',
      name: '硅基流动',
      baseUrl: 'https://api.siliconflow.cn/v1',
      model: 'Pro/zai-org/GLM-4.7',
      website: 'https://cloud.siliconflow.cn',
    ),
    AiProviderPreset(
      id: 'mimo',
      name: '小米 MiMo',
      baseUrl: 'https://api.xiaomimimo.com/v1',
      model: 'mimo-v2.5-pro',
      website: 'https://platform.xiaomimimo.com',
    ),
    AiProviderPreset(
      id: 'kimi',
      name: 'Kimi',
      baseUrl: 'https://api.moonshot.cn/v1',
      model: 'kimi-k3',
      website: 'https://platform.kimi.com',
    ),
    AiProviderPreset(
      id: 'custom',
      name: '自定义 OpenAI 兼容接口',
      baseUrl: '',
      model: '',
      website: '',
    ),
  ];

  static AiProviderPreset byId(String id) =>
      presets.firstWhere((item) => item.id == id, orElse: () => presets.last);
}
