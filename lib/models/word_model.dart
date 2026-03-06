import 'package:cloud_firestore/cloud_firestore.dart';

class WordResult {
  final String id;
  final String word;
  final String mean;
  final String grade;
  final String? example;
  final bool isMemorized;
  final Timestamp? pickedAt;
  final Timestamp? memorizedAt;

  WordResult({
    required this.id,
    required this.word,
    required this.mean,
    required this.grade,
    this.example,
    this.isMemorized = false,
    this.pickedAt,
    this.memorizedAt,
  });

  factory WordResult.fromMap(String id, Map<String, dynamic> data) {
    return WordResult(
      id: id,
      word: data['word'] ?? '',
      mean: data['mean'] ?? '',
      grade: data['grade'] ?? '',
      example: data['example'],
      isMemorized: data['isMemorized'] ?? false,
      pickedAt: data['pickedAt'] as Timestamp?,
      memorizedAt: data['memorizedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'mean': mean,
      'grade': grade,
      if (example != null) 'example': example,
      'isMemorized': isMemorized,
      if (pickedAt != null) 'pickedAt': pickedAt,
      if (memorizedAt != null) 'memorizedAt': memorizedAt,
    };
  }
}
