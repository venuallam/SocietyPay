import 'package:cloud_firestore/cloud_firestore.dart';

enum ContactCategory { emergency, repairs, nearby }

class ContactModel {
  final String id;
  final String name;
  final String phone;
  final ContactCategory category;
  final bool isDefault;
  final String addedBy;
  final DateTime createdAt;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    this.isDefault = false,
    required this.addedBy,
    required this.createdAt,
  });

  factory ContactModel.fromDoc(
      DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ContactModel(
      id:       doc.id,
      name:     d['name'] as String? ?? '',
      phone:    d['phone'] as String? ?? '',
      category: ContactCategory.values.firstWhere(
              (e) => e.name ==
              (d['category'] as String? ?? 'emergency'),
          orElse: () => ContactCategory.emergency),
      isDefault:
      d['isDefault'] as bool? ?? false,
      addedBy:
      d['addedBy'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'phone':     phone,
    'category':  category.name,
    'isDefault': isDefault,
    'addedBy':   addedBy,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  String get categoryLabel => switch (category) {
    ContactCategory.emergency => 'Emergency',
    ContactCategory.repairs   => 'Society Repairs',
    ContactCategory.nearby    => 'Nearby Services',
  };

  String get categoryIcon => switch (category) {
    ContactCategory.emergency => '🚨',
    ContactCategory.repairs   => '🔧',
    ContactCategory.nearby    => '🏥',
  };
}

class ContactSuggestionModel {
  final String id;
  final String name;
  final String phone;
  final ContactCategory category;
  final String suggestedBy;
  final String suggestedByName;
  final String status; // pending/approved/rejected
  final DateTime createdAt;

  const ContactSuggestionModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.category,
    required this.suggestedBy,
    required this.suggestedByName,
    required this.status,
    required this.createdAt,
  });

  factory ContactSuggestionModel.fromDoc(
      DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ContactSuggestionModel(
      id:   doc.id,
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      category: ContactCategory.values.firstWhere(
              (e) => e.name ==
              (d['category'] as String?
                  ?? 'nearby'),
          orElse: () => ContactCategory.nearby),
      suggestedBy:
      d['suggestedBy'] as String? ?? '',
      suggestedByName:
      d['suggestedByName'] as String? ?? '',
      status:
      d['status'] as String? ?? 'pending',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':             name,
    'phone':            phone,
    'category':         category.name,
    'suggestedBy':      suggestedBy,
    'suggestedByName':  suggestedByName,
    'status':           status,
    'createdAt':
    Timestamp.fromDate(createdAt),
  };
}