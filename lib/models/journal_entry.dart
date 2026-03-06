class JournalEntry {
  final int? entryID;
  final int userID;
  final String text;
  final String date;

  JournalEntry({
    this.entryID,
    required this.userID,
    required this.text,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'entryID': entryID,
      'userID': userID,
      'text': text,
      'date': date,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      entryID: map['entryID'],
      userID: map['userID'],
      text: map['text'],
      date: map['date'],
    );
  }
}
