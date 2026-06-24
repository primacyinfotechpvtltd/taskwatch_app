class ProjectModel {
  final int id;
  final String name;

  ProjectModel({required this.id, required this.name});

  // Convert a ProjectModel instance to a JSON map
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  // Create a ProjectModel instance from a JSON map
  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(id: json['id'], name: json['name']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
