import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Firestore operations
class FirebaseDatabaseService {
  final FirebaseFirestore _firestore;

  /// Creates a new FirebaseDatabaseService instance with optional custom configuration
  FirebaseDatabaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? _configureFirestore();

  /// Configure Firestore with custom settings and connect to "duckbuck" database
  static FirebaseFirestore _configureFirestore() {    
    // Access the Firebase app instance
    final app = Firebase.app();
    
    // Create FirebaseFirestoreSettings object with persistence enabled
    final settings = Settings(
      persistenceEnabled: true,
    );

    // Get Firestore instance with specific database ID
    final instance = FirebaseFirestore.instanceFor(
      app: app,
      databaseId: 'duckbuck', // Connect to "duckbuck" database
    );

    // Apply the settings to the instance
    instance.settings = settings;
    
    // Log connection confirmation
    debugPrint('🔥 FIREBASE: Connected to Firestore database: duckbuck');
    
    return instance;
  }

  /// Get the configured Firestore instance
  FirebaseFirestore get firestoreInstance => _firestore;

  /// Get a document from a collection
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      final docSnapshot =
          await _firestore.collection(collection).doc(documentId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return docSnapshot.data();
    } catch (e) {
      throw Exception('Failed to get document: ${e.toString()}');
    }
  }

  /// Add a new document to a collection
  Future<String> addDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    try {
      final docRef = await _firestore.collection(collection).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add document: ${e.toString()}');
    }
  }

  /// Set a document with a specific ID
  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = true,
    bool logOperation = false,
  }) async {
    try {
      if (logOperation) {
        debugPrint('🔥 FIREBASE: Setting document $documentId in $collection (merge: $merge)');
        debugPrint('🔥 FIREBASE: Document data: $data');
      }
      
      await _firestore.collection(collection).doc(documentId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!merge) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: merge));
      
      if (logOperation) {
        debugPrint('🔥 FIREBASE: Document set successfully');
      }
    } catch (e) {
      if (logOperation) {
        debugPrint('🔥 FIREBASE: Error setting document: ${e.toString()}');
      }
      throw Exception('Failed to set document: ${e.toString()}');
    }
  }

  
  /// Delete a document
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('Failed to delete document: ${e.toString()}');
    }
  }

  /// Get a stream of document changes
  Stream<DocumentSnapshot<Map<String, dynamic>>> documentStream({
    required String collection,
    required String documentId,
  }) {
    return _firestore.collection(collection).doc(documentId).snapshots();
  }

  /// Get a stream of collection changes
  Stream<QuerySnapshot<Map<String, dynamic>>> collectionStream({
    required String collection,
    Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>> query,
    )?
    queryBuilder,
  }) {
    CollectionReference<Map<String, dynamic>> collectionRef = _firestore
        .collection(collection);

    if (queryBuilder != null) {
      return queryBuilder(collectionRef).snapshots();
    }

    return collectionRef.snapshots();
  }

  /// Query documents in a collection by a builder function
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryDocumentsWithBuilder({
    required String collection,
    required Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>> query,
    )
    queryBuilder,
  }) async {
    try {
      final collectionRef = _firestore.collection(collection);
      final query = queryBuilder(collectionRef);
      final querySnapshot = await query.get();

      return querySnapshot.docs;
    } catch (e) {
      throw Exception('Failed to query documents: ${e.toString()}');
    }
  }
  
  /// Query documents in a collection by field conditions
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    String? field,
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic>? arrayContainsAny,
    List<dynamic>? whereIn,
    List<dynamic>? whereNotIn,
    String? orderBy,
    bool descending = false,
    int? limit,
    List<Map<String, dynamic>>? conditions,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collection);
      
      // Apply field conditions if provided
      if (field != null) {
        if (isEqualTo != null) {
          query = query.where(field, isEqualTo: isEqualTo);
        }
        if (isNotEqualTo != null) {
          query = query.where(field, isNotEqualTo: isNotEqualTo);
        }
        if (isLessThan != null) {
          query = query.where(field, isLessThan: isLessThan);
        }
        if (isLessThanOrEqualTo != null) {
          query = query.where(field, isLessThanOrEqualTo: isLessThanOrEqualTo);
        }
        if (isGreaterThan != null) {
          query = query.where(field, isGreaterThan: isGreaterThan);
        }
        if (isGreaterThanOrEqualTo != null) {
          query = query.where(field, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo);
        }
        if (arrayContains != null) {
          query = query.where(field, arrayContains: arrayContains);
        }
        if (arrayContainsAny != null) {
          query = query.where(field, arrayContainsAny: arrayContainsAny);
        }
        if (whereIn != null) {
          query = query.where(field, whereIn: whereIn);
        }
        if (whereNotIn != null) {
          query = query.where(field, whereNotIn: whereNotIn);
        }
      }
      
      // Apply additional conditions if provided
      if (conditions != null) {
        for (final condition in conditions) {
          final field = condition['field'] as String;
          final operator = condition['operator'] as String;
          final value = condition['value'];
          
          switch (operator) {
            case '==':
              query = query.where(field, isEqualTo: value);
              break;
            case '!=':
              query = query.where(field, isNotEqualTo: value);
              break;
            case '<':
              query = query.where(field, isLessThan: value);
              break;
            case '<=':
              query = query.where(field, isLessThanOrEqualTo: value);
              break;
            case '>':
              query = query.where(field, isGreaterThan: value);
              break;
            case '>=':
              query = query.where(field, isGreaterThanOrEqualTo: value);
              break;
            case 'array-contains':
              query = query.where(field, arrayContains: value);
              break;
            case 'array-contains-any':
              query = query.where(field, arrayContainsAny: value as List<dynamic>);
              break;
            case 'in':
              query = query.where(field, whereIn: value as List<dynamic>);
              break;
            case 'not-in':
              query = query.where(field, whereNotIn: value as List<dynamic>);
              break;
          }
        }
      }
      
      // Apply ordering if provided
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      
      // Apply limit if provided
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final querySnapshot = await query.get();
      
      // Return documents with their IDs included
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to query documents: ${e.toString()}');
    }
  }

  /// Query documents with pagination support
  Future<List<Map<String, dynamic>>> queryDocumentsWithPagination({
    required String collection,
    String? field,
    dynamic isEqualTo,
    String? orderBy,
    bool descending = false,
    int? limit,
    String? startAfterDocument,
    List<Map<String, dynamic>>? conditions,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collection);
      
      // Apply field conditions if provided
      if (field != null && isEqualTo != null) {
        query = query.where(field, isEqualTo: isEqualTo);
      }
      
      // Apply additional conditions if provided
      if (conditions != null) {
        for (final condition in conditions) {
          final field = condition['field'] as String;
          final operator = condition['operator'] as String;
          final value = condition['value'];
          
          switch (operator) {
            case '==':
              query = query.where(field, isEqualTo: value);
              break;
            case '!=':
              query = query.where(field, isNotEqualTo: value);
              break;
            case '<':
              query = query.where(field, isLessThan: value);
              break;
            case '<=':
              query = query.where(field, isLessThanOrEqualTo: value);
              break;
            case '>':
              query = query.where(field, isGreaterThan: value);
              break;
            case '>=':
              query = query.where(field, isGreaterThanOrEqualTo: value);
              break;
            case 'array-contains':
              query = query.where(field, arrayContains: value);
              break;
            case 'array-contains-any':
              query = query.where(field, arrayContainsAny: value as List<dynamic>);
              break;
            case 'in':
              query = query.where(field, whereIn: value as List<dynamic>);
              break;
            case 'not-in':
              query = query.where(field, whereNotIn: value as List<dynamic>);
              break;
          }
        }
      }
      
      // Apply ordering if provided
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      
      // Apply startAfter for pagination
      if (startAfterDocument != null) {
        final docSnapshot = await _firestore
            .collection(collection)
            .doc(startAfterDocument)
            .get();
            
        if (docSnapshot.exists) {
          query = query.startAfterDocument(docSnapshot);
        }
      }
      
      // Apply limit if provided
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final querySnapshot = await query.get();
      
      // Return documents with their IDs included
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to query documents with pagination: ${e.toString()}');
    }
  }

  /// Perform a batch write operation
  Future<void> batchWrite(
    Future<void> Function(WriteBatch batch) actions,
  ) async {
    try {
      final batch = _firestore.batch();
      await actions(batch);
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to perform batch write: ${e.toString()}');
    }
  }

  /// Perform a transaction
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) actions,
  ) async {
    try {
      return await _firestore.runTransaction((transaction) {
        return actions(transaction);
      });
    } catch (e) {
      throw Exception('Failed to run transaction: ${e.toString()}');
    }
  }

  /// Get a subcollection reference
  CollectionReference<Map<String, dynamic>> getSubcollection({
    required String collection,
    required String documentId,
    required String subcollection,
  }) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .collection(subcollection);
  }

  /// Get a document from a subcollection
  Future<Map<String, dynamic>?> getSubcollectionDocument({
    required String collection,
    required String documentId,
    required String subcollection,
    required String subcollectionDocumentId,
  }) async {
    try {
      final docSnapshot = await _firestore
          .collection(collection)
          .doc(documentId)
          .collection(subcollection)
          .doc(subcollectionDocumentId)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      return docSnapshot.data();
    } catch (e) {
      throw Exception('Failed to get subcollection document: ${e.toString()}');
    }
  }

  /// Set a document in a subcollection
  Future<void> setSubcollectionDocument({
    required String collection,
    required String documentId,
    required String subcollection,
    required String subcollectionDocumentId,
    required Map<String, dynamic> data,
    bool merge = true,
    bool logOperation = false,
  }) async {
    try {
      if (logOperation) {
        debugPrint('🔥 FIREBASE: Setting subcollection document $subcollectionDocumentId in $collection/$documentId/$subcollection (merge: $merge)');
        debugPrint('🔥 FIREBASE: Document data: $data');
      }
      
      await _firestore
          .collection(collection)
          .doc(documentId)
          .collection(subcollection)
          .doc(subcollectionDocumentId)
          .set({
            ...data,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!merge) 'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: merge));
      
      if (logOperation) {
        debugPrint('🔥 FIREBASE: Subcollection document set successfully');
      }
    } catch (e) {
      if (logOperation) {
        debugPrint('🔥 FIREBASE: Error setting subcollection document: ${e.toString()}');
      }
      throw Exception('Failed to set subcollection document: ${e.toString()}');
    }
  }
  
  /// Delete a document from a subcollection
  Future<void> deleteSubcollectionDocument({
    required String collection,
    required String documentId,
    required String subcollection,
    required String subcollectionDocumentId,
  }) async {
    try {
      await _firestore
          .collection(collection)
          .doc(documentId)
          .collection(subcollection)
          .doc(subcollectionDocumentId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete subcollection document: ${e.toString()}');
    }
  }
  
  /// Get a stream of subcollection document changes
  Stream<DocumentSnapshot<Map<String, dynamic>>> subcollectionDocumentStream({
    required String collection,
    required String documentId,
    required String subcollection,
    required String subcollectionDocumentId,
  }) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .collection(subcollection)
        .doc(subcollectionDocumentId)
        .snapshots();
  }
  
  /// Get a stream of subcollection changes
  Stream<QuerySnapshot<Map<String, dynamic>>> subcollectionStream({
    required String collection,
    required String documentId,
    required String subcollection,
    Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>> query,
    )? queryBuilder,
  }) {
    CollectionReference<Map<String, dynamic>> subcollectionRef = _firestore
        .collection(collection)
        .doc(documentId)
        .collection(subcollection);

    if (queryBuilder != null) {
      return queryBuilder(subcollectionRef).snapshots();
    }

    return subcollectionRef.snapshots();
  }
  
  /// Query documents in a subcollection by field conditions
  Future<List<Map<String, dynamic>>> querySubcollectionDocuments({
    required String collection,
    required String documentId,
    required String subcollection,
    String? field,
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<dynamic>? arrayContainsAny,
    List<dynamic>? whereIn,
    List<dynamic>? whereNotIn,
    String? orderBy,
    bool descending = false,
    int? limit,
    List<Map<String, dynamic>>? conditions,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(collection)
          .doc(documentId)
          .collection(subcollection);
      
      // Apply field conditions if provided
      if (field != null) {
        if (isEqualTo != null) {
          query = query.where(field, isEqualTo: isEqualTo);
        }
        if (isNotEqualTo != null) {
          query = query.where(field, isNotEqualTo: isNotEqualTo);
        }
        if (isLessThan != null) {
          query = query.where(field, isLessThan: isLessThan);
        }
        if (isLessThanOrEqualTo != null) {
          query = query.where(field, isLessThanOrEqualTo: isLessThanOrEqualTo);
        }
        if (isGreaterThan != null) {
          query = query.where(field, isGreaterThan: isGreaterThan);
        }
        if (isGreaterThanOrEqualTo != null) {
          query = query.where(field, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo);
        }
        if (arrayContains != null) {
          query = query.where(field, arrayContains: arrayContains);
        }
        if (arrayContainsAny != null) {
          query = query.where(field, arrayContainsAny: arrayContainsAny);
        }
        if (whereIn != null) {
          query = query.where(field, whereIn: whereIn);
        }
        if (whereNotIn != null) {
          query = query.where(field, whereNotIn: whereNotIn);
        }
      }
      
      // Apply additional conditions if provided
      if (conditions != null) {
        for (final condition in conditions) {
          final field = condition['field'] as String;
          final operator = condition['operator'] as String;
          final value = condition['value'];
          
          switch (operator) {
            case '==':
              query = query.where(field, isEqualTo: value);
              break;
            case '!=':
              query = query.where(field, isNotEqualTo: value);
              break;
            case '<':
              query = query.where(field, isLessThan: value);
              break;
            case '<=':
              query = query.where(field, isLessThanOrEqualTo: value);
              break;
            case '>':
              query = query.where(field, isGreaterThan: value);
              break;
            case '>=':
              query = query.where(field, isGreaterThanOrEqualTo: value);
              break;
            case 'array-contains':
              query = query.where(field, arrayContains: value);
              break;
            case 'array-contains-any':
              query = query.where(field, arrayContainsAny: value as List<dynamic>);
              break;
            case 'in':
              query = query.where(field, whereIn: value as List<dynamic>);
              break;
            case 'not-in':
              query = query.where(field, whereNotIn: value as List<dynamic>);
              break;
          }
        }
      }
      
      // Apply ordering if provided
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      
      // Apply limit if provided
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final querySnapshot = await query.get();
      
      // Return documents with their IDs included
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to query subcollection documents: ${e.toString()}');
    }
  }
}
