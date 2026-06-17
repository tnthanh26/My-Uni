/* eslint-disable indent */
import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();

setGlobalOptions({maxInstances: 5, region: "asia-southeast1"});

const BLACK_LIST = [
  "dit", "du", "deo", "dech", "dit me", "dm", "dmm", "dcm", "vcl", "clm",
  "oc cho", "suc vat", "rac ruoi", "chet di", "cut", "bien di",
  "phan dong", "ba que",
];

const SENSITIVE_LIST = [
  "lua dao", "scam", "da cap", "viec nhe luong cao",
  "kiem tien online", "chuyen khoan truoc", "coc truoc",
  "dau tu loi nhuan cao", "cam ket loi nhuan", "keo thom",
  "tay chay", "dinh cong", "bieu tinh", "boc phot",
  "thi ho", "gian lan", "quay cop", "mua diem",
  "chay diem", "fake diem", "lo de",
];

/**
 * Remove Vietnamese diacritics
 * @param {string} str input string
 * @return {string} normalized string
 */
function removeDiacritics(str: string): string {
  /* eslint-disable max-len */
  const withDia = "àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ";
  const noDia = "aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd";
  /* eslint-enable max-len */
  let result = str.toLowerCase();
  for (let i = 0; i < withDia.length; i++) {
    result = result.split(withDia[i]).join(noDia[i]);
  }
  return result;
}

/**
 * Check if content is toxic
 * @param {string} text content to check
 * @return {object} status and score
 */
function analyzeContent(text: string): { status: string; score: number } {
  if (!text) return {status: "approved", score: 0};
  const normalized = removeDiacritics(text);
  const cleanText = normalized.replace(/[^a-z0-9\s]/g, "");

  const isToxic = BLACK_LIST.some((word) =>
    new RegExp(`\\b${word}\\b`).test(cleanText)
  );
  if (isToxic) return {status: "hidden", score: 1.0};

  const isSensitive = SENSITIVE_LIST.some((word) =>
    new RegExp(`\\b${word}\\b`).test(cleanText)
  );
  if (isSensitive) return {status: "pending", score: 0.5};

  return {status: "approved", score: 0};
}

/**
 * Process moderation logic
 * @param {admin.firestore.DocumentSnapshot} snapshot
 * @param {string} text
 * @return {Promise<FirebaseFirestore.WriteResult>}
 */
async function processModeration(
  snapshot: admin.firestore.DocumentSnapshot,
  text: string
) {
  const analysis = analyzeContent(text);
  return snapshot.ref.update({
    status: analysis.status,
    toxicityScore: analysis.score,
    isToxicChecked: true,
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    processedBy: "LocalFilter",
  });
}

export const moderateForumPost = onDocumentCreated(
  "forum_posts/{docId}",
  (event) => {
    if (!event.data) return null;
    return processModeration(event.data, event.data.data().content || "");
  }
);

export const moderateReview = onDocumentCreated(
  "course_reviews/{docId}",
  (event) => {
    if (!event.data) return null;
    const data = event.data.data();
    const combined = `${data.courseName || ""} ${data.content || ""}`;
    return processModeration(event.data, combined);
  }
);

export const moderateMaterial = onDocumentCreated(
  "study_materials/{docId}",
  (event) => {
    if (!event.data) return null;
    const data = event.data.data();
    const combined = `${data.fileName || ""} ${data.content || ""}`;
    return processModeration(event.data, combined);
  }
);

/**
 * Chat with Ú Em via Proxy
 */
export const chatWithUEm = onCall(async (request) => {
  // 1. Security Layer: Check authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Bạn cần đăng nhập để hỏi Ú Em.");
  }

  const uid = request.auth.uid;
  const query = request.data.query;

  if (!query || typeof query !== "string") {
    throw new HttpsError("invalid-argument", "Câu hỏi không hợp lệ.");
  }

  // 2. Toxic Check (Optional but good)
  const analysis = analyzeContent(query);
  if (analysis.status === "hidden") {
    return {
      answer: "Ú Em từ chối trả lời các câu hỏi có nội dung không phù hợp. Hãy giữ văn minh nhé!",
      sources: [],
    };
  }

  // 3. Rate Limit Layer (10 questions/day)
  const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const limitRef = db.collection("usage_limits").doc(uid);
  const limitDoc = await limitRef.get();

  let count = 0;
  if (limitDoc.exists) {
    const data = limitDoc.data();
    if (data?.lastReset === today) {
      count = data?.count || 0;
    }
  }

  if (count >= 10) {
    throw new HttpsError("resource-exhausted", "Bạn đã hết 10 lượt hỏi trong hôm nay. Hẹn gặp lại vào ngày mai!");
  }

  // 4. Caching Layer
  const queryHash = crypto.createHash("md5").update(query.trim().toLowerCase()).digest("hex");
  const cacheRef = db.collection("chat_cache").doc(queryHash);
  const cacheDoc = await cacheRef.get();

  if (cacheDoc.exists) {
    const cachedData = cacheDoc.data();
    // Record usage even for cache hit
    await limitRef.set({count: count + 1, lastReset: today}, {merge: true});
    return cachedData;
  }

  // 5. Proxy to Python Server
  try {
    const response = await fetch("http://34.21.243.141:8000/chat", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({query: query}),
    });

    if (!response.ok) {
      throw new Error(`Server error: ${response.status}`);
    }

    const result = await response.json();

    // 6. Save to Cache & Update Rate Limit
    await Promise.all([
      cacheRef.set({
        answer: result.answer,
        sources: result.sources || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      limitRef.set({count: count + 1, lastReset: today}, {merge: true}),
    ]);

    return result;
  } catch (error) {
    console.error("Chatbot Proxy Error:", error);
    throw new HttpsError("internal", "Ú Em đang bận hoặc server đang bảo trì. Thử lại sau nhé!");
  }
});
