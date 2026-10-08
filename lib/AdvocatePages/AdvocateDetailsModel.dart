import '../RegistrationPage/gender.dart';

class AdvocateDetailsModel {
  String? id;
  String? contactInfoId;
  String? locationId;

  String? userId;
  String? userGenderId;
  Gender? gender;
  String? name;
  String? fullName;
  String? profileImageId;

  List<String> advocateSpeciality;

  int? experience;
  double rating; // 🔥 non-nullable করা হয়েছে

  String? licenseKey;
  String? cvHexKey;
  String? district;

  List<String> degrees;
  List<String> workingExperiences;

  String? email;
  String? phone;

  String? locationName;

  double? lattitude;
  double? longitude;

  AdvocateDetailsModel(
      this.id,
      this.contactInfoId,
      this.locationId,
      this.userId,
      this.name,
      this.fullName,
      this.profileImageId,
      this.advocateSpeciality,
      this.experience,
      this.licenseKey,
      this.cvHexKey,
      this.degrees,
      this.workingExperiences,
      this.email,
      this.phone,
      this.locationName,
      this.lattitude,
      this.longitude,
      this.district,
      this.rating,
      this.userGenderId,
      this.gender
      );

  AdvocateDetailsModel.defaultConstructor()
      : advocateSpeciality = [],
        degrees = [],
        workingExperiences = [],
        rating = 0.0; // 🔥 ডিফল্ট ভ্যালু

  // 🔥 FROM JSON
  factory AdvocateDetailsModel.fromJson(Map<String, dynamic> json) {
    return AdvocateDetailsModel(
      json['id']?.toString() ?? json['_id']?.toString(),
      json['contactInfoId']?.toString(),
      json['locationId']?.toString(),
      json['userId']?.toString(),
      json['name']?.toString(),
      json['fullName']?.toString(),
      json['profileImageId']?.toString(),

      // ✅ Enum Set → List<String>
      json['advocateSpeciality'] != null
          ? List<String>.from(json['advocateSpeciality'].map((e) => e.toString()))
          : [],

      (json['experience'] ?? 0).toInt(),

      json['licenseKey']?.toString(),
      json['cvHexKey']?.toString(),

      // ✅ Arrays
      json['degrees'] != null
          ? List<String>.from(json['degrees'].map((e) => e.toString()))
          : [],

      json['workingExperiences'] != null
          ? List<String>.from(
          json['workingExperiences'].map((e) => e.toString()))
          : [],

      json['email']?.toString(),
      json['phone']?.toString(),

      json['locationName']?.toString(),
      
      json['lattitude'] != null
          ? double.tryParse(json['lattitude'].toString())
          : null,

      json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      json['district'] != null ? json['district'] : '',
      json['rating'] != null 
          ? double.tryParse(json['rating'].toString()) ?? 0.0 
          : 0.0,
      json['userGenderId'],
      json['gender']
    );
  }
}