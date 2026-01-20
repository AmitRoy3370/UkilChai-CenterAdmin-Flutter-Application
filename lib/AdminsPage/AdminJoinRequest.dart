class AdminJoinRequest {
  final String id;
  final String userId;
  final List<String> advocateSpeciality;

  AdminJoinRequest({
    required this.id,
    required this.userId,
    required this.advocateSpeciality,
  });

  factory AdminJoinRequest.fromJson(Map<String, dynamic> json) {
    return AdminJoinRequest(
      id: json['id'],
      userId: json['userId'],
      advocateSpeciality:
      List<String>.from(json['advocateSpeciality'] ?? []),
    );
  }
}
