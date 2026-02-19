class AdvocateJoinRequestModel {
  String? id;
  String? name;
  String? email;
  String? phone;
  String? profileImageId;
  String? locationName;
  String? password;
  String? userId;

  double? lattitude;
  double? longitude;
  int? experience;

  String? licenseKey;

  List<dynamic> advocateSpeciality;
  List<dynamic> degrees;
  List<dynamic> workingExperiences;

  AdvocateJoinRequestModel(
      this.id,
      this.name,
      this.email,
      this.phone,
      this.profileImageId,
      this.locationName,
      this.lattitude,
      this.longitude,
      this.password,
      this.experience,
      this.licenseKey,
      this.advocateSpeciality,
      this.degrees,
      this.workingExperiences,
      this.userId,
      );

  AdvocateJoinRequestModel.defaultConstructor()
      : advocateSpeciality = [],
        degrees = [],
        workingExperiences = [];

  // 🔥 FROM JSON
  factory AdvocateJoinRequestModel.fromJson(Map<String, dynamic> json) {
    return AdvocateJoinRequestModel(
      json['id'] ?? json['_id'],
      json['name'],
      json['email'],
      json['phone'],
      json['profileImageId'],
      json['locationName'],
      json['lattitude'] != null
          ? double.tryParse(json['lattitude'].toString())
          : null,
      json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      json['password'],
      json['experience'],
      json['licenseKey'],
      json['advocateSpeciality'] != null
          ? List.from(json['advocateSpeciality'])
          : [],
      json['degrees'] != null ? List.from(json['degrees']) : [],
      json['workingExperiences'] != null
          ? List.from(json['workingExperiences'])
          : [],
      json['userId'],
    );
  }
}
