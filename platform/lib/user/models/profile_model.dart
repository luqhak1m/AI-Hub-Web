class ExperienceItem {
  final String title, company, startDate, rawNotes;
  final String? endDate;
  final bool isCurrent;

  ExperienceItem({required this.title, required this.company, required this.startDate, required this.rawNotes, this.endDate, this.isCurrent = false});

  Map<String, dynamic> toJson() => {'title': title, 'company': company, 'start_date': startDate, 'end_date': endDate, 'is_current': isCurrent, 'raw_notes': rawNotes};
}

class SkillItem {
  final String name;
  SkillItem({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

class EducationItem {
  final String degree, institution, year;
  EducationItem({required this.degree, required this.institution, required this.year});
  Map<String, dynamic> toJson() => {'degree': degree, 'institution': institution, 'year': year};
}

class CertificationItem {
  final String name, issuer, year;
  CertificationItem({required this.name, required this.issuer, required this.year});
  Map<String, dynamic> toJson() => {'name': name, 'issuer': issuer, 'year': year};
}

class ProfileModel {
  final int id, userId;
  final String? name, email, phone, linkedin;

  /// API path of the uploaded profile picture; null when none is set.
  final String? avatarUrl;
  final List<dynamic> experiences, skills, education, certifications, careerAssessmentResults;

  ProfileModel({required this.id, required this.userId, this.name, this.email, this.phone, this.linkedin, this.avatarUrl, required this.experiences, required this.skills, required this.education, required this.certifications, required this.careerAssessmentResults});

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    id: (json['id'] as int?) ?? 0,
    userId: (json['user_id'] as int?) ?? 0,
    name: json['name'],
    email: json['email'],
    phone: json['phone'],
    linkedin: json['linkedin'],
    avatarUrl: json['avatar_url'] as String?,
    experiences: List<dynamic>.from(json['experiences'] ?? []),
    skills: List<dynamic>.from(json['skills'] ?? []),
    education: List<dynamic>.from(json['education'] ?? []),
    certifications: List<dynamic>.from(json['certifications'] ?? []),
    careerAssessmentResults: List<dynamic>.from(json['career_assessment_results'] ?? []),
  );
}
