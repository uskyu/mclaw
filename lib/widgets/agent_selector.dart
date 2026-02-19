import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../models/agent.dart';

class AgentSelector extends StatelessWidget {
  final Agent currentAgent;
  final Function(Agent) onAgentSelected;

  const AgentSelector({
    super.key,
    required this.currentAgent,
    required this.onAgentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final agents = [
      Agent(
        id: 'general',
        name: l10n.generalAssistant,
        icon: '🤖',
        description: l10n.generalAssistantDesc,
        isDefault: true,
      ),
      Agent(
        id: 'code',
        name: l10n.codeAssistant,
        icon: '💻',
        description: l10n.codeAssistantDesc,
      ),
      Agent(
        id: 'writing',
        name: l10n.writingAssistant,
        icon: '✍️',
        description: l10n.writingAssistantDesc,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部把手
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.appleGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.selectAgent,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(),
            // Agent列表
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final agent = agents[index];
                final isSelected = agent.id == currentAgent.id;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.appleBlue.withValues(alpha: 0.1)
                          : AppTheme.appleLightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        agent.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  title: Text(
                    agent.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppTheme.appleBlue : null,
                    ),
                  ),
                  subtitle: Text(
                    agent.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppTheme.appleBlue)
                      : null,
                  onTap: () => onAgentSelected(agent),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
