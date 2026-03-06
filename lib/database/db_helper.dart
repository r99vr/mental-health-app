import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/journal_entry.dart';
import '../models/nlp_result.dart';
import '../models/assessment.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mental_health.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Users (
        userID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE JournalEntry (
        entryID INTEGER PRIMARY KEY AUTOINCREMENT,
        userID INTEGER NOT NULL,
        text TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (userID) REFERENCES Users (userID) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE NLPResults (
        resultID INTEGER PRIMARY KEY AUTOINCREMENT,
        entryID INTEGER NOT NULL,
        emotion TEXT NOT NULL,
        confidence REAL NOT NULL,
        FOREIGN KEY (entryID) REFERENCES JournalEntry (entryID) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Assessment (
        assessID INTEGER PRIMARY KEY AUTOINCREMENT,
        userID INTEGER NOT NULL,
        scaleType TEXT NOT NULL,
        score INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (userID) REFERENCES Users (userID) ON DELETE CASCADE
      )
    ''');
  }

  // --- Users ---
  Future<User> createUser(User user) async {
    final db = await instance.database;
    final id = await db.insert('Users', user.toMap());
    return User(
      userID: id,
      name: user.name,
      email: user.email,
      password: user.password,
    );
  }

  Future<User?> getUser(String email, String password) async {
    final db = await instance.database;
    final maps = await db.query(
      'Users',
      columns: ['userID', 'name', 'email', 'password'],
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<User?> getUserById(int id) async {
    final db = await instance.database;
    final maps = await db.query('Users', where: 'userID = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // --- Journal Entries ---
  Future<JournalEntry> createJournalEntry(JournalEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('JournalEntry', entry.toMap());
    return JournalEntry(
      entryID: id,
      userID: entry.userID,
      text: entry.text,
      date: entry.date,
    );
  }

  Future<List<JournalEntry>> getUserJournalEntries(int userID) async {
    final db = await instance.database;
    final maps = await db.query(
      'JournalEntry',
      where: 'userID = ?',
      whereArgs: [userID],
      orderBy: 'date DESC',
    );
    return maps.map((map) => JournalEntry.fromMap(map)).toList();
  }

  // --- NLP Results ---
  Future<NLPResult> createNLPResult(NLPResult result) async {
    final db = await instance.database;
    final id = await db.insert('NLPResults', result.toMap());
    return NLPResult(
      resultID: id,
      entryID: result.entryID,
      emotion: result.emotion,
      confidence: result.confidence,
    );
  }

  Future<List<NLPResult>> getUserEmotions(int userID) async {
    final db = await instance.database;
    // Join with JournalEntry to get user's results
    final result = await db.rawQuery('''
      SELECT n.* FROM NLPResults n
      INNER JOIN JournalEntry j ON n.entryID = j.entryID
      WHERE j.userID = ?
      ORDER BY j.date ASC
    ''', [userID]);
    
    return result.map((map) => NLPResult.fromMap(map)).toList();
  }

  // --- Assessments ---
  Future<Assessment> createAssessment(Assessment assessment) async {
    final db = await instance.database;
    final id = await db.insert('Assessment', assessment.toMap());
    return Assessment(
      assessID: id,
      userID: assessment.userID,
      scaleType: assessment.scaleType,
      score: assessment.score,
      date: assessment.date,
    );
  }

  Future<List<Assessment>> getUserAssessments(int userID) async {
    final db = await instance.database;
    final maps = await db.query(
      'Assessment',
      where: 'userID = ?',
      whereArgs: [userID],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Assessment.fromMap(map)).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
