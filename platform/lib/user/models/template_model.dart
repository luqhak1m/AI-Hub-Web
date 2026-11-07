class SectionConstraints {
  final int minItems, maxItems;
  final int? descMinChars, descMaxChars;

  SectionConstraints({required this.minItems, required this.maxItems, this.descMinChars, this.descMaxChars});

  factory SectionConstraints.fromJson(Map<String, dynamic> json) => SectionConstraints(
    minItems: json['min_items'] ?? 0,
    maxItems: json['max_items'] ?? 0,
    descMinChars: json['desc_min_chars'],
    descMaxChars: json['desc_max_chars'],
  );
}

class TemplateModel {
  final int id;
  final String name, description;
  final String? previewImageUrl;
  final Map<String, SectionConstraints> sections;

  TemplateModel({required this.id, required this.name, required this.description, this.previewImageUrl, required this.sections});

  factory TemplateModel.fromJson(Map<String, dynamic> json) => TemplateModel(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    previewImageUrl: json['preview_image_url'],
    sections: ((json['sections'] as Map<String, dynamic>?) ?? {}).map(
      (k, v) => MapEntry(k, SectionConstraints.fromJson(v as Map<String, dynamic>)),
    ),
  );

  String eligibilityHint(Map<String, int> userCounts) {
    for (final entry in sections.entries) {
      final min = entry.value.minItems;
      if (min > 0 && (userCounts[entry.key] ?? 0) < min) {
        return 'Requires $min+ ${entry.key}';
      }
    }
    return '';
  }
}
