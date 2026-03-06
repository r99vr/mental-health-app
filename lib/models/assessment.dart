class Assessment {
  final int? assessID;
  final int userID;
  final String scaleType;
  final int score;
  final String date;

  Assessment({
    this.assessID,
    required this.userID,
    required this.scaleType,
    required this.score,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'assessID': assessID,
      'userID': userID,
      'scaleType': scaleType,
      'score': score,
      'date': date,
    };
  }

  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      assessID: map['assessID'],
      userID: map['userID'],
      scaleType: map['scaleType'],
      score: map['score'],
      date: map['date'],
    );
  }
}
