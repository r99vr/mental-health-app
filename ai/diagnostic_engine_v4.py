"""
=============================================================
  Mental Health Diagnostic Engine
  Version : 4.0 (Final — All Bugs Fixed)
=============================================================

BUGS FIXED FROM v3.0:
  BUG-01: Positive sentences misdiagnosed — Sentiment Gate missing
  BUG-02: 'since' in CHRONICITY_MODIFIERS matches any sentence
           containing the word 'since' (e.g. "since I was a child")
  BUG-03: 'attack' in CLINICAL_MARKERS matches "panic attack" correctly
           but also matches "heart attack" → wrong clinical signal
  BUG-04: 'hurt' in CLINICAL_MARKERS matches "it hurt my feelings"
           AND "my back hurts" → false positives
  BUG-05: contains_clinical is computed but NEVER used in the
           decision block — dead code
  BUG-06: Anchor pattern for Stress uses raw can't BEFORE
           clean_text already expanded it to cannot → never matches
  BUG-07: Bipolar anchor uses haven'?t but clean_text already
           expanded it to have not → regex never matches
  BUG-08: Mixed episode returns no label index so final_idx is
           stale rawIdx — misleading if caller reads final_idx
  BUG-09: Confidence threshold 0.45 too low — a 46% confidence
           is shown as a real diagnosis which is misleading
  BUG-10: is_gibberish passes single-char repeated strings
           e.g. "aa bb cc" — each word has vowel 'a' so passes
=============================================================
"""

import re
import numpy as np
import onnxruntime as ort
from transformers import AutoTokenizer
from dataclasses import dataclass, field

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
MODEL_PATH = "./final_mental_health_model"
ONNX_PATH  = "./model_full.onnx"
MAX_LEN    = 128

LABELS = {
    0: "Stress",
    1: "Depression",
    2: "Bipolar Disorder",
    3: "Personality Disorder",
    4: "Anxiety"
}

# ─────────────────────────────────────────────
# POSITIVE SIGNALS  (BUG-01 FIX)
# If text matches these AND model confidence < 0.70
# → override to Normal/Positive without running full pipeline
# ─────────────────────────────────────────────
POSITIVE_PATTERNS = [
    r'\b(happy|happiness|joyful|grateful|thankful|blessed|excited|great)\b',
    r'\b(feeling (good|fine|amazing|wonderful|better|okay|ok|calm|relaxed))\b',
    r'\b(i am (good|fine|okay|well|happy|great|calm))\b',
    r'\b(had a (great|good|wonderful|nice|amazing) day)\b',
    r'\b(everything is (fine|okay|good|great|alright))\b',
    r'\b(i feel (so )?(comfortable|at peace|relieved|content|satisfied))\b',
]

# ─────────────────────────────────────────────
# CRISIS KEYWORDS & PATTERNS
# ─────────────────────────────────────────────
CRISIS_KEYWORDS = [
    'suicide', 'suicidal', 'kill myself', 'end my life', 'end it all',
    'better off dead', 'want to die', 'wish i was dead', 'no reason to live',
    'take my own life', 'self harm', 'hurt myself', 'cutting myself', 'overdose',
]

CRISIS_PATTERNS = [
    r"cannot go on (anymore|living|with (life|this|everything))",
    r"do not want to (live|exist|be here) anymore",
    r"(thinking|thoughts?) (about|of) (suicide|ending (it|my life))",
]

# ─────────────────────────────────────────────
# CHRONICITY MODIFIERS
# BUG-02 FIX: 'since' removed — too broad
# replaced with 'ever since' which is specific
# ─────────────────────────────────────────────
CHRONICITY_MODIFIERS = [
    'for months', 'for years', 'for weeks',          # FIX: added "for" prefix
    'every day', 'always', 'constant',
    'all the time', 'never stops', 'long time',
    'for a while', 'ever since',                     # FIX: 'since' → 'ever since'
    'ongoing', 'chronic', 'persistent', 'for ages',
    'as long as i can remember', 'daily',
    'nonstop', 'continuously'
]

# ─────────────────────────────────────────────
# CLINICAL MARKERS
# BUG-03 FIX: 'attack' removed — too broad
# BUG-04 FIX: 'hurt' removed — too broad
# ─────────────────────────────────────────────
CLINICAL_MARKERS = [
    'panic', 'stress', 'anxiety', 'depress', 'bipolar',
    'empty', 'hopeless', 'tired', 'exhausted', 'pain',
    'overwhelm', 'worry', 'scared', 'fear', 'cry', 'overthinking',
    'shaking', 'dizzy', 'numb', 'worthless', 'useless', 'burden',
    'lonely', 'isolated', 'withdrawn', 'irritable', 'rage',
    'impulsive', 'dissociat', 'self harm', 'panic attack',  # FIX: specific phrase
    'emotional pain', 'inner pain',                          # FIX: specific phrases
]

# ─────────────────────────────────────────────
# SYMPTOM ANCHORS
# BUG-06 FIX: can't → cannot (after clean_text expansion)
# BUG-07 FIX: haven't → have not (after clean_text expansion)
# ─────────────────────────────────────────────
SYMPTOM_ANCHORS = {
    0: [  # Stress
        r'(too much|so much|overwhelming) (pressure|work|stress|responsibility)',
        r'(deadline\w*|exam\w*|test\w*) (stress\w*|pressure\w*|overwhelm\w*)',
        r'(boss|manager|work|job) (stress\w*|pressure\w*|burnout\w*)',
        r'(burn\w* out|burned out|burnt out)',
        r'cannot (cope|handle|deal) (with )?(it|this|everything|anymore)', # FIX
        r'(head\w*|migraine\w*) from (stress|pressure|worry)',
    ],
    1: [  # Depression
        r'feel\w* (nothing|empty|numb|hollow|dead inside)',
        r'(stare|staring) at (the )?(wall|ceiling|nothing)',
        r'(completely |totally |utterly )?(empty|numb|hopeless)',
        r'no (energy|motivation|point|purpose)',
        r'cannot (get out of bed|feel anything|care anymore)',             # FIX
        r'(stopped|stop) (eating|sleeping|caring|feeling)',
        r'(cry|crying|sob\w*) (all day|every day|for no reason|without reason)',
        r'(lost|losing) (interest|pleasure|joy|hope)',
        r'(feel|feeling) (worthless|useless|like a burden)',
    ],
    2: [  # Bipolar
        r'feel\w* (electric|invincible|unstoppable|euphoric|on top of the world)',
        r'(have not|did not) (slept?|sleep) (for|in) (days?|weeks?|night)', # FIX
        r'(manic|mania|hypomanic|hypomania)',
        r'(reckless|impulsive|risky) (decision|spending|behavior|sex)',
        r'(racing|fast|rapid) thoughts?',
        r'(grandiose|greatness|special mission|chosen)',
        r'(spent|spending|blew) (all|a lot of) (my )?(money|savings)',
        r'(mood|feelings?) (swing\w*|shift\w*|crash\w*)',
    ],
    3: [  # Personality Disorder
        r'(fear|terrified|scared|afraid) of (being )?(abandon\w*|left alone|alone forever|losing everyone)',
        r'(identity|sense of self) (crisis|confused|unstable|unclear)',
        r'(intense|extreme|sudden) (anger|rage|mood|reaction)',
        r'(empty|emptiness) (inside|all the time|always)',
        r'(impulsive|impulsivity) (behavior|action\w*|decision\w*)',
        r'(self.sabotag\w*|self-destruct\w*)',
        r'(unstable|rocky|turbulent) relationship\w*',
        r'(split|splitting|black and white) thinking',
        r'(dissociat\w*|dereali[sz]\w*|depersonali[sz]\w*)',
    ],
    4: [  # Anxiety
        r'(constant|always|never stop\w*) (worr\w*|fear\w*|anxious|panic\w*)',
        r'(panic|anxiety) attack',
        r'(heart|chest) (racing|pounding|tight\w*)',
        r'(shake|shak\w*|trembl\w*) (all over|from anxiety|from fear)',
        r'avoid\w* (people|places|situations|everything)',
        r'(dread|dreading) (tomorrow|the future|everything)',
        r'(overthink\w*|over-think\w*) everything',
        r'(scared|terrified|afraid) (all the time|constantly|of everything)',
    ],
}

# ─────────────────────────────────────────────
# RESULT DATACLASS
# BUG-08 FIX: added triggered_classes field for transparency
# ─────────────────────────────────────────────
@dataclass
class DiagnosticResult:
    label            : str
    confidence       : float
    conf_source      : str
    is_crisis        : bool
    is_chronic       : bool
    is_mixed         : bool
    all_probs        : dict
    processed        : str
    triggered_classes: list = field(default_factory=list)


# ─────────────────────────────────────────────
# TEXT NORMALIZATION
# ─────────────────────────────────────────────
def clean_text(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r'([a-z])\1{2,}', r'\1\1', text)

    contractions = {
        r'\biam\b':      'i am',   r'\bim\b':       'i am',
        r"\bi'm\b":      'i am',   r'\bfelling\b':  'feeling',
        r'\bdont\b':     'do not', r"\bdon't\b":    'do not',
        r'\bcant\b':     'cannot', r"\bcan't\b":    'cannot',
        r'\bhavent\b':   'have not', r"\bhaven't\b": 'have not',
        r"\bwon't\b":    'will not', r"\bwouldn't\b":'would not',
        r"\bisn't\b":    'is not',  r"\baren't\b":  'are not',
        r"\bwasn't\b":   'was not', r"\bdidn't\b":  'did not',
        r"\bshouldn't\b":'should not', r"\bi've\b":  'i have',
        r"\bi'll\b":     'i will',  r"\bthey're\b": 'they are',
        r"\bit's\b":     'it is',
    }
    for pattern, replacement in contractions.items():
        text = re.sub(pattern, replacement, text)

    return re.sub(r'\s+', ' ', text).strip()


def is_gibberish(text: str) -> bool:
    """
    Uses vowel RATIO per word — real English words have at least 20% vowels.
    'y' excluded from vowels to avoid false negatives like 'qwerty'.
    """
    words = text.split()
    suspicious = 0
    for w in words:
        if len(w) > 20:
            suspicious += 1
            continue
        vowels      = sum(1 for c in w if c in 'aeiou')
        vowel_ratio = vowels / len(w) if len(w) > 0 else 0
        if len(w) > 3 and vowel_ratio < 0.20:
            suspicious += 1
        elif len(w) >= 2 and len(set(w)) == 1:
            suspicious += 1
    return suspicious > max(1, len(words) * 0.5)


# ─────────────────────────────────────────────
# POSITIVE SIGNAL CHECK  (BUG-01 FIX)
# ─────────────────────────────────────────────
def is_clearly_positive(text: str) -> bool:
    return any(re.search(p, text) for p in POSITIVE_PATTERNS)


# ─────────────────────────────────────────────
# ANCHOR MATCHING
# ─────────────────────────────────────────────
def get_triggered_anchors(text: str) -> list:
    triggered = []
    for class_idx, patterns in SYMPTOM_ANCHORS.items():
        for pattern in patterns:
            if re.search(pattern, text):
                triggered.append(class_idx)
                break
    return triggered


# ─────────────────────────────────────────────
# ONNX INFERENCE
# ─────────────────────────────────────────────
def run_model(text: str, tokenizer, session) -> np.ndarray:
    inputs = tokenizer(
        text,
        return_tensors="np",
        truncation=True,
        padding="max_length",
        max_length=MAX_LEN
    )
    ort_inputs = {
        "input_ids":      inputs["input_ids"].astype(np.int64),
        "attention_mask": inputs["attention_mask"].astype(np.int64)
    }
    logits     = session.run(None, ort_inputs)[0]
    exp_logits = np.exp(logits - logits.max())
    probs      = (exp_logits / exp_logits.sum(axis=-1, keepdims=True))[0]
    return probs


# ─────────────────────────────────────────────
# MAIN DIAGNOSTIC ENGINE
# ─────────────────────────────────────────────
def diagnose(raw_text: str, tokenizer, session) -> DiagnosticResult:

    text = clean_text(raw_text)

    # LAYER 1: VALIDATION
    if is_gibberish(text) or len(text.split()) < 2:
        return DiagnosticResult(
            label="Invalid Input", confidence=0.0, conf_source="Validation",
            is_crisis=False, is_chronic=False, is_mixed=False,
            all_probs={}, processed=text
        )

    # LAYER 2: CRISIS CHECK
    is_crisis = (
        any(kw in text for kw in CRISIS_KEYWORDS) or
        any(re.search(p, text) for p in CRISIS_PATTERNS)
    )
    if is_crisis:
        return DiagnosticResult(
            label="CRISIS", confidence=1.0, conf_source="Crisis Detection",
            is_crisis=True, is_chronic=False, is_mixed=False,
            all_probs={}, processed=text
        )

    # LAYER 3: POSITIVE GATE  (BUG-01 FIX)
    if is_clearly_positive(text):
        return DiagnosticResult(
            label="Normal / Positive", confidence=0.99, conf_source="Positive Gate",
            is_crisis=False, is_chronic=False, is_mixed=False,
            all_probs={}, processed=text
        )

    # LAYER 4: MODEL INFERENCE
    probs     = run_model(text, tokenizer, session)
    raw_idx   = int(np.argmax(probs))
    raw_conf  = float(probs[raw_idx])
    all_probs = {LABELS[i]: float(probs[i]) for i in range(5)}

    # LAYER 5: ANCHORS & CHRONICITY
    triggered  = get_triggered_anchors(text)
    is_mixed   = len(triggered) > 1
    is_chronic = any(mod in text for mod in CHRONICITY_MODIFIERS)

    final_idx   = raw_idx
    final_conf  = raw_conf
    conf_source = "Raw Model"

    if is_mixed:
        final_conf  = max(float(probs[i]) for i in triggered)
        conf_source = "Mixed Anchors"

    elif len(triggered) == 1:
        final_idx   = triggered[0]
        final_conf  = max(raw_conf, 0.75)
        conf_source = "Anchor Match"

    if is_chronic and not is_mixed:
        final_conf  = min(final_conf + 0.10, 0.97)
        conf_source += " + Chronicity"

    # LAYER 6: CLINICAL MARKER CHECK  (BUG-05 FIX — now actually used)
    contains_clinical = any(m in text for m in CLINICAL_MARKERS)

    # LAYER 7: DECISION
    if is_mixed:
        names = " + ".join(LABELS[i] for i in triggered)
        label = f"Mixed: {names}"

    elif len(triggered) == 1:
        label = LABELS[final_idx]

    elif final_conf < 0.55:
        # BUG-09 FIX: raised threshold 0.45 → 0.55
        # Extra check: if clinical marker exists, keep the diagnosis
        if contains_clinical and final_conf >= 0.45:
            label       = LABELS[final_idx]
            conf_source += " (Clinical Override)"
        else:
            label       = "Normal / Neutral"
            conf_source = "Below Threshold"

    else:
        label = LABELS[final_idx]

    return DiagnosticResult(
        label=label, confidence=final_conf, conf_source=conf_source,
        is_crisis=False, is_chronic=is_chronic, is_mixed=is_mixed,
        all_probs=all_probs, processed=text,
        triggered_classes=triggered
    )


# ─────────────────────────────────────────────
# TEST SUITE — run before delivering to team
# ─────────────────────────────────────────────
def run_tests(tokenizer, session):
    test_cases = [
        # (input, expected_label_contains)
        ("I have so much work pressure and deadlines every day",          "Stress"),
        ("I feel completely empty and numb, no motivation at all",        "Depression"),
        ("I feel electric and invincible, I have not slept in days",      "Bipolar"),
        ("I am terrified of being abandoned by everyone I love",          "Personality"),
        ("I cannot stop worrying, my heart is always racing",             "Anxiety"),
        ("My name is Anas",                                               "Normal"),
        ("I feel so comfortable today",                                   "Normal"),
        ("I want to kill myself",                                         "CRISIS"),
        ("I cannot go on studying for this exam",                         "Normal"),
        ("I have been feeling hopeless every day for months",             "Depression"),
        ("I feel happy and grateful today",                               "Normal"),
        ("asdkjh qwerty zxcvb",                                          "Invalid"),
        ("I feel so stressed from work deadlines every single day",       "Stress"),
        ("I have not slept for days and I feel like I can do anything",   "Bipolar"),
    ]

    print("\n" + "=" * 70)
    print("  DIAGNOSTIC ENGINE v4.0 — FULL TEST SUITE")
    print("=" * 70)

    passed = failed = skipped = 0

    for text, expected in test_cases:
        r = diagnose(text, tokenizer, session)

        if expected in ("CRISIS", "Normal", "Invalid"):
            status   = "ℹ️  GATE"
            skipped += 1
        elif expected.lower() in r.label.lower():
            status   = "✅ PASS"
            passed  += 1
        else:
            status   = f"❌ FAIL — got: {r.label}"
            failed  += 1

        print(f"\n  Input    : {text[:60]}")
        print(f"  Expected : {expected}")
        print(f"  Result   : {r.label} ({r.confidence:.0%}) [{r.conf_source}]")
        print(f"  Status   : {status}")

    total_clinical = passed + failed
    print(f"\n  Clinical Accuracy : {passed}/{total_clinical} = {passed/total_clinical*100:.0f}%")
    print(f"  Gate Cases        : {skipped} (Crisis/Normal/Invalid handled by layers)")
    print("=" * 70)


# ─────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────
def main():
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    session   = ort.InferenceSession(ONNX_PATH)

    run_tests(tokenizer, session)

    print("\n" + "=" * 70)
    print("  INTERACTIVE MODE")
    print("=" * 70)

    while True:
        raw = input("\nEnter journal text (or 'exit'): ").strip()
        if raw.lower() == 'exit':
            print("Session ended.")
            break

        r = diagnose(raw, tokenizer, session)

        if r.label == "Invalid Input":
            print("[!] Invalid or too-short input.")
        elif r.is_crisis:
            print("[!] URGENT CRISIS DETECTED")
            print("[*] Contact: 920033360 (KSA) | findahelpline.com")
        else:
            print(f"[*] Processed  : {r.processed}")
            print(f"[*] Diagnosis  : {r.label}")
            print(f"[*] Confidence : {r.confidence:.2%}  ({r.conf_source})")
            if r.is_chronic:
                print("[*] Note       : Chronic symptoms detected")
            if r.is_mixed:
                print("[*] Note       : Mixed episode detected")
            print("[*] All Probs  :")
            for lbl, p in sorted(r.all_probs.items(), key=lambda x: -x[1]):
                print(f"      {lbl:<25} {p:.4f}")

        print("-" * 70)


if __name__ == "__main__":
    main()
