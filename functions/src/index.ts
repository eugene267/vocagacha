import * as admin from "firebase-admin";
import { GoogleGenAI } from "@google/genai"; 

const serviceAccount = require("../service-account.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 데이터 구조 정의
interface WordData {
  word: string;
  mean: string;
  grade: string;
}


async function runSeed() {
  
  const ai = new GoogleGenAI({
    apiKey: "AIzaSyBQWLBMS27kaKTjF6Y7FU9HYzmubZ65Hbg"
  });

  try {
    
    const wordsRef = db.collection("all_words");
    const existingDocs = await wordsRef.get();
    let allWords = existingDocs.docs.map(doc => doc.data().word);

    const shuffled = allWords.sort(() => 0.5 - Math.random());
    const excludeList = shuffled.slice(0, 200).join(", ");
    const result = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: `
      영어 단어 학습 앱을 위한 단어 30개를 생성해줘. 
      각 등급의 기준과 예시는 다음과 같으니 이 난이도에 절대적으로 맞춰줘:
      1. B: 비즈니스 일반 (예: alignment, leverage, streamline, touch base, proactive)
      2. A: 비즈니스 전문 (예: discrepancy, contingency, mitigate, prerequisite, consolidate)
      3. S: 뉴스 및 잡지 (예: ambivalent, ephemeral, cynical, plausible, ubiquitous)
      4. SSS: 논문 (예: anomalous, axiom, empirical, dichotomy, juxtaposition)

      위 기준에 맞춰 SSS 등급 1개, S 등급 7개, A 등급 10개, B 등급 12개를 반드시 아래 JSON 배열 형식으로만 답해줘. 다른 설명은 생략해.
      [
        { "word": "단어1", "mean": "뜻1", "grade": "B" },
        ...
        { "word": "단어30", "mean": "뜻30", "grade": "SSS"}
      ]
        
      제약 조건:
      - 단어는 전부 소문자로 해줘.
      - [중요] 아래 리스트에 있는 단어는 이미 DB에 있으니 절대 생성하지 마:
        ${excludeList}
      `      
    });

    const responseText = result.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const cleanJson = responseText.replace(/```json|```/g, "").trim();
    const parsedArray: any[] = JSON.parse(cleanJson);


    for (const data of parsedArray) {
      const snapshot = await wordsRef.where("word", "==", data.word).get();
      
      if (snapshot.empty) {
        const wordData: WordData = {
          ...data
        };
        await wordsRef.add(wordData);
        console.log(`✅ 추가 성공: ${data.word}`);
        
      } else {
        console.log(`⚠️ 중복 제외: ${data.word}`);
      }
    }
    process.exit(0);
  } catch (error) {
    console.error("❌ 에러 발생:", error);
    process.exit(1);
  }
};

runSeed();