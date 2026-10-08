// RegistrationPage.dart — Center Admin, responsive + Google Sign-In
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/BaseURL.dart' as baseURL;
import '../Auth/AuthService.dart' as authService;

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController googlePasswordController =
      TextEditingController();
  final TextEditingController confirmGooglePasswordController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationTextController = TextEditingController();

  List<String> selectedDistricts = [];

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

  bool _showPassword = false;
  bool _showGooglePassword = false;
  bool _showConfirmGooglePassword = false;
  bool _isGoogleSignInLoading = false;
  bool _showSuccessMessage = false;

  lat_lng.LatLng? _devicePosition;
  lat_lng.LatLng? _selectedPosition;
  String? _selectedPlaceName;
  List<Marker> _markers = [];
  bool showForm = false;
  File? pickedImage;
  Uint8List? webImageBytes;
  double lattitude = 0.0;
  double longititude = 0.0;

  final MapController mapController = MapController();
  late GoogleSignIn _googleSignIn;

  Stream<Position>? _positionStream;

  static const String _webClientId =
      '556137802637-se4ttcor4s9hnqsmacaeo4f96uvl8955.apps.googleusercontent.com';

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
    if (screenHeight < 700) return screenHeight * 0.95;
    return screenHeight * 0.90;
  }

  double get _horizontalPadding {
    if (_isDesktop) return 24;
    if (_isTablet) return 20;
    return 14;
  }

  double get _maxContentWidth {
    if (_isDesktop) return 500;
    if (_isTablet) return 600;
    return double.infinity;
  }

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    searchController.dispose();
    nameController.dispose();
    fullNameController.dispose();
    passwordController.dispose();
    googlePasswordController.dispose();
    confirmGooglePasswordController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationTextController.dispose();
    super.dispose();
  }

  void _initializeGoogleSignIn() {
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        clientId: _webClientId,
        scopes: ['email', 'profile', 'openid'],
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile', 'openid'],
      );
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

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied forever")),
        );
      }
      return;
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
      position.latitude,
      position.longitude,
    );
    String placeName = await getAddressFromLatLng(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _devicePosition = newPos;
      if (_selectedPosition == null) {
        _selectedPosition = newPos;
        _selectedPlaceName = placeName;
        lattitude = position.latitude;
        longititude = position.longitude;
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
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          double lat = double.parse(data[0]['lat']);
          double lng = double.parse(data[0]['lon']);
          lattitude = lat;
          longititude = lng;
          pos = lat_lng.LatLng(lat, lng);
          String name = data[0]['display_name'];
          setState(() {
            _selectedPosition = pos;
            _selectedPlaceName = name;
            locationTextController.text = _selectedPlaceName!;
            _updateMarkers();
          });
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
                await _pickImageFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take from camera'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromSource(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    XFile? file = await ImagePicker().pickImage(source: source);
    if (file != null) {
      if (kIsWeb) {
        webImageBytes = await file.readAsBytes();
      } else {
        pickedImage = File(file.path);
      }
      if (mounted) setState(() {});
    }
  }

  // ============ DISTRICT SELECTOR ============
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
                            selectedDistricts.add(district);
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

  // ============ CENTER ADMIN REGISTRATION ============
  Future<void> registerCenterAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt_token");
    final userId = prefs.getString("userId");

    if (kDebugMode) {
      print("userId in registerCenterAdmin :- $userId");
      print("token in registerCenterAdmin :- $token");
    }

    authService.AuthService.getUserId();

    final url = Uri.parse("${baseURL.Urls().baseURL}center-admin/add/$userId");

    final body = {
      "userId": userId,
      "admins": [],
      "advocates": [],
      "districts": selectedDistricts,
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Center Admin Registered")),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.body)),
      );
    }
  }

  // ============ SNACK HELPER ============
  void _showSnack(String message, [Color color = Colors.orange]) {
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

  // ============ NAVIGATION AFTER REGISTRATION ============
  void _closeRegistration() {
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ============ GOOGLE SIGN-IN ============
  Future<void> _signInWithGoogle() async {
    if (googlePasswordController.text.isEmpty) {
      _showSnack("Please enter a password");
      return;
    }
    if (googlePasswordController.text.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }
    if (googlePasswordController.text !=
        confirmGooglePasswordController.text) {
      _showSnack("Passwords do not match");
      return;
    }

    setState(() {
      _isGoogleSignInLoading = true;
      _showSuccessMessage = false;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isGoogleSignInLoading = false);
        return;
      }

      final String? email = googleUser.email;
      final String? displayName = googleUser.displayName;
      final String? photoUrl = googleUser.photoUrl;

      if (email == null) {
        throw Exception('Could not get email from Google');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      // Prefer the access token's userinfo endpoint for the freshest data.
      if (accessToken != null) {
        try {
          final userInfoResponse = await http.get(
            Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
            headers: {'Authorization': 'Bearer $accessToken'},
          );

          if (userInfoResponse.statusCode == 200) {
            final userInfo = jsonDecode(userInfoResponse.body);
            await _registerGoogleUser(
              email: userInfo['email'] ?? email,
              displayName: userInfo['name'] ?? displayName,
              photoUrl: userInfo['picture'] ?? photoUrl,
              accessToken: accessToken,
            );

            setState(() => _showSuccessMessage = true);
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) _closeRegistration();
            });
            return;
          }
        } catch (e) {
          print('⚠️ Error getting user info: $e');
        }
      }

      if (idToken != null) {
        await _registerGoogleUser(
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          accessToken: accessToken,
          idToken: idToken,
        );
        setState(() => _showSuccessMessage = true);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _closeRegistration();
        });
      } else if (accessToken != null) {
        await _registerGoogleUser(
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          accessToken: accessToken,
        );
        setState(() => _showSuccessMessage = true);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _closeRegistration();
        });
      } else {
        throw Exception('No authentication token available');
      }
    } catch (e) {
      _showSnack('Google Sign-In failed: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSignInLoading = false;
        });
      }
    }
  }

  Future<void> _registerGoogleUser({
    required String email,
    required String? displayName,
    required String? photoUrl,
    String? accessToken,
    String? idToken,
  }) async {
    Uint8List? profileImageBytes;
    if (photoUrl != null) {
      try {
        final response = await http.get(Uri.parse(photoUrl));
        if (response.statusCode == 200) {
          profileImageBytes = response.bodyBytes;
        }
      } catch (e) {
        print('Failed to download profile image: $e');
      }
    }

    final registrationUri = Uri.parse("${baseURL.Urls().baseURL}auth/register");
    final String userName = email.split('@').first;
    final String fullName = displayName ?? userName;

    var request = http.MultipartRequest("POST", registrationUri);
    request.fields["name"] = userName;
    request.fields["FullName"] = fullName;
    request.fields["password"] = googlePasswordController.text;
    request.fields["profileImageId"] = "profileImageId";

    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          profileImageBytes,
          filename: '$userName.png',
          contentType: http.MediaType('image', 'png'),
        ),
      );
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(responseBody);
      final String token = decoded["token"];
      final String userId = decoded["userId"];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("jwt_token", token);
      await prefs.setString("userId", userId);
      await prefs.setString("userEmail", email);
      await prefs.setString("userName", userName);
      await prefs.setString("fullName", fullName);

      // Contact info
      try {
        final contactInfoUri = Uri.parse(
            "${baseURL.Urls().baseURL}user/contact-info/add?userId=$userId");
        await http.post(
          contactInfoUri,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "userId": userId,
            "email": email,
            "phone": null,
          }),
        );
      } catch (e) {
        print('Contact info failed: $e');
      }

      // Location
      try {
        if (locationTextController.text.isNotEmpty) {
          final locationUri =
              Uri.parse("${baseURL.Urls().baseURL}userLocation/add");
          await http.post(
            locationUri,
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "userId": userId,
              "locationName": locationTextController.text.trim(),
              "lattitude": lattitude,
              "longitude": longititude,
            }),
          );
        }
      } catch (e) {
        print('Location failed: $e');
      }

      // Center-admin registration (using any districts the user selected)
      try {
        await registerCenterAdmin();
      } catch (e) {
        print('Center admin registration failed: $e');
      }

      _showSnack('🎉 Google Sign-In Successful! Welcome!', Colors.green);
    } else {
      throw Exception('Registration failed: $responseBody');
    }
  }

  // ============ GOOGLE PASSWORD DIALOG ============
  void _showGooglePasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding:
                EdgeInsets.symmetric(horizontal: _isMobile ? 16 : 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _isDesktop ? 450 : double.infinity,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Google Sign-In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please set a password for your account.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: googlePasswordController,
                      obscureText: !_showGooglePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Colors.blue),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showGooglePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _showGooglePassword = !_showGooglePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmGooglePasswordController,
                      obscureText: !_showConfirmGooglePassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Colors.blue),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmGooglePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _showConfirmGooglePassword =
                                  !_showConfirmGooglePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isMobile)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _signInWithGoogle();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Continue with Google'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _signInWithGoogle();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Continue with Google'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============ REGULAR REGISTRATION ============
  Future<void> _submitForm() async {
    try {
      final uri = Uri.parse("${baseURL.Urls().baseURL}auth/register");

      if (fullNameController.text.isEmpty) {
        _showSnack("Please enter fullName");
        return;
      } else if (nameController.text.isEmpty) {
        _showSnack("Please enter userName");
        return;
      } else if (passwordController.text.isEmpty) {
        _showSnack("Please enter password");
        return;
      } else if (emailController.text.isEmpty) {
        _showSnack("Please enter email");
        return;
      } else if (phoneController.text.isEmpty) {
        _showSnack("Please enter phone");
        return;
      } else if (locationTextController.text.isEmpty) {
        _showSnack("Please select location");
        return;
      } else if (selectedDistricts.isEmpty) {
        _showSnack("Please select at least one district");
        return;
      }

      var request = http.MultipartRequest("POST", uri);
      request.fields["name"] = nameController.text.trim();
      request.fields["FullName"] = fullNameController.text.trim();
      request.fields["password"] = passwordController.text.trim();
      request.fields["profileImageId"] = "profileImageId";

      if (kIsWeb && webImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webImageBytes!,
            filename: '${nameController.text.trim()}.png',
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
        final decoded = jsonDecode(responseBody);
        final String token = decoded["token"];
        final String userId = decoded["userId"];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", token);
        await prefs.setString("userId", userId);

        final _token = prefs.getString("jwt_token");
        if (_token == null || token.isEmpty) {
          print("No token found. User not logged in.");
          return;
        }

        // Contact info
        if (emailController.text.isNotEmpty || phoneController.text.isNotEmpty) {
          try {
            final url = Uri.parse(
                "${baseURL.Urls().baseURL}user/contact-info/add?userId=$userId");
            await http.post(
              url,
              headers: {
                "Authorization": "Bearer $_token",
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
          } catch (e) {
            print('Contact info failed: $e');
          }
        }

        // Location
        try {
          final locationUri =
              Uri.parse("${baseURL.Urls().baseURL}userLocation/add");
          await http.post(
            locationUri,
            headers: {
              "Authorization": "Bearer $_token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "userId": userId,
              "locationName": locationTextController.text.trim(),
              "lattitude": lattitude,
              "longitude": longititude,
            }),
          );
        } catch (e) {
          print('Location failed: $e');
        }

        _showSnack("Registration Successful", Colors.green);

        // Register as center admin
        await registerCenterAdmin();

        setState(() {
          showForm = false;
        });

        nameController.clear();
        fullNameController.clear();
        passwordController.clear();
        emailController.clear();
        phoneController.clear();
        locationTextController.clear();
        pickedImage = null;
        webImageBytes = null;
        selectedDistricts.clear();

        // Close registration form and return to login/home
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _closeRegistration();
        });
      } else {
        _showSnack("Registration failed: $responseBody", Colors.red);
      }
    } catch (e) {
      _showSnack(e.toString(), Colors.red);
    }
  }

  // ============ UI COMPONENTS ============

  Widget _buildOpenFormButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Regular Registration Button
          GestureDetector(
            onTap: () => setState(() => showForm = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()..scale(showForm ? 0.0 : 1.0),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 18 : 20,
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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
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
                      child: Icon(
                        Icons.app_registration,
                        color: Colors.blue,
                        size: _isMobile ? 18 : 20,
                      ),
                    ),
                    SizedBox(width: _isMobile ? 8 : 12),
                    Text(
                      'New Registration',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: _isMobile ? 14 : 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: _isMobile ? 14 : 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Google Sign-In Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            transform: Matrix4.identity()..scale(showForm ? 0.0 : 1.0),
            child: _buildGoogleSignInButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return GestureDetector(
      onTap: _isGoogleSignInLoading ? null : _showGooglePasswordDialog,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _isMobile ? 16 : 20,
          vertical: _isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isGoogleSignInLoading)
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              )
            else
              Image.network(
                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                height: 22,
                width: 22,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(width: 10),
            Text(
              _isGoogleSignInLoading
                  ? 'Signing in...'
                  : 'Continue with Google',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: _isMobile ? 13 : 14,
              ),
            ),
          ],
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
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxContentWidth),
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
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy > 10) {
                          setState(() => showForm = false);
                        }
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
                    ),
                    _buildFormHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom + 20,
                          left: _horizontalPadding,
                          right: _horizontalPadding,
                          top: 16,
                        ),
                        child: Column(
                          children: [
                            _buildFormField(
                              controller: fullNameController,
                              label: "Full Name",
                              icon: Icons.person_outline,
                              hint: "Write your full name",
                            ),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: nameController,
                              label: "User Name",
                              icon: Icons.person_outline,
                              hint: "Write your user name (unique)",
                            ),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: emailController,
                              label: "Email",
                              icon: Icons.email_outlined,
                              hint: "Your mail address",
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: phoneController,
                              label: "Mobile Number",
                              icon: Icons.phone_outlined,
                              hint: "01XXXXXXXXX",
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 14),
                            _buildPasswordField(),
                            const SizedBox(height: 14),
                            _buildFormField(
                              controller: locationTextController,
                              label: "Location",
                              icon: Icons.location_on_outlined,
                              hint: "Select from the map",
                              readOnly: true,
                            ),
                            const SizedBox(height: 18),

                            // District selector
                            _buildDistrictSelector(),
                            const SizedBox(height: 18),

                            _buildImagePicker(),
                            const SizedBox(height: 24),
                            _buildSubmitButton(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 14 : 20),
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.blue,
                    size: _isMobile ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Center Admin Registration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Fill with your data',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: _isMobile ? 11 : 12,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildDistrictSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 16,
        vertical: 12,
      ),
      child: Column(
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
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "No districts selected",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedDistricts
                    .map((d) => Chip(
                          label: Text(d),
                          deleteIconColor: Colors.blue,
                          onDeleted: () {
                            setState(() {
                              selectedDistricts.remove(d);
                            });
                          },
                          backgroundColor: Colors.blue.withOpacity(0.08),
                          labelStyle: const TextStyle(color: Colors.blue),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
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
        style: TextStyle(fontSize: _isMobile ? 14 : 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blue,
            fontSize: _isMobile ? 13 : 14,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.blue, size: _isMobile ? 20 : 24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 14 : 20,
            vertical: _isMobile ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: passwordController,
        obscureText: !_showPassword,
        style: TextStyle(fontSize: _isMobile ? 14 : 16),
        decoration: InputDecoration(
          labelText: "Password",
          labelStyle: TextStyle(
            color: Colors.blue,
            fontSize: _isMobile ? 13 : 14,
          ),
          hintText: "At least 6 characters",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.lock_outline,
              color: Colors.blue, size: _isMobile ? 20 : 24),
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility : Icons.visibility_off,
              color: Colors.blue,
              size: _isMobile ? 20 : 24,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 14 : 20,
            vertical: _isMobile ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final size = _isMobile ? 100.0 : 120.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Profile image",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: pickImage,
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: pickedImage == null && webImageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt,
                            size: _isMobile ? 32 : 40,
                            color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          "Add image",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    )
                  : kIsWeb
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            webImageBytes!,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            pickedImage!,
                            width: size,
                            height: size,
                            fit: BoxFit.cover,
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          FocusScope.of(context).unfocus();

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Registering...",
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Please wait",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          );

          await _submitForm();

          if (mounted) Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: _isMobile ? 14 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        child: Text(
          "Registration Complete",
          style: TextStyle(
            fontSize: _isMobile ? 15 : 16,
            fontWeight: FontWeight.bold,
          ),
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
          "Center Admin Registration",
          style: TextStyle(fontSize: _isMobile ? 16 : 20),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
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
                      userAgentPackageName: 'com.advocatechai.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              );
            },
          ),

          // Gradient overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // Search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: _isMobile ? 12 : 16,
            right: _isMobile ? 12 : 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        onSubmitted: (value) => searchPlace(),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(30),
                      ),
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

          // My location button
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

          // Open form button
          if (!showForm)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: _buildOpenFormButton(),
              ),
            ),

          // Animated form
          _buildAnimatedForm(),
        ],
      ),
    );
  }
}