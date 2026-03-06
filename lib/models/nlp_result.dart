class NLPResult {
  final int? resultID;
  final int entryID;
  final String emotion;
  final double confidence;

  NLPResult({
    this.resultID,
    required this.entryID,
    required this.emotion,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'resultID': resultID,
      'entryID': entryID,
      'emotion': emotion,
      'confidence': confidence,
    };
  }

  factory NLPResult.fromMap(Map<String, dynamic> map) {
    return NLPResult(
      resultID: map['resultID'],
      entryID: map['entryID'],
      emotion: map['emotion'],
      confidence: map['confidence'],
    );
  }
}
