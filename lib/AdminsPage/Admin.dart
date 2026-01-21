class Admin {
  final String id;
  final String userId;
  final List<String> advocateSpeciality;

  Admin({
    required this.id,
    required this.userId,
    required this.advocateSpeciality,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'],
      userId: json['userId'],
      advocateSpeciality:
      List<String>.from(json['advocateSpeciality'] ?? []),
    );
  }
}
