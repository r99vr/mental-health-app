# AI Model Integration

This project uses a local AI model to analyze user text and detect mental health signals such as depression and anxiety.

The model runs locally on the device using ONNX Runtime.

Pipeline:

User Text
↓
Dart Tokenizer
↓
Token IDs
↓
ONNX Model
↓
Prediction

The tokenizer reads tokenizer.json directly inside Flutter.

Note:
The ONNX model file is stored externally due to GitHub size limits.
Download it from:

https://drive.google.com/drive/folders/1gOzm8TBYTrdBJwckmeowoUhzeS5C-6SW?usp=drive_link

After downloading place it in:

ai/model_full.onnx
