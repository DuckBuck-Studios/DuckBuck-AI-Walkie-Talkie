import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service for handling Firebase Firestore operations
class FirebaseDatabaseService {
  final FirebaseFirestore _firestore;

  /// Creates a new FirebaseDatabaseService instance with optional custom configuration
  FirebaseDatabaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? _configureFirestore();

  /// Configure Firestore with custom settings
  static FirebaseFirestore _configureFirestore() {
    // Get the default Firebase app
    final app = Firebase.app();

    // Create a FirebaseFirestoreSettings object with the custom database ID
    final settings = Settings(
      // Do NOT specify databaseId here as it's not supported this way
      persistenceEnabled: true,
    );

    // Get the Firestore instance and then configure it with settings
    final instance = FirebaseFirestore.instanceFor(
      app: app,
      databaseId: 'duckbuck',
    );

    // Apply the settings to the instance
    instance.settings = settings;

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
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!merge) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: merge));
    } catch (e) {
      throw Exception('Failed to set document: ${e.toString()}');
    }
  }

  /// Update an existing document
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update document: ${e.toString()}');
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

  /// Query documents in a collection
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryDocuments({
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
}
