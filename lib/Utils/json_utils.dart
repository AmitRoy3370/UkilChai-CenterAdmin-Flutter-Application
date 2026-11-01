// lib/Utils/json_utils.dart
import 'dart:convert';

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

List<String> asStringList(dynamic v) {
  if (v == null) return <String>[];
  if (v is List) return v.map((e) => e.toString()).toList();
  return <String>[];
}

Map<String, dynamic> decodeMap(String body) {
  if (body.isEmpty) throw Exception("Empty response from server");
  final d = jsonDecode(body);
  if (d is Map<String, dynamic>) return d;
  throw Exception("Expected JSON object, got ${d.runtimeType}");
}

List<dynamic> decodeList(String body) {
  if (body.isEmpty) return <dynamic>[];
  final d = jsonDecode(body);
  return d is List ? d : <dynamic>[];
}