// UpdateProfile.dart — Center Admin, responsive inputs + admin district update
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:advocatechaicenteradmin/Utils/BaseURL.dart' as baseURL;
import 'package:advocatechaicenteradmin/Auth/AuthService.dart';

class UpdateProfile extends StatefulWidget {
  const UpdateProfile({super.key});

  @override
  State<UpdateProfile> createState() => _UpdateProfileState();
}

class _UpdateProfileState extends State<UpdateProfile> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController oldNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationTextController = TextEditingController();

  bool _showPassword = false, _showOldPassword = false;

  lat_lng.LatLng? _devicePosition;
  lat_lng.LatLng? _selectedPosition;
  String? _selectedPlaceName;
  List<Marker> _markers = [];
  bool showForm = false;
  bool locationPresent = false;
  File? pickedImage;
  Uint8List? webImageBytes;
  double latitude = 0.0;
  double longitude = 0.0;

  bool loading = true;
  bool isUpdating = false;

  final MapController mapController = MapController();

  Stream<Position>? _positionStream;

  final FocusNode _oldNameFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _oldPasswordFocus = FocusNode();
  final FocusNode _newPasswordFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  List<String> selectedDistricts = [];
  List<String> admins = [];
  List<String> advocates = [];

  final List<String> bangladeshDistricts = [
    "Bagerhat", "Bandarban", "Barguna", "Barisal", "Bhola", "Bogura",
    "Brahmanbaria", "Chandpur", "Chapainawabganj", "Chattogram", "Chuadanga",
    "Cox's Bazar", "Cumilla", "Dhaka", "Dinajpur", "Faridpur", "Feni",
    "Gaibandha", "Gazipur", "Gopalganj", "Habiganj", "Jamalpur", "Jashore",
    "Jhalokathi", "Jhenaidah", "Joypurhat", "Khagrachari", "Khulna",
    "Kishoreganj", "Kurigram", "Kushtia", "Lakshmipur", "Lalmonirhat",
    "Madaripur", "Magura", "Manikganj", "Meherpur", "Moulvibazar",
    "Munshiganj", "Mymensingh", "Naogaon", "Narail", "Narayanganj",
    "Narsingdi", "Natore", "Netrokona", "Nilphamari", "Noakhali", "Pabna",
    "Panchagarh", "Patuakhali", "Pirojpur", "Rajbari", "Rajshahi",
    "Rangamati", "Rangpur", "Satkhira", "Shariatpur", "Sherpur",
    "Sirajganj", "Sunamganj", "Sylhet", "Tangail",
  ];

  // ============ RESPONSIVE HELPERS ============
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  double get _formHeight {
    final screenHeight = MediaQuery.of(context).size.height;
    if (_isDesktop) return screenHeight * 0.85;
    if (_isTablet) return screenHeight * 0.80;
    return screenHeight > 800 ? screenHeight * 0.88 : screenHeight * 0.92;
  }

  double get _horizontalPadding {
    if (_isDesktop) return 24;
    if (_isTablet) return 20;
    return 16;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPreviousData();
      _startLocationUpdates();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    fullNameController.dispose();
    oldNameController.dispose();
    passwordController.dispose();
    oldPasswordController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationTextController.dispose();

    _oldNameFocus.dispose();
    _nameFocus.dispose();
    _fullNameFocus.dispose();
    _oldPasswordFocus.dispose();
    _newPasswordFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();

    _positionStream?.drain();
    mapController.dispose();
    super.dispose();
  }

  // ============ DATA LOADING ============
  Future<File?> convertBytesToFile(
    Uint8List bytes, {
    required String extension,
  }) async {
    if (kIsWeb) return null;
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/profile.$extension';
    final file = File(tempPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> loadPreviousData() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      print("No token found...");
      return;
    }

    final userId = await AuthService.getUserId();

    final response = await http.get(
      Uri.parse("${baseURL.Urls().baseURL}user/search?userId=$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (mounted) {
        setState(() {
          oldNameController.text = data["name"] ?? "";
          fullNameController.text = data["fullName"] ?? "";
        });
      }

      final profileImageId = data["profileImageId"];
      if (profileImageId != null) {
        await _loadProfileImage(profileImageId, token);
      }

      await _loadLocationData(userId!, token);
      await _loadContactInfo(userId, token);
      await _loadCenterAdminData(userId, token);

      if (mounted) setState(() => loading = false);
    } else {
      if (mounted) setState(() => loading = false);
      print("Failed to load previous data: ${response.statusCode}");
    }
  }

  Future<void> _loadProfileImage(String profileImageId, String token) async {
    final url = "${baseURL.Urls().baseURL}user/download/$profileImageId";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Accept": "image/*,application/octet-stream",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final bytes = response.bodyBytes;
      bool isJpeg = bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      bool isPng = bytes.length > 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47;

      if ((isJpeg || isPng) && mounted) {
        setState(() => webImageBytes = bytes);
        try {
          final file = await convertBytesToFile(
            bytes,
            extension: isJpeg ? 'jpg' : 'png',
          );
          if (mounted) setState(() => pickedImage = file);
        } catch (e) {
          print('Image save error: $e');
        }
      }
    }
  }

  Future<void> _loadLocationData(String userId, String token) async {
    final url = "${baseURL.Urls().baseURL}userLocation/findByUserId/$userId";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          locationPresent = true;
          locationTextController.text = data["locationName"] ?? "";
          latitude = data["lattitude"] ?? 0.0;
          longitude = data["longitude"] ?? 0.0;
          _selectedPosition = lat_lng.LatLng(latitude, longitude);
          _updateMarkers();
        });
      }
    }
  }

  Future<void> _loadContactInfo(String userId, String token) async {
    final url =
        "${baseURL.Urls().baseURL}user/contact-info/user?userId=$userId";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          emailController.text = data["email"] ?? "";
          phoneController.text = data["phone"] ?? "";
        });
      }
    }
  }

  Future<void> _loadCenterAdminData(String userId, String token) async {
    final url = "${baseURL.Urls().baseURL}center-admin/by-user/$userId";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          selectedDistricts =
              (data["districts"] as List).cast<String>();
          admins = (data["admins"] as List).cast<String>();
          advocates = (data["advocates"] as List).cast<String>();
        });
      }
    }
  }

  // ============ LOCATION ============
  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location service")),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
        }
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    );
    _updateDevicePosition(position);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );

    _positionStream!.listen((Position position) {
      _updateDevicePosition(position);
    });
  }

  Future<void> _updateDevicePosition(Position position) async {
    lat_lng.LatLng newPos = lat_lng.LatLng(
      locationPresent ? latitude : position.latitude,
      locationPresent ? longitude : position.longitude,
    );
    String placeName = await getAddressFromLatLng(
      locationPresent ? latitude : position.latitude,
      locationPresent ? longitude : position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _devicePosition = newPos;
      if (_selectedPosition == null) {
        _selectedPosition = newPos;
        _selectedPlaceName = placeName;
        latitude = position.latitude;
        longitude = position.longitude;
        locationTextController.text = placeName;
      }
      _updateMarkers();
    });

    if (_selectedPosition == newPos) {
      mapController.move(newPos, 15.0);
    }
  }

  void _updateMarkers() {
    _markers = [];
    if (_devicePosition != null) {
      _markers.add(
        Marker(
          width: 80,
          height: 80,
          point: _devicePosition!,
          child: const Icon(Icons.my_location, color: Colors.red, size: 40),
        ),
      );
    }
    if (_selectedPosition != null && _selectedPosition != _devicePosition) {
      _markers.add(
        Marker(
          width: 80,
          height: 80,
          point: _selectedPosition!,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      );
    }
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'AdvocateChaiApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
    } catch (e) {
      if (kDebugMode) print('Geocoding error: $e');
    }
    return 'Lat: $lat, Lng: $lng';
  }

  Future<void> searchPlace() async {
    String query = searchController.text.trim();
    if (query.isEmpty) return;

    lat_lng.LatLng? pos;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'AdvocateChaiApp/1.0'},
      );

      if (response.statusCode == 200) {
        locationPresent = false;
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          double lat = double.parse(data[0]['lat']);
          double lng = double.parse(data[0]['lon']);
          if (mounted) {
            setState(() {
              latitude = lat;
              longitude = lng;
            });
          }
          pos = lat_lng.LatLng(lat, lng);
          String name = data[0]['display_name'];
          _selectedPosition = pos;
          _selectedPlaceName = name;
          locationTextController.text = _selectedPlaceName!;
          _updateMarkers();
          mapController.move(pos, 15.0);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Search error: $e');
    }

    if (pos == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No results found")),
      );
    }
  }

  // ============ IMAGE PICKER ============
  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Select from gallery'),
              onTap: () async {
                Navigator.pop(context);
                XFile? file =
                    await ImagePicker().pickImage(source: ImageSource.gallery);
                if (file != null) {
                  if (kIsWeb) {
                    webImageBytes = await file.readAsBytes();
                  } else {
                    pickedImage = File(file.path);
                  }
                  if (mounted) setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take from camera'),
              onTap: () async {
                Navigator.pop(context);
                XFile? file =
                    await ImagePicker().pickImage(source: ImageSource.camera);
                if (file != null) {
                  if (kIsWeb) {
                    webImageBytes = await file.readAsBytes();
                  } else {
                    pickedImage = File(file.path);
                  }
                  if (mounted) setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============ DISTRICT DIALOG ============
  void showDistrictDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text("Select Districts"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  children: bangladeshDistricts.map((district) {
                    return CheckboxListTile(
                      title: Text(district),
                      value: selectedDistricts.contains(district),
                      onChanged: (value) {
                        dialogSetState(() {
                          if (value == true) {
                            if (!selectedDistricts.contains(district)) {
                              selectedDistricts.add(district);
                            }
                          } else {
                            selectedDistricts.remove(district);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDistrict(String district) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove District"),
        content: Text("Are you sure you want to remove $district?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => selectedDistricts.remove(district));
      _showSnackBar("$district removed", Colors.green);
    }
  }

  // ============ SNACK HELPER ============
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  // ============ VALIDATION ============
  // ✅ CHANGED: "New User Name" and "New Password" are now OPTIONAL.
  //            If left blank, the old values will be reused.
  bool _validateForm() {
    if (fullNameController.text.isEmpty) {
      _showSnackBar("Please enter full name", Colors.orange);
      return false;
    }
    if (oldPasswordController.text.isEmpty) {
      _showSnackBar("Please enter old password", Colors.orange);
      return false;
    }
    if (locationTextController.text.isEmpty) {
      _showSnackBar("Please select location", Colors.orange);
      return false;
    }
    return true;
  }

  // ============ SUBMIT FORM ============
  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => isUpdating = true);

    // ✅ CHANGED: Fall back to the old values if the new ones are empty.
    final String effectiveNewName = nameController.text.trim().isNotEmpty
        ? nameController.text.trim()
        : oldNameController.text.trim();

    final String effectiveNewPassword =
        passwordController.text.trim().isNotEmpty
            ? passwordController.text.trim()
            : oldPasswordController.text.trim();

    try {
      // 1) Verify identity
      final logInUri = Uri.parse("${baseURL.Urls().baseURL}auth/login");
      final logInResponse = await http.post(
        logInUri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userName": oldNameController.text.trim(),
          "password": oldPasswordController.text.trim(),
        }),
      );

      if (logInResponse.statusCode != 200) {
        _showSnackBar("Invalid credential", Colors.red);
        setState(() => isUpdating = false);
        return;
      }

      final decoded = jsonDecode(logInResponse.body);
      final String? token = decoded["token"];
      final String? userId = decoded["userId"];

      if (token == null || userId == null) {
        _showSnackBar("Login failed: missing token", Colors.red);
        setState(() => isUpdating = false);
        return;
      }

      // 2) Update user basics (name, fullName, password, image)
      final uri = Uri.parse("${baseURL.Urls().baseURL}user/update/$userId");
      var request = http.MultipartRequest("PUT", uri);
      request.headers['Authorization'] = 'Bearer $token';

      // ✅ Use the effective (fallback) values here.
      request.fields["name"] = effectiveNewName;
      request.fields["FullName"] = fullNameController.text.trim();
      request.fields["password"] = effectiveNewPassword;

      final imageFindingUri =
          Uri.parse("${baseURL.Urls().baseURL}user/search?userId=$userId");
      final imageFindingResponse = await http.get(
        imageFindingUri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (imageFindingResponse.statusCode == 200) {
        final imageFindingData = jsonDecode(imageFindingResponse.body);
        final String? profileImageId = imageFindingData["profileImageId"];
        if (profileImageId != null && profileImageId.isNotEmpty) {
          request.fields["profileImageId"] = profileImageId;
        }
      }

      if (kIsWeb && webImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webImageBytes!,
            filename: '${effectiveNewName}.png',
            contentType: http.MediaType('image', 'png'),
          ),
        );
      } else if (!kIsWeb && pickedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("file", pickedImage!.path),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 3) Contact info
        await _updateContactInfo(userId, token);

        // 4) Location info
        await _updateLocationInfo(userId, token);

        // 5) Center admin districts/admins/advocates
        await _updateCenterAdminInfo(userId, token);

        _showSnackBar("Profile updated successfully 🎉", Colors.green);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => showForm = false);
        });
      } else {
        _showSnackBar("Update failed: $responseBody", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _updateContactInfo(String userId, String token) async {
    final contactInfoUri = Uri.parse(
        "${baseURL.Urls().baseURL}user/contact-info/user?userId=$userId");
    final response = await http.get(
      contactInfoUri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String contactInfoId = data["id"];
      final updateUri = Uri.parse(
          "${baseURL.Urls().baseURL}user/contact-info/update?userId=$userId&contactInfoId=$contactInfoId");
      await http.put(
        updateUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "email": emailController.text.isNotEmpty
              ? emailController.text.trim()
              : null,
          "phone": phoneController.text.isNotEmpty
              ? phoneController.text.trim()
              : null,
        }),
      );
    } else {
      final addUri = Uri.parse(
          "${baseURL.Urls().baseURL}user/contact-info/add?userId=$userId");
      await http.post(
        addUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "email": emailController.text.isNotEmpty
              ? emailController.text.trim()
              : null,
          "phone": phoneController.text.isNotEmpty
              ? phoneController.text.trim()
              : null,
        }),
      );
    }
  }

  Future<void> _updateLocationInfo(String userId, String token) async {
    final locationUri = Uri.parse(
        "${baseURL.Urls().baseURL}userLocation/findByUserId/$userId");
    final response = await http.get(
      locationUri,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String locationInfoId = data["id"];
      final updateUri = Uri.parse(
          "${baseURL.Urls().baseURL}userLocation/update/$locationInfoId?userId=$userId");
      await http.put(
        updateUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "locationName": locationTextController.text.trim(),
          "lattitude": latitude,
          "longitude": longitude,
        }),
      );
    } else {
      final addUri = Uri.parse("${baseURL.Urls().baseURL}userLocation/add");
      await http.post(
        addUri,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "userId": userId,
          "locationName": locationTextController.text.trim(),
          "lattitude": latitude,
          "longitude": longitude,
        }),
      );
    }
  }

  Future<void> _updateCenterAdminInfo(String userId, String token) async {
    final url = "${baseURL.Urls().baseURL}center-admin/by-user/$userId";
    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final centerAdminId = data["id"];

      await http.put(
        Uri.parse(
            "${baseURL.Urls().baseURL}center-admin/update/$centerAdminId/$userId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "userId": userId,
          "districts": selectedDistricts,
          "admins": admins,
          "advocates": advocates,
        }),
      );
    }
  }

  // ============ UI COMPONENTS ============
  Widget _buildOpenFormButton() {
    return GestureDetector(
      onTap: () => setState(() => showForm = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 18 : 24,
            vertical: _isMobile ? 12 : 14,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(_isMobile ? 6 : 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit,
                    color: Colors.blue, size: _isMobile ? 18 : 20),
              ),
              SizedBox(width: _isMobile ? 8 : 12),
              Text(
                'Update profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: _isMobile ? 14 : 16,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward,
                  color: Colors.white, size: _isMobile ? 16 : 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedForm() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      bottom: showForm ? 0 : -MediaQuery.of(context).size.height,
      left: 0,
      right: 0,
      height: _formHeight,
      child: IgnorePointer(
        ignoring: !showForm,
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: showForm ? 1 : 0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 100),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -5)),
              ],
            ),
            child: Column(
              children: [
                _buildDragHandle(),
                _buildFormHeader(),
                Expanded(child: _buildFormContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 10) setState(() => showForm = false);
      },
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(_isMobile ? 8 : 10),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.edit,
                      color: Colors.blue, size: _isMobile ? 20 : 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Update your data',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: _isMobile ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => showForm = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: _horizontalPadding,
        right: _horizontalPadding,
        top: 20,
      ),
      child: Column(
        children: [
          _buildProfileImage(),
          const SizedBox(height: 24),
          _buildTextField(
            controller: oldNameController,
            label: "Old user name",
            icon: Icons.person_outline,
            readOnly: true,
            focusNode: _oldNameFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: nameController,
            label: "New User Name (optional)",
            icon: Icons.person,
            hint: "Leave blank to keep current",
            focusNode: _nameFocus,
            nextFocus: _fullNameFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: fullNameController,
            label: "New Full Name",
            icon: Icons.badge_outlined,
            hint: "Write your full name",
            focusNode: _fullNameFocus,
            nextFocus: _oldPasswordFocus,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: oldPasswordController,
            label: "Old password",
            isVisible: _showOldPassword,
            onToggle: () =>
                setState(() => _showOldPassword = !_showOldPassword),
            focusNode: _oldPasswordFocus,
            nextFocus: _newPasswordFocus,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: passwordController,
            label: "New Password (optional)",
            isVisible: _showPassword,
            onToggle: () => setState(() => _showPassword = !_showPassword),
            focusNode: _newPasswordFocus,
            nextFocus: _emailFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: emailController,
            label: "Email",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            focusNode: _emailFocus,
            nextFocus: _phoneFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: phoneController,
            label: "Mobile Number",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            focusNode: _phoneFocus,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: locationTextController,
            label: "Location",
            icon: Icons.location_on_outlined,
            readOnly: true,
            onTap: () =>
                _showSnackBar("Select from the map", Colors.blue),
          ),
          const SizedBox(height: 20),
          _buildDistrictSection(),
          const SizedBox(height: 30),
          _buildSubmitButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDistrictSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_city, color: Colors.blue, size: 22),
            const SizedBox(width: 12),
            const Text(
              "Districts",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: showDistrictDialog,
              child: const Text("Select"),
            ),
          ],
        ),
        if (selectedDistricts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 34),
            child: Text(
              "No districts selected",
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedDistricts.map((d) {
                return Chip(
                  label: Text(d),
                  deleteIconColor: Colors.blue,
                  onDeleted: () => _confirmDeleteDistrict(d),
                  backgroundColor: Colors.blue.withOpacity(0.08),
                  labelStyle: const TextStyle(color: Colors.blue),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: GestureDetector(
        onTap: pickImage,
        child: Container(
          width: _isMobile ? 90 : 110,
          height: _isMobile ? 90 : 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
            boxShadow: [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (pickedImage != null && !kIsWeb)
                  Image.file(pickedImage!, fit: BoxFit.cover)
                else if (webImageBytes != null && kIsWeb)
                  Image.memory(webImageBytes!, fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.white,
                    child: Icon(Icons.person_add_alt_1,
                        size: _isMobile ? 40 : 50, color: Colors.blue),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Colors.blue, Colors.blueAccent]),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(55),
                        bottomRight: Radius.circular(55),
                      ),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        focusNode: focusNode,
        onTap: onTap,
        textInputAction:
            nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onEditingComplete: () {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        style: TextStyle(fontSize: _isMobile ? 14 : 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.blue, fontSize: _isMobile ? 13 : 14),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon:
              Icon(icon, color: Colors.blue, size: _isMobile ? 20 : 24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 16 : 20,
            vertical: _isMobile ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggle,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        focusNode: focusNode,
        textInputAction:
            nextFocus != null ? TextInputAction.next : TextInputAction.done,
        onEditingComplete: () {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        style: TextStyle(fontSize: _isMobile ? 14 : 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.blue, fontSize: _isMobile ? 13 : 14),
          prefixIcon: Icon(Icons.lock_outline,
              color: Colors.blue, size: _isMobile ? 20 : 24),
          suffixIcon: IconButton(
            icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.blue, size: _isMobile ? 20 : 24),
            onPressed: onToggle,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 16 : 20,
            vertical: _isMobile ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isUpdating
            ? null
            : () async {
                FocusScope.of(context).unfocus();
                _showLoadingDialog();
                await _submitForm();
                if (mounted) Navigator.pop(context);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: _isMobile ? 14 : 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
        ),
        child: isUpdating
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(
                'Update',
                style: TextStyle(
                    fontSize: _isMobile ? 15 : 16,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
            SizedBox(height: 16),
            Text("Updating...",
                style: TextStyle(fontSize: 16, color: Colors.blue)),
            SizedBox(height: 8),
            Text("Please wait",
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          "Update profile",
          style: TextStyle(fontSize: _isMobile ? 18 : 20),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: lat_lng.LatLng(23.8103, 90.4125),
                    initialZoom: 13.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              );
            },
          ),

          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6)
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: _isMobile ? 12 : 16,
            right: _isMobile ? 12 : 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue, size: 20),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        style: TextStyle(fontSize: _isMobile ? 14 : 16),
                        decoration: const InputDecoration(
                          hintText: "Search location...",
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        onSubmitted: (value) => searchPlace(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(30)),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: searchPlace,
                        iconSize: 18,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 20,
            right: _isMobile ? 12 : 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_devicePosition != null) {
                  setState(() {
                    _selectedPosition = _devicePosition;
                    locationTextController.text = _selectedPlaceName ?? '';
                    _updateMarkers();
                  });
                  mapController.move(_devicePosition!, 15.0);
                }
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          if (!showForm)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(child: _buildOpenFormButton()),
            ),

          _buildAnimatedForm(),
        ],
      ),
    );
  }
}