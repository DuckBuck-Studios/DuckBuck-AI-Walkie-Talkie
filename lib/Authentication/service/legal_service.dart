import 'dart:convert';
import 'package:flutter/services.dart';

class LegalService {
  static Future<String> getLegalText(bool isTerms) async {
    try {
      final String filePath = isTerms
          ? 'lib/Authentication/data/terms_of_service.json'
          : 'lib/Authentication/data/privacy_policy.json';
      final String jsonString = await rootBundle.loadString(filePath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      final data = jsonData;
      final StringBuffer buffer = StringBuffer();
      
      for (var section in data['sections']) {
        buffer.writeln(section['title']);
        buffer.writeln();
        
        if (section['content'] is List) {
          for (var item in section['content']) {
            buffer.writeln('- $item');
          }
        } else {
          buffer.writeln(section['content']);
        }
        buffer.writeln();
      }
      
      return buffer.toString();
    } catch (e) {
      return 'Error loading legal text';
    }
  }
}