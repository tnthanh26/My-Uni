/* eslint-disable indent */
import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

setGlobalOptions({maxInstances: 5, region: "asia-southeast1"});

const BLACK_LIST = [
  "dit", "du", "deo", "dech", "dit me", "dm", "dmm", "dcm", "vcl", "clm"
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
