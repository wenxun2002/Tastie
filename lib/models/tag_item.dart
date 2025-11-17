class TagItem {
  final int id;
  final String label;
  final bool isEnabled;

  const TagItem({
    required this.id,
    required this.label,
    this.isEnabled = false,
  });

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: json['id'] as int,
      label: json['label'] as String,
      isEnabled: (json['defaultEnabled'] as bool?) ?? false,
    );
  }

  TagItem copyWith({
    bool? isEnabled,
  }) {
    return TagItem(
      id: id,
      label: label,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'defaultEnabled': isEnabled,
    };
  }
}

