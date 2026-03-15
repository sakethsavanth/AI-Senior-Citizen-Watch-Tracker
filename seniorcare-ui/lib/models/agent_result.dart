class AgentResult {
  final String agentName;
  final Map<String, dynamic>? output;
  final bool wasInvoked;

  const AgentResult({
    required this.agentName,
    this.output,
    required this.wasInvoked,
  });

  factory AgentResult.fromMap(String name, Map<String, dynamic> map) {
    return AgentResult(
      agentName: name,
      wasInvoked: map['invoked'] as bool? ?? false,
      output: map['output'] as Map<String, dynamic>?,
    );
  }
}
