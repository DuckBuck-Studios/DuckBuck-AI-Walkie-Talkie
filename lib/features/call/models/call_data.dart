class CallData {
  final String callerName;
  final String? callerPhotoUrl;

  CallData({
    required this.callerName,
    this.callerPhotoUrl,
  });

  factory CallData.fromMap(Map<String, dynamic> map) {
    return CallData(
      callerName: map['callerName'] ?? 'Unknown Caller',
      callerPhotoUrl: map['callerPhotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
    };
  }
}
