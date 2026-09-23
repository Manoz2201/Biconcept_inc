enum ProjectStatus {
  planning('planning', 'Planning'),
  inProgress('in_progress', 'In progress'),
  onHold('on_hold', 'On hold'),
  review('review', 'Review'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const ProjectStatus(this.value, this.label);

  final String value;
  final String label;

  String toAppwriteString() => value;

  static ProjectStatus fromString(String raw) => values.firstWhere(
        (status) => status.value == raw || status.name == raw,
        orElse: () => ProjectStatus.planning,
      );

  bool get isTerminal => this == completed || this == cancelled;

  bool canTransitionTo(ProjectStatus next) {
    return switch (this) {
      ProjectStatus.planning =>
        next == ProjectStatus.inProgress || next == ProjectStatus.cancelled,
      ProjectStatus.inProgress =>
        next == ProjectStatus.onHold ||
            next == ProjectStatus.review ||
            next == ProjectStatus.completed ||
            next == ProjectStatus.cancelled,
      ProjectStatus.onHold =>
        next == ProjectStatus.inProgress || next == ProjectStatus.cancelled,
      ProjectStatus.review =>
        next == ProjectStatus.inProgress || next == ProjectStatus.completed,
      ProjectStatus.completed || ProjectStatus.cancelled => false,
    };
  }
}

enum ProjectPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const ProjectPriority(this.value, this.label);
  final String value;
  final String label;

  static ProjectPriority? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in values) {
      if (value.value == raw || value.name == raw) return value;
    }
    return null;
  }
}
