// ==========================================
// File: models.dart
// Description: Data models representing the ERD
// ==========================================

// 1. User Model
class User {
  int? userID;
  String name;
  String email;
  String password;

  User({this.userID, required this.name, required this.email, required this.password});

  // Convert User object to a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'name': name,
      'email': email,
      'password': password,
    };
  }

  // Create a User object from a SQLite Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userID: map['userID'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
    );
  }
}

// 2. Journal Entry Model
class JournalEntry {
  int? entryID;
  int userID;
  String text;
  String date;

  JournalEntry({this.entryID, required this.userID, required this.text, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'entryID': entryID,
      'userID': userID,
      'text': text,
      'date': date,
    };
  }
}

// 3. Assessment Model (e.g., PHQ-9, GAD-7)
class Assessment {
  int? assessID;
  int userID;
  String scaleType; 
  int score;

  Assessment({this.assessID, required this.userID, required this.scaleType, required this.score});

  Map<String, dynamic> toMap() {
    return {
      'assessID': assessID,
      'userID': userID,
      'scaleType': scaleType,
      'score': score,
    };
  }
}

// 4. NLP Result Model
class NLPResult {
  int? resultID;
  int entryID;
  String emotion;
  double confidence;

  NLPResult({this.resultID, required this.entryID, required this.emotion, required this.confidence});

  Map<String, dynamic> toMap() {
    return {
      'resultID': resultID,
      'entryID': entryID,
      'emotion': emotion,
      'confidence': confidence,
    };
  }
}