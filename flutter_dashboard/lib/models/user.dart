class User {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profileImageUrl;
  final Organization? organization;
  final DateTime createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.profileImageUrl,
    this.organization,
    required this.createdAt,
    this.updatedAt,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username;
  }

  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle organization from the organizations array (backend format)
    Organization? org;
    if (json['organizations'] != null &&
        json['organizations'] is List &&
        (json['organizations'] as List).isNotEmpty) {
      final orgList = json['organizations'] as List;
      final orgData = orgList.first as Map<String, dynamic>;
      org = Organization(
        id: orgData['organization_id']?.toString() ?? '',
        name: orgData['organization_name'] ?? '',
        description: null,
        createdAt: DateTime.parse(
          orgData['joined_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
    } else if (json['organization'] != null) {
      org = Organization.fromJson(json['organization']);
    }

    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      profileImageUrl: json['profile_picture_url'] ?? json['profile_image_url'],
      organization: org,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'profile_image_url': profileImageUrl,
      'organization': organization?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Organization {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  String get displayName => name;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
