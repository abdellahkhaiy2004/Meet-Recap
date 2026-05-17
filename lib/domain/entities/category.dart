/// Folder category enum — matches architecture §6 colour tokens in AppColors.
enum Category {
  work,
  education,
  personal,
  health,
  finance,
  legal,
  other;

  String get label => switch (this) {
        Category.work => 'Travail',
        Category.education => 'Éducation',
        Category.personal => 'Personnel',
        Category.health => 'Santé',
        Category.finance => 'Finance',
        Category.legal => 'Juridique',
        Category.other => 'Autre',
      };
}
