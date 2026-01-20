class AdvocateDetailsModel {

  String? id, name, email, phone, profileImageId, locationName, password;
  double? lattitude, longitude;
  int? experience;
  String? licenseKey, userId;
  var advocateSpeciality = [];
  var degrees = [];
  var workingExperiences = [];

  AdvocateDetailsModel(this.id, this.name, this.email, this.phone,
      this.profileImageId, this.locationName, this.lattitude, this.longitude, this.password, this.experience, this.licenseKey, this.advocateSpeciality, this.degrees, this.workingExperiences, this.userId);

  AdvocateDetailsModel.defaultConstructor();

}