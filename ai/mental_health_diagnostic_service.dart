// =============================================================
//  Mental Health Diagnostic Engine
//  Version : 4.0 — Dart (Synced with Python v4.0)
//
//  pubspec.yaml dependencies:
//    onnxruntime: ^1.4.0
//
//  pubspec.yaml assets:
//    assets:
//      - assets/model_full.onnx
//      - assets/tokenizer.json
// =============================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

// ─────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────
const int _maxLen = 128;

const Map<int, String> _labels = {
  0: 'Stress',
  1: 'Depression',
  2: 'Bipolar Disorder',
  3: 'Personality Disorder',
  4: 'Anxiety',
};

// ─────────────────────────────────────────────
// POSITIVE PATTERNS
// ─────────────────────────────────────────────
final List<RegExp> _positivePatterns = [
  RegExp(r'\b(happy|happiness|joyful|grateful|thankful|blessed|excited|great)\b'),
  RegExp(r'\b(feeling (good|fine|amazing|wonderful|better|okay|ok|calm|relaxed))\b'),
  RegExp(r'\b(i am (good|fine|okay|well|happy|great|calm))\b'),
  RegExp(r'\b(had a (great|good|wonderful|nice|amazing) day)\b'),
  RegExp(r'\b(everything is (fine|okay|good|great|alright))\b'),
  RegExp(r'\b(i feel (so )?(comfortable|at peace|relieved|content|satisfied))\b'),
];

// ─────────────────────────────────────────────
// CRISIS KEYWORDS & PATTERNS
// ─────────────────────────────────────────────
const List<String> _crisisKeywords = [
  'suicide', 'suicidal', 'kill myself', 'end my life', 'end it all',
  'better off dead', 'want to die', 'wish i was dead', 'no reason to live',
  'take my own life', 'self harm', 'hurt myself', 'cutting myself', 'overdose',
];

final List<RegExp> _crisisPatterns = [
  RegExp(r'cannot go on (anymore|living|with (life|this|everything))'),
  RegExp(r'do not want to (live|exist|be here) anymore'),
  RegExp(r'(thinking|thoughts?) (about|of) (suicide|ending (it|my life))'),
];

// ─────────────────────────────────────────────
// CHRONICITY MODIFIERS
// ─────────────────────────────────────────────
const List<String> _chronicityModifiers = [
  'for months', 'for years', 'for weeks',
  'every day', 'always', 'constant',
  'all the time', 'never stops', 'long time',
  'for a while', 'ever since',
  'ongoing', 'chronic', 'persistent', 'for ages',
  'as long as i can remember', 'daily',
  'nonstop', 'continuously',
];

// ─────────────────────────────────────────────
// CLINICAL MARKERS
// ─────────────────────────────────────────────
const List<String> _clinicalMarkers = [
  'panic', 'stress', 'anxiety', 'depress', 'bipolar',
  'empty', 'hopeless', 'tired', 'exhausted', 'pain',
  'overwhelm', 'worry', 'scared', 'fear', 'cry', 'overthinking',
  'shaking', 'dizzy', 'numb', 'worthless', 'useless', 'burden',
  'lonely', 'isolated', 'withdrawn', 'irritable', 'rage',
  'impulsive', 'dissociat', 'self harm', 'panic attack',
  'emotional pain', 'inner pain',
];

// ─────────────────────────────────────────────
// SYMPTOM ANCHORS
// ─────────────────────────────────────────────
final Map<int, List<RegExp>> _symptomAnchors = {
  0: [
    RegExp(r'(too much|so much|overwhelming) (pressure|work|stress|responsibility)'),
    RegExp(r'(deadline\w*|exam\w*|test\w*) (stress\w*|pressure\w*|overwhelm\w*)'),
    RegExp(r'(boss|manager|work|job) (stress\w*|pressure\w*|burnout\w*)'),
    RegExp(r'(burn\w* out|burned out|burnt out)'),
    RegExp(r'cannot (cope|handle|deal) (with )?(it|this|everything|anymore)'),
    RegExp(r'(head\w*|migraine\w*) from (stress|pressure|worry)'),
  ],
  1: [
    RegExp(r'feel\w* (nothing|empty|numb|hollow|dead inside)'),
    RegExp(r'(stare|staring) at (the )?(wall|ceiling|nothing)'),
    RegExp(r'(completely |totally |utterly )?(empty|numb|hopeless)'),
    RegExp(r'no (energy|motivation|point|purpose)'),
    RegExp(r'cannot (get out of bed|feel anything|care anymore)'),
    RegExp(r'(stopped|stop) (eating|sleeping|caring|feeling)'),
    RegExp(r'(cry|crying|sob\w*) (all day|every day|for no reason|without reason)'),
    RegExp(r'(lost|losing) (interest|pleasure|joy|hope)'),
    RegExp(r'(feel|feeling) (worthless|useless|like a burden)'),
  ],
  2: [
    RegExp(r'feel\w* (electric|invincible|unstoppable|euphoric|on top of the world)'),
    RegExp(r'(have not|did not) (slept?|sleep) (for|in) (days?|weeks?|night)'),
    RegExp(r'(manic|mania|hypomanic|hypomania)'),
    RegExp(r'(reckless|impulsive|risky) (decision|spending|behavior|sex)'),
    RegExp(r'(racing|fast|rapid) thoughts?'),
    RegExp(r'(grandiose|greatness|special mission|chosen)'),
    RegExp(r'(spent|spending|blew) (all|a lot of) (my )?(money|savings)'),
    RegExp(r'(mood|feelings?) (swing\w*|shift\w*|crash\w*)'),
  ],
  3: [
    RegExp(r'(fear|terrified|scared|afraid) of (being )?(abandon\w*|left alone|alone forever|losing everyone)'),
    RegExp(r'(identity|sense of self) (crisis|confused|unstable|unclear)'),
    RegExp(r'(intense|extreme|sudden) (anger|rage|mood|reaction)'),
    RegExp(r'(empty|emptiness) (inside|all the time|always)'),
    RegExp(r'(impulsive|impulsivity) (behavior|action\w*|decision\w*)'),
    RegExp(r'(self.sabotag\w*|self-destruct\w*)'),
    RegExp(r'(unstable|rocky|turbulent) relationship\w*'),
    RegExp(r'(split|splitting|black and white) thinking'),
    RegExp(r'(dissociat\w*|dereali[sz]\w*|depersonali[sz]\w*)'),
  ],
  4: [
    RegExp(r'(constant|always|never stop\w*) (worr\w*|fear\w*|anxious|panic\w*)'),
    RegExp(r'(panic|anxiety) attack'),
    RegExp(r'(heart|chest) (racing|pounding|tight\w*)'),
    RegExp(r'(shake|shak\w*|trembl\w*) (all over|from anxiety|from fear)'),
    RegExp(r'avoid\w* (people|places|situations|everything)'),
    RegExp(r'(dread|dreading) (tomorrow|the future|everything)'),
    RegExp(r'(overthink\w*|over-think\w*) everything'),
    RegExp(r'(scared|terrified|afraid) (all the time|constantly|of everything)'),
  ],
};

// ─────────────────────────────────────────────
// RESULT MODEL
// ─────────────────────────────────────────────
class DiagnosticResult {
  final String label;
  final double confidence;
  final String confSource;
  final bool isCrisis;
  final bool isChronic;
  final bool isMixed;
  final Map<String, double> allProbs;
  final String processedText;
  final List<int> triggeredClasses;

  const DiagnosticResult({
    required this.label,
    required this.confidence,
    required this.confSource,
    required this.isCrisis,
    required this.isChronic,
    required this.isMixed,
    required this.allProbs,
    required this.processedText,
    this.triggeredClasses = const [],
  });
}

// ─────────────────────────────────────────────
// TOKENIZER
// ─────────────────────────────────────────────
class _WordPieceTokenizer {
  final Map<String, int> _vocab;
  static const int _clsId = 101;
  static const int _sepId = 102;
  static const int _padId = 0;
  static const int _unkId = 100;

  _WordPieceTokenizer(this._vocab);

  static Future<_WordPieceTokenizer> load() async {
    final raw   = await rootBundle.loadString('assets/tokenizer.json');
    final json  = jsonDecode(raw) as Map<String, dynamic>;
    final vocab = (json['model']['vocab'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
    return _WordPieceTokenizer(vocab);
  }

  List<int> _wordPieceTokenize(String word) {
    if (_vocab.containsKey(word)) return [_vocab[word]!];
    final tokens = <int>[];
    int start = 0;
    while (start < word.length) {
      int end = word.length;
      int? found;
      while (start < end) {
        final sub = start == 0
            ? word.substring(start, end)
            : '##${word.substring(start, end)}';
        if (_vocab.containsKey(sub)) {
          found = _vocab[sub]!;
          break;
        }
        end--;
      }
      if (found == null) return [_unkId];
      tokens.add(found);
      start = end;
    }
    return tokens;
  }

  Map<String, List<int>> encode(String text) {
    final words    = text.toLowerCase().trim().split(RegExp(r'\s+'));
    final tokenIds = <int>[_clsId];

    for (final word in words) {
      tokenIds.addAll(_wordPieceTokenize(word));
      if (tokenIds.length >= _maxLen - 1) break;
    }
    tokenIds.add(_sepId);

    final inputIds      = List<int>.filled(_maxLen, _padId);
    final attentionMask = List<int>.filled(_maxLen, 0);

    for (int i = 0; i < min(tokenIds.length, _maxLen); i++) {
      inputIds[i]      = tokenIds[i];
      attentionMask[i] = 1;
    }

    return {'input_ids': inputIds, 'attention_mask': attentionMask};
  }
}

// ─────────────────────────────────────────────
// TEXT NORMALIZATION
// ─────────────────────────────────────────────
String _cleanText(String text) {
  text = text.toLowerCase().trim();

  text = text.replaceAllMapped(
    RegExp(r'([a-z])\1{2,}'),
    (m) => '${m[1]}${m[1]}',
  );

  final contractions = {
    RegExp(r'\biam\b'):       'i am',
    RegExp(r'\bim\b'):        'i am',
    RegExp(r"\bi'm\b"):       'i am',
    RegExp(r'\bfelling\b'):   'feeling',
    RegExp(r'\bdont\b'):      'do not',
    RegExp(r"\bdon't\b"):     'do not',
    RegExp(r'\bcant\b'):      'cannot',
    RegExp(r"\bcan't\b"):     'cannot',
    RegExp(r'\bhavent\b'):    'have not',
    RegExp(r"\bhaven't\b"):   'have not',
    RegExp(r"\bwon't\b"):     'will not',
    RegExp(r"\bwouldn't\b"):  'would not',
    RegExp(r"\bisn't\b"):     'is not',
    RegExp(r"\baren't\b"):    'are not',
    RegExp(r"\bwasn't\b"):    'was not',
    RegExp(r"\bdidn't\b"):    'did not',
    RegExp(r"\bshouldn't\b"): 'should not',
    RegExp(r"\bi've\b"):      'i have',
    RegExp(r"\bi'll\b"):      'i will',
    RegExp(r"\bthey're\b"):   'they are',
    RegExp(r"\bit's\b"):      'it is',
  };

  contractions.forEach((p, r) => text = text.replaceAll(p, r));
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ─────────────────────────────────────────────
// GIBBERISH CHECK
// ─────────────────────────────────────────────
bool _isGibberish(String text) {
  final words = text.split(' ');
  int suspicious = 0;

  for (final w in words) {
    if (w.length > 20) {
      suspicious++;
      continue;
    }
    final vowelCount = w.runes
        .where((c) => c == 97 || c == 101 || c == 105 || c == 111 || c == 117)
        .length;
    final vowelRatio = w.isNotEmpty ? vowelCount / w.length : 0.0;

    if (w.length > 3 && vowelRatio < 0.20) {
      suspicious++;
    } else if (w.length >= 2 && w.split('').toSet().length == 1) {
      suspicious++;
    }
  }

  return suspicious > max(1, (words.length * 0.5).floor());
}

// ─────────────────────────────────────────────
// POSITIVE GATE
// ─────────────────────────────────────────────
bool _isClearlyPositive(String text) {
  return _positivePatterns.any((p) => p.hasMatch(text));
}

// ─────────────────────────────────────────────
// ANCHOR MATCHING
// ─────────────────────────────────────────────
List<int> _getTriggeredAnchors(String text) {
  final triggered = <int>[];
  _symptomAnchors.forEach((classIdx, patterns) {
    for (final p in patterns) {
      if (p.hasMatch(text)) {
        triggered.add(classIdx);
        break;
      }
    }
  });
  return triggered;
}

// ─────────────────────────────────────────────
// SOFTMAX
// ─────────────────────────────────────────────
List<double> _softmax(List<double> logits) {
  final maxVal = logits.reduce(max);
  final exps   = logits.map((x) => exp(x - maxVal)).toList();
  final sum    = exps.reduce((a, b) => a + b);
  return exps.map((x) => x / sum).toList();
}

// ─────────────────────────────────────────────
// MAIN SERVICE CLASS
// ─────────────────────────────────────────────
class MentalHealthDiagnosticService {
  OrtSession? _session;
  _WordPieceTokenizer? _tokenizer;
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> initialize() async {
    OrtEnv.instance.init();
    _tokenizer = await _WordPieceTokenizer.load();

    final sessionOptions = OrtSessionOptions();
    final modelBytes     = await rootBundle.load('assets/model_full.onnx');
    final bytes          = modelBytes.buffer.asUint8List();
    _session  = OrtSession.fromBuffer(bytes, sessionOptions);
    _isReady  = true;
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _isReady = false;
  }

  Future<DiagnosticResult> diagnose(String rawText) async {
    if (!_isReady) {
      throw StateError('Call initialize() before diagnose().');
    }

    // LAYER 1: Normalization
    final text = _cleanText(rawText);

    // LAYER 2: Validation
    if (_isGibberish(text) || text.split(' ').length < 2) {
      return DiagnosticResult(
        label: 'Invalid Input', confidence: 0.0, confSource: 'Validation',
        isCrisis: false, isChronic: false, isMixed: false,
        allProbs: {}, processedText: text,
      );
    }

    // LAYER 3: Crisis Check
    final isCrisis = _crisisKeywords.any((kw) => text.contains(kw)) ||
        _crisisPatterns.any((p) => p.hasMatch(text));

    if (isCrisis) {
      return DiagnosticResult(
        label: 'CRISIS', confidence: 1.0, confSource: 'Crisis Detection',
        isCrisis: true, isChronic: false, isMixed: false,
        allProbs: {}, processedText: text,
      );
    }

    // LAYER 4: Positive Gate
    if (_isClearlyPositive(text)) {
      return DiagnosticResult(
        label: 'Normal / Positive', confidence: 0.99, confSource: 'Positive Gate',
        isCrisis: false, isChronic: false, isMixed: false,
        allProbs: {}, processedText: text,
      );
    }

    // LAYER 5: ONNX Inference
    final encoded = _tokenizer!.encode(text);

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(encoded['input_ids']!),
      [1, _maxLen],
    );
    final attMaskTensor = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(encoded['attention_mask']!),
      [1, _maxLen],
    );

    final inputs     = {'input_ids': inputIdsTensor, 'attention_mask': attMaskTensor};
    final runOptions = OrtRunOptions();
    final outputs    = await _session!.runAsync(runOptions, inputs);

    inputIdsTensor.release();
    attMaskTensor.release();
    runOptions.release();

    final rawLogits = (outputs![0]?.value as List<List<double>>)[0];
    outputs.forEach((e) => e?.release());

    final probs   = _softmax(rawLogits);
    final rawIdx  = probs.indexOf(probs.reduce(max));
    final rawConf = probs[rawIdx];

    final allProbs = <String, double>{
      for (int i = 0; i < probs.length; i++) _labels[i]!: probs[i]
    };

    // LAYER 6: Anchors & Chronicity
    final triggered = _getTriggeredAnchors(text);
    final isMixed   = triggered.length > 1;
    final isChronic = _chronicityModifiers.any((m) => text.contains(m));

    int    finalIdx   = rawIdx;
    double finalConf  = rawConf;
    String confSource = 'Raw Model';

    if (isMixed) {
      finalConf  = triggered.map((i) => probs[i]).reduce(max);
      confSource = 'Mixed Anchors';
    } else if (triggered.length == 1) {
      finalIdx   = triggered[0];
      finalConf  = rawConf > 0.75 ? rawConf : 0.75;
      confSource = 'Anchor Match';
    }

    if (isChronic && !isMixed) {
      finalConf  = (finalConf + 0.10).clamp(0.0, 0.97);
      confSource += ' + Chronicity';
    }

    // LAYER 7: Clinical Marker Check
    final containsClinical = _clinicalMarkers.any((m) => text.contains(m));

    // LAYER 8: Decision
    String label;

    if (isMixed) {
      label = 'Mixed: ${triggered.map((i) => _labels[i]!).join(' + ')}';
    } else if (triggered.length == 1) {
      label = _labels[finalIdx]!;
    } else if (finalConf < 0.55) {
      if (containsClinical && finalConf >= 0.45) {
        label      = _labels[finalIdx]!;
        confSource += ' (Clinical Override)';
      } else {
        label      = 'Normal / Neutral';
        confSource = 'Below Threshold';
      }
    } else {
      label = _labels[finalIdx]!;
    }

    return DiagnosticResult(
      label: label, confidence: finalConf, confSource: confSource,
      isCrisis: false, isChronic: isChronic, isMixed: isMixed,
      allProbs: allProbs, processedText: text,
      triggeredClasses: triggered,
    );
  }
}
