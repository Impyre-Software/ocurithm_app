import '../../../Clinics/data/model/clinics_model.dart';

class LoginModel {
  LoginModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final User? user;

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      accessToken: json["accessToken"],
      refreshToken: json["refreshToken"],
      expiresIn: json["expiresIn"],
      user: json["user"] == null ? null : User.fromJson(json["user"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "accessToken": accessToken,
    "refreshToken": refreshToken,
    "expiresIn": expiresIn,
    "user": user?.toJson(),
  };
}

class User {
  User({
    required this.id,
    required this.name,
    required this.userType,
    required this.clinic,
    required this.capabilities,
    this.image,
  });

  final String? id;
  final String? name;
  final String? userType;
  final Clinic? clinic;
  final List<String> capabilities;
  final String? image;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawCaps = json["capabilities"];

    List<String> parsedCapabilities = [];

    if (rawCaps != null && rawCaps is List) {
      parsedCapabilities = rawCaps.map<String>((cap) {

        // Case 1 → Already String
        if (cap is String) {
          return cap;
        }

        // Case 2 → Object → Extract name
        if (cap is Map<String, dynamic>) {
          return cap["name"] ?? "";
        }

        // Fallback safety
        return "";
      }).where((cap) => cap.isNotEmpty).toList();
    }

    return User(
      id: json["id"],
      name: json["name"],
      userType: json["userType"],
      clinic: json["clinic"] == null ? null : Clinic.fromJson(json["clinic"]),
      capabilities: parsedCapabilities,
      image: json["image"],
    );
  }


  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "userType": userType,
    "clinic": clinic?.toJson(),
    "capabilities": capabilities.map((x) => x).toList(),
    "image": image,
  };
}

class Capability {
  Capability({
    required this.isActive,
    required this.name,
    required this.id,
    this.label,
    this.description,
    this.group,
    this.order,
  });

  final bool? isActive;
  final String? name;
  final String? id;

  /// Editor title, e.g. "Book appointments".
  final String? label;

  /// What holding it unlocks, written for the admin granting it.
  final String? description;

  /// Area key the editor groups by (see [CapabilityCatalog.groups]).
  final String? group;

  /// Position inside its area.
  final num? order;

  /// [label] when the API sent one, otherwise the name split into words:
  /// `manageExaminationTypes` -> "Manage Examination Types".
  String get title {
    if (label != null && label!.trim().isNotEmpty) return label!;
    final words = (name ?? '').replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return words.isEmpty ? '' : words[0].toUpperCase() + words.substring(1);
  }

  factory Capability.fromJson(Map<String, dynamic> json) {
    return Capability(
      isActive: json["isActive"],
      name: json["name"],
      id: json["id"],
      label: json["label"],
      description: json["description"],
      group: json["group"],
      order: json["order"],
    );
  }

  Map<String, dynamic> toJson() => {
        "isActive": isActive,
        "name": name,
        "id": id,
        "label": label,
        "description": description,
        "group": group,
        "order": order,
      };
}

/// Areas (display order) and one-click task bundles for the capability editor,
/// from `GET /capabilities/catalog`.
class CapabilityCatalog {
  const CapabilityCatalog({required this.groups, required this.bundles});

  final List<CapabilityGroup> groups;
  final List<CapabilityBundle> bundles;

  factory CapabilityCatalog.fromJson(Map<String, dynamic> json) {
    return CapabilityCatalog(
      groups: (json['groups'] as List? ?? const [])
          .map((x) => CapabilityGroup.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      bundles: (json['bundles'] as List? ?? const [])
          .map((x) => CapabilityBundle.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
    );
  }
}

class CapabilityGroup {
  const CapabilityGroup({required this.key, required this.label});

  final String key;
  final String label;

  factory CapabilityGroup.fromJson(Map<String, dynamic> json) =>
      CapabilityGroup(key: '${json['key']}', label: '${json['label']}');
}

class CapabilityBundle {
  const CapabilityBundle({
    required this.key,
    required this.label,
    required this.description,
    required this.capabilities,
  });

  final String key;
  final String label;
  final String description;

  /// Capability **names**.
  final List<String> capabilities;

  factory CapabilityBundle.fromJson(Map<String, dynamic> json) =>
      CapabilityBundle(
        key: '${json['key']}',
        label: '${json['label']}',
        description: '${json['description'] ?? ''}',
        capabilities: (json['capabilities'] as List? ?? const [])
            .map((x) => '$x')
            .toList(),
      );
}
