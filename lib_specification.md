# Vocacha `lib` 디렉토리 명세서

이 문서는 `vocagacha` 앱의 `lib` 폴더 내에 있는 각 Dart 파일들의 역할과 주요 기능을 설명하는 명세서입니다.

## 📁 루트 디렉토리 (`lib/`)

### 1. `main.dart`
- **역할**: Flutter 애플리케이션의 진입점(Entry Point)이자 메인 UI 뼈대를 구성하는 파일입니다.
- **주요 기능**:
  - `dotenv`를 통한 환경 변수 초기화.
  - `Firebase` 앱 초기화 (`DefaultFirebaseOptions` 사용).
  - 앱의 기본 탭 구조(가챠, 인벤토리)를 정의한 `VocachaTest` 위젯 제공.
  - `DbService`를 인스턴스화하고 유저 데이터를 초기화 (`test_user_01`을 테스트 계정으로 사용).
  - 유저의 실시간 토큰(코인) 수를 스트림으로 수신하여 화면에 업데이트.

### 2. `firebase_options.dart`
- **역할**: Firebase CLI에 의해 자동 생성된 파일로, 플랫폼별(Web, Android, iOS, macOS, Windows) Firebase 연결 설정 값을 담고 있습니다.
- **주요 기능**:
  - `DefaultFirebaseOptions` 클래스를 통해 현재 구동 중인 플랫폼에 알맞은 API Key, App ID, Project ID 등의 Firebase 설정 객체를 반환하여 초기화를 돕습니다.

### 3. `gemini_service.dart`
- **역할**: Google Gemini AI API와 통신하여 영단어를 추천받고 사용자의 암기 제출 상태를 검증하는 서비스 클래스입니다.
- **주요 기능**:
  - `.env` 파일에서 `GEMINI_API_KEY`를 로드하여 `GenerativeModel`을 초기화합니다.
  - `validateMemorization(word, expectedMean, userMean, userExample)`: 유저가 입력한 단어의 뜻과 예문을 검사하여, 실제 뜻과 유사한지 및 예문이 문법적으로 맞는지 엄격하게 채점(`isValid`, `reason`)합니다.

---

## 📁 모델 폴더 (`lib/models/`)

### 4. `word_model.dart`
- **역할**: 앱 전체 및 Firestore 데이터베이스 통신에서 사용하는 단어 데이터 모델인 `WordResult` 클래스를 정의합니다.
- **주요 기능**:
  - 단어의 고유 ID, 텍스트, 뜻, 등급, 예문, 암기 여부(`isMemorized`), 뽑은 시간(`pickedAt`), 암기한 시간(`memorizedAt`)을 속성으로 관리합니다.
  - `fromMap`: Firestore 문서 맵 데이터를 Dart 객체로 변환.
  - `toMap`: Dart 객체를 Firestore에 저장하기 적합한 형태의 맵 데이터로 변환.

---

## 📁 화면 폴더 (`lib/screens/`)

### 5. `home_screen.dart`
- **역할**: 앱의 첫 번째 탭. 사용자가 코인을 소모하여 랜덤 단어를 획득(가챠)하는 화면입니다.
- **주요 기능**:
  - 현재 보유한 코인(토큰) 수를 텍스트로 크게 표시합니다.
  - "가챠 돌리기" 버튼 기능: 클릭 시 `DbService`의 `performGacha`를 호출하여 랜덤 단어를 가져오고 토큰을 1개 차감합니다.
  - 단어 뽑기가 성공적으로 완료되면 획득 결과(등급, 단어, 뜻)를 팝업 형태(`AlertDialog`)로 보여줍니다. (로딩 스피너 처리 포함)

### 6. `inventory_screen.dart`
- **역할**: 앱의 두 번째 탭. 사용자가 뽑은 단어 목록을 확인하고, 아직 외우지 않은 단어를 테스트하여 리뷰 및 보상을 지급하는 인벤토리 화면입니다.
- **주요 기능**:
  - **단어 목록 렌더링**: `dbService.getInventoryStream`을 구독하여 뽑은 단어 리스트를 실시간으로 보여줍니다. (암기된 단어는 취소선과 체크 아이콘 처리)
  - **랜덤 단어 암기 팝업**: 상단 "랜덤 단어 암기하기" 버튼을 통해 미암기 단어를 랜덤하게 하나 불러와 뜻과 예문을 입력하게 합니다. `GeminiService`를 통해 정답 판정을 받습니다.
  - **보상 지급**: 채점을 통과하면 `DbService.claimReward`를 호출하여 단어 상태를 업데이트(암기완료)하고 1코인을 추가 지급합니다.

---

## 📁 서비스 폴더 (`lib/services/`)

### 7. `db_service.dart`
- **역할**: Firebase Firestore와 통신하며, 앱의 비즈니스 로직(실시간 데이터 구독 및 DB 쓰기/트랜잭션)을 담당하는 클래스입니다.
- **주요 기능**:
  - `getUserTokensStream`: 단일 사용자의 토큰 개수를 실시간 스트림 관찰.
  - `initializeUser`: 유저 문서가 없으면 초기 10토큰 지급.
  - `getInventoryStream`: 인벤토리 단어 스트림. **Lazy Invalidation(30일 경과 시 자동 미암기 처리)** 로직이 포함되어 있으며, 암기 여부 및 최신순으로 정렬합니다.
  - `performGacha`: 가챠 로직 구현. `all_words` 컬렉션과 사용자의 `inventory` 컬렉션을 비교해 남은 단어 중 겹치지 않는 단어를 랜덤 할당하고 토큰을 차감(트랜잭션 처리)합니다.
  - `claimReward`: 단어를 성공적으로 암기했을 때, 단어 상태(`isMemorized = true`, `memorizedAt` 시간 저장) 업데이트 및 유저의 코인을 증가(트랜잭션 처리)시킵니다.
  - `getRandomUnmemorizedWord`: 인벤토리에서 미암기인 단어(또는 30일 경과로 만료될 단어) 중 하나를 무작위로 반환하여 암기 테스트에 활용합니다.
