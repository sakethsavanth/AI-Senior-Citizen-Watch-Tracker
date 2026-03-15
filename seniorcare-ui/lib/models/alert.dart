enum AlertType { critical, aiAction, warning, info }

class Alert {
  final AlertType type;
  final String message;
  final String time;
  final bool hasCta;
  final String? ctaLabel;

  const Alert({
    required this.type,
    required this.message,
    required this.time,
    this.hasCta = false,
    this.ctaLabel,
  });
}
