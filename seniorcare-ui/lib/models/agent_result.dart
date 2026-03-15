class AgentResult {
  final String agentName;
  final Map<String, dynamic> output;
  final bool wasInvoked;

  const AgentResult({
    required this.agentName,
    required this.output,
    required this.wasInvoked,
  });
}
