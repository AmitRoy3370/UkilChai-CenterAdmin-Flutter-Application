import '../RegistrationPage/gender.dart';

// Assuming you create these models based on our previous discussions
import 'advocate_working_experience_model.dart';
import 'advocate_documents_model.dart';
import 'advocate_additional_info_model.dart';

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
  double rating;

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

  // ✅ ADDED: Nested models from AdvocateResponse DTO
  AdvocateWorkingExperience? workingExperience;
  AdvocateDocuments? advocateDocuments;
  AdvocateAdditionalInfo? additionalInfo;

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
    this.gender,
    this.workingExperience,
    this.advocateDocuments,
    this.additionalInfo,
  );

  AdvocateDetailsModel.defaultConstructor()
    : advocateSpeciality = [],
      degrees = [],
      workingExperiences = [],
      rating = 0.0;

  // 🔥 FROM JSON (Mapped exactly to AdvocateResponse)
factory AdvocateDetailsModel.fromJson(Map<String, dynamic> json) {
  return AdvocateDetailsModel(
    json['id']?.toString() ?? json['_id']?.toString(),
    json['contactInfoId']?.toString(),
    json['locationId']?.toString(),
    json['userId']?.toString(),
    json['name']?.toString(),
    json['fullName']?.toString(),
    json['profileImageId']?.toString(),
    _parseStringList(json['advocateSpeciality']),
    _parseInt(json['experience']) ?? 0,
    json['licenseKey']?.toString(),
    json['cvHexKey']?.toString(),
    _parseStringList(json['degrees']),
    _parseStringList(json['workingExperiences']),
    json['email']?.toString(),
    json['phone']?.toString(),
    json['locationName']?.toString(),
    _parseDouble(json['lattitude']),
    _parseDouble(json['longitude']),
    json['district']?.toString(),          // ✅ null instead of ''
    _parseDouble(json['rating']) ?? 0.0,
    json['userGenderId']?.toString(),
    _parseGender(json['gender']),          // ✅ safe
    json['workingExperience'] != null
        ? AdvocateWorkingExperience.fromJson(json['workingExperience'])
        : null,
    json['advocateDocuments'] != null
        ? AdvocateDocuments.fromJson(json['advocateDocuments'])
        : null,
    json['additionalInfo'] != null
        ? AdvocateAdditionalInfo.fromJson(json['additionalInfo'])
        : null,
  );
}

// ── Safe cast helpers ─────────────────────────────────────
static int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

static double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

static List<String> _parseStringList(dynamic v) {
  if (v == null) return <String>[];
  if (v is List) return v.map((e) => e.toString()).toList();
  return <String>[];
}

static Gender? _parseGender(dynamic v) {
  if (v == null) return null;
  final s = v.toString().toUpperCase();
  switch (s) {
    case 'MALE':
      return Gender.MALE;
    case 'FEMALE':
      return Gender.FEMALE;
    case 'OTHER':
      return Gender.OTHER;
    default:
      return null;   // ✅ never throws
  }
}
}
