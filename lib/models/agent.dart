class Agent {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isDefault;

  Agent({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isDefault = false,
  });

  static List<Agent> get defaultAgents => [
    Agent(
      id: 'general',
      name: '通用助手',
      icon: '🤖',
      description: '可以回答各类问题',
      isDefault: true,
    ),
    Agent(
      id: 'code',
      name: '代码助手',
      icon: '💻',
      description: '专注编程问题',
    ),
    Agent(
      id: 'writing',
      name: '写作助手',
      icon: '✍️',
      description: '文章润色创意写作',
    ),
  ];
}
