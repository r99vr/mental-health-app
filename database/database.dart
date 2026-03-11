// ==========================================
// File: database_helper.dart
// Description: SQLite Database configuration and queries
// ==========================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Get database instance or initialize it
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mental_health_app.db');
    return _database!;
  }

  // Initialize the database path
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Create tables based on the project ERD
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Users (
        userID INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE JournalEntry (
        entryID INTEGER PRIMARY KEY AUTOINCREMENT,
        userID INTEGER NOT NULL,
        text TEXT NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (userID) REFERENCES Users (userID)
      )
    ''');

    await db.execute('''
      CREATE TABLE Assessment (
        assessID INTEGER PRIMARY KEY AUTOINCREMENT,
        userID INTEGER NOT NULL,
        scaleType TEXT NOT NULL,
        score INTEGER NOT NULL,
        FOREIGN KEY (userID) REFERENCES Users (userID)
      )
    ''');

    await db.execute('''
      CREATE TABLE NLPResult (
        resultID INTEGER PRIMARY KEY AUTOINCREMENT,
        entryID INTEGER NOT NULL,
        emotion TEXT NOT NULL,
        confidence REAL NOT NULL,
        FOREIGN KEY (entryID) REFERENCES JournalEntry (entryID)
      )
    ''');
  }

  // --- CRUD Operations (Insert) ---

  Future<int> insertUser(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('Users', row);
  }

  Future<int> insertJournalEntry(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('JournalEntry', row);
  }

  Future<int> insertAssessment(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('Assessment', row);
  }

  Future<int> insertNLPResult(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('NLPResult', row);
  }

  // --- Data Fetching Operations (For UI & Charts) ---

  // Validate user login
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'Users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (result.isNotEmpty) return result.first;
    return null; 
  }

  // Fetch previous assessments for a user
  Future<List<Map<String, dynamic>>> getUserAssessments(int userID) async {
    final db = await instance.database;
    return await db.query(
      'Assessment',
      where: 'userID = ?',
      whereArgs: [userID],
      orderBy: 'assessID DESC', 
    );
  }

  // Fetch mood history combining Journal and NLP Results for Charts
  Future<List<Map<String, dynamic>>> getMoodHistoryForChart(int userID) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT JournalEntry.date, NLPResult.emotion, NLPResult.confidence 
      FROM JournalEntry 
      INNER JOIN NLPResult ON JournalEntry.entryID = NLPResult.entryID 
      WHERE JournalEntry.userID = ? 
      ORDER BY JournalEntry.date ASC
    ''', [userID]);
    return result; 
  }
}