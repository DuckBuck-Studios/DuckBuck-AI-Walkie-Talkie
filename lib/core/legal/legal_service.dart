import 'dart:convert';
import 'package:flutter/services.dart';

/// Model for legal document sections
class LegalSection {
  final String title;
  final String content;
  final String? animationKey; // Optional animation key for custom animations

  LegalSection({
    required this.title, 
    required this.content, 
    this.animationKey,
  });

  factory LegalSection.fromJson(Map<String, dynamic> json) {
    return LegalSection(
      title: json['title'] as String,
      content: json['content'] as String,
      animationKey: json['animationKey'] as String?,
    );
  }
}

/// Model for legal documents
class LegalDocument {
  final String version;
  final String lastUpdated;
  final String title;
  final List<LegalSection> sections;
  final String? animationType; // Animation type preference for this document

  LegalDocument({
    required this.version,
    required this.lastUpdated,
    required this.title,
    required this.sections,
    this.animationType,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      version: json['version'] as String,
      lastUpdated: json['lastUpdated'] as String,
      title: json['title'] as String,
      animationType: json['animationType'] as String?,
      sections:
          (json['sections'] as List)
              .map(
                (section) =>
                    LegalSection.fromJson(section as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

/// Service for handling legal documents
class LegalService {
  LegalService._();
  static final LegalService instance = LegalService._();

  Future<LegalDocument> getTermsOfService() async {
    return _loadLegalDocument('lib/core/legal/terms_of_service.json');
  }

  Future<LegalDocument> getPrivacyPolicy() async {
    return _loadLegalDocument('lib/core/legal/privacy_policy.json');
  }

  Future<LegalDocument> _loadLegalDocument(String path) async {
    // Load document immediately without artificial delay
    final jsonString = await rootBundle.loadString(path);
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return LegalDocument.fromJson(jsonMap);
  }
}
