import '../Utils/AdvocateSpeciality.dart';

class AdminDTO {
  final String id;
  final String? profileImageId;
  final String userId;
  final String userName;
  final Set<AdvocateSpeciality> advocateSpeciality;

  AdminDTO({
    required this.id,
    this.profileImageId,
    required this.userId,
    required this.userName,
    required this.advocateSpeciality,
  });

  // Factory constructor for creating AdminDTO from JSON
  factory AdminDTO.fromJson(Map<String, dynamic> json) {
    // Parse advocateSpeciality from JSON
    Set<AdvocateSpeciality> specialities = {};
    
    if (json['advocateSpeciality'] != null) {
      final specialitiesList = json['advocateSpeciality'] as List;
      specialities = specialitiesList
          .map((item) => AdvocateSpecialityExt.fromApi(item.toString()))
          .toSet();
    }

    return AdminDTO(
      id: json['id'] as String,
      profileImageId: json['profileImageId'] as String?,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      advocateSpeciality: specialities,
    );
  }

  // Convert AdminDTO to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileImageId': profileImageId,
      'userId': userId,
      'userName': userName,
      'advocateSpeciality': advocateSpeciality.map((e) => e.name).toList(),
    };
  }

  // Copy with method for updating specific fields
  AdminDTO copyWith({
    String? id,
    String? profileImageId,
    String? userId,
    String? userName,
    Set<AdvocateSpeciality>? advocateSpeciality,
  }) {
    return AdminDTO(
      id: id ?? this.id,
      profileImageId: profileImageId ?? this.profileImageId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      advocateSpeciality: advocateSpeciality ?? this.advocateSpeciality,
    );
  }

  @override
  String toString() {
    return 'AdminDTO(id: $id, profileImageId: $profileImageId, userId: $userId, userName: $userName, advocateSpeciality: $advocateSpeciality)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminDTO &&
        other.id == id &&
        other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;
}