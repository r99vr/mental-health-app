// ==========================================
// File: ai_service.dart
// Description: AI Model logic and integration with the Database
// ==========================================

import 'database_helper.dart';

class AIService {
  
  // Translate the raw model output label to the specific psychological class
  static String translateEmotion(String modelOutput) {
    switch (modelOutput) {
      case 'LABEL_0':
        return 'Stress';                
      case 'LABEL_1':
        return 'Depression';            
      case 'LABEL_2':
        return 'Bipolar';               
      case 'LABEL_3':
        return 'Personality Disorder';  
      case 'LABEL_4':
        return 'Anxiety';               
      default:
        return 'Unknown';               
    }
  }

  // Process the journal text, run AI analysis, and save both entry and result
  static Future<void> processAndSaveJournal(int currentUserID, String journalText, String rawModelOutput, double confidenceScore) async {
    
    // Step 1: Save the journal text to the database
    Map<String, dynamic> newEntry = {
      'userID': currentUserID,
      'text': journalText,
      'date': DateTime.now().toIso8601String(),
    };
    
    // Get the generated ID of the new journal entry
    int savedEntryID = await DatabaseHelper.instance.insertJournalEntry(newEntry);

    // Step 2: Translate the AI result to the actual emotion category
    String finalEmotion = translateEmotion(rawModelOutput);

    // Step 3: Save the AI result to the database and link it to the journal entry ID
    Map<String, dynamic> newResult = {
      'entryID': savedEntryID,
      'emotion': finalEmotion,
      'confidence': confidenceScore, 
    };
    
    await DatabaseHelper.instance.insertNLPResult(newResult);

    // Console output for debugging
    print('Journal saved successfully! Detected state: $finalEmotion');
  }
}