import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_model.dart';

class DbService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 유저 토큰 실시간 스트림
  Stream<int> getUserTokensStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data()?['tokens'] ?? 0;
      }
      return 0;
    });
  }

  // 유저 초기화 (없으면 생성 및 기초토큰 지급)
  Future<void> initializeUser(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({'tokens': 10});
    }
  }

  // 인벤토리 스트림 가져오기
  Stream<List<WordResult>> getInventoryStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('inventory')
        .orderBy('isMemorized', descending: false)
        .orderBy('pickedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final List<WordResult> results = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            bool isMemorized = data['isMemorized'] ?? false;
            Timestamp? memorizedAt = data['memorizedAt'] as Timestamp?;
            bool shouldUpdateDb = false;

            if (isMemorized) {
              final referenceTime =
                  memorizedAt ?? data['pickedAt'] as Timestamp?;
              if (referenceTime != null) {
                final diff = now.difference(referenceTime.toDate());
                if (diff.inDays >= 30) {
                  isMemorized = false;
                  memorizedAt = null;
                  shouldUpdateDb = true;
                }
              }
            }

            if (shouldUpdateDb) {
              // 조용히 백그라운드 업데이트 (Side effect)
              doc.reference
                  .update({'isMemorized': false, 'memorizedAt': null})
                  .catchError((e) => print("Expired word update failed: $e"));
            }

            final modelData = Map<String, dynamic>.from(data)
              ..['isMemorized'] = isMemorized
              ..['memorizedAt'] = memorizedAt;

            results.add(WordResult.fromMap(doc.id, modelData));
          }

          // UI에 보여주기 전에 다시 isMemorized 기준으로 정렬 (방금 풀린 단어들을 위로)
          results.sort((a, b) {
            if (a.isMemorized != b.isMemorized) {
              return a.isMemorized ? 1 : -1;
            }
            // 둘 다 상태가 같으면 pickedAt 기준 최신순
            final aTime = a.pickedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.pickedAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });

          return results;
        });
  }

  // 가챠 진행 메서드 (뽑은 단어 및 소비한 토큰 트랜잭션)
  Future<WordResult?> performGacha(String uid) async {
    try {
      // 1. 전체 단어 목록 가져오기
      final allWordsSnapshot = await _firestore.collection('all_words').get();
      if (allWordsSnapshot.docs.isEmpty) throw "DB에 단어가 없습니다.";

      // 2. 내 인벤토리의 단어 가져오기 (중복 체크)
      final inventorySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('inventory')
          .get();
      final List<String> myWords = inventorySnapshot.docs
          .map((doc) => doc.get('word') as String)
          .toList();

      final availableWords = allWordsSnapshot.docs.where((doc) {
        return !myWords.contains(doc.get('word'));
      }).toList();

      if (availableWords.isEmpty) {
        return null; // 모든 단어 수집 완료
      }

      final randomDoc = (availableWords..shuffle()).first;
      final wordData = randomDoc.data();

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(uid);
        final userSnap = await transaction.get(userRef);
        int currentTokens = userSnap.get('tokens') ?? 0;

        if (currentTokens > 0) {
          transaction.update(userRef, {'tokens': currentTokens - 1});
          final inventoryRef = userRef.collection('inventory').doc();
          transaction.set(inventoryRef, {
            ...wordData,
            'isMemorized': false,
            'pickedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      return WordResult.fromMap('', wordData); // id는 팝업에 안쓰므로 빈문자열
    } catch (e) {
      print("❌ 가챠 실패: $e");
      rethrow;
    }
  }

  // 암기 완료 (보상 지급) 트랜잭션
  Future<bool> claimReward(String uid, String docId) async {
    final userRef = _firestore.collection('users').doc(uid);
    final wordRef = userRef.collection('inventory').doc(docId);
    bool rewardClaimed = false;

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final wordSnap = await transaction.get(wordRef);
      bool isMemorized = wordSnap.get('isMemorized') ?? false;
      int currentTokens = userSnap.get('tokens') ?? 0;

      if (!isMemorized) {
        transaction.update(wordRef, {
          'isMemorized': true,
          'memorizedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(userRef, {'tokens': currentTokens + 1});
        rewardClaimed = true;
      }
    });

    return rewardClaimed;
  }

  // 랜덤 미암기 단어 가져오기
  Future<WordResult?> getRandomUnmemorizedWord(String uid) async {
    try {
      final inventoryRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('inventory');

      final inventorySnapshot = await inventoryRef.get();
      final now = DateTime.now();

      List<QueryDocumentSnapshot<Map<String, dynamic>>> unmemorizedDocs = [];

      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        bool isMemorized = data['isMemorized'] ?? false;
        Timestamp? memorizedAt = data['memorizedAt'] as Timestamp?;

        if (!isMemorized) {
          unmemorizedDocs.add(doc);
        } else {
          // isMemorized == true 인 경우
          final referenceTime = memorizedAt ?? data['pickedAt'] as Timestamp?;
          if (referenceTime != null) {
            final diff = now.difference(referenceTime.toDate());
            if (diff.inDays >= 30) {
              unmemorizedDocs.add(doc);
              // 백그라운드 업데이트
              doc.reference
                  .update({'isMemorized': false, 'memorizedAt': null})
                  .catchError((e) => print("Expired word update failed: $e"));
            }
          }
        }
      }

      if (unmemorizedDocs.isEmpty) {
        return null; // 모든 단어를 30일 이내에 암기함
      }

      unmemorizedDocs.shuffle();
      final targetDoc = unmemorizedDocs.first;

      final modelData = Map<String, dynamic>.from(targetDoc.data())
        ..['isMemorized'] = false
        ..['memorizedAt'] = null;

      return WordResult.fromMap(targetDoc.id, modelData);
    } catch (e) {
      print("❌ 랜덤 단어 가져오기 실패: $e");
      rethrow;
    }
  }
}
