/* eslint-disable indent */
import {setGlobalOptions} from "firebase-functions/v2";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import axios from "axios";

admin.initializeApp();

const db = admin.firestore();

setGlobalOptions({maxInstances: 5, region: "asia-southeast1"});

const UNACCENTED_BLACK_LIST = [
  "dm", "dmm", "dcm", "clm", "vcl", "vkl", "đm", "đmm", "đcm", "cmn", "cl",
  "dit me", "djt me", "ditme", "djtme", "địt mẹ", "địt cụ", "dit cu", "địt cụ mày",
  "du ma", "duma", "du me", "dume", "đụ mẹ", "đụ má",
  "deo me", "deome", "đéo mẹ", "đéo cụ",
  "oc cho", "suc vat", "rac ruoi", "chet di", "bien di",
  "phan dong", "ba que",
  "dit nhau", "djt nhau", "chich nhau",
];

const ACCENTED_BLACK_LIST = [
  "địt", "đụ", "đéo", "cút", "lồn", "cặc", "buồi", "đĩ", "chịch", "nện", "phịch",
];

const UNACCENTED_SENSITIVE_LIST = [
  "lua dao", "scam", "da cap", "viec nhe luong cao",
  "kiem tien online", "chuyen khoan truoc", "coc truoc",
  "dau tu loi nhuan cao", "cam ket loi nhuan", "keo thom",
  "tay chay", "dinh cong", "bieu tinh", "boc phot",
  "thi ho", "gian lan", "quay cop", "mua diem",
  "chay diem", "fake diem", "lo de",
  "ca do", "danh bai", "danh bac", "casino", "nha cai",
];

const ACCENTED_SENSITIVE_LIST = [
  "cọc", "kèo", "cò", "lừa", "độ",
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
 * Helper to match a whole word or phrase in a preprocessed text
 * @param {string} cleanText preprocessed text
 * @param {string} targetWord word or phrase to match
 * @return {boolean} true if found as a whole word/phrase
 */
function matchWord(cleanText: string, targetWord: string): boolean {
  const escapedWord = targetWord.replace(/\s+/g, "\\s+");
  const regex = new RegExp(`(^|\\s)${escapedWord}(\\s|$)`);
  return regex.test(cleanText);
}

/**
 * Check if content is toxic
 * @param {string} text content to check
 * @return {object} status and score
 */
function analyzeContent(text: string): { status: string; score: number } {
  if (!text) return {status: "approved", score: 0};

  // 1. Prepare raw text with Vietnamese characters (replace punctuation with space)
  const cleanAccented = text.toLowerCase()
    .replace(/[^a-z0-9àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ\s]/gi, " ");

  // 2. Prepare unaccented text (remove diacritics and replace punctuation with space)
  const normalized = removeDiacritics(text.toLowerCase());
  const cleanUnaccented = normalized.replace(/[^a-z0-9\s]/gi, " ");

  // 3. Match against Blacklists
  const isAccentedToxic = ACCENTED_BLACK_LIST.some((word) =>
    matchWord(cleanAccented, word)
  );
  const isUnaccentedToxic = UNACCENTED_BLACK_LIST.some((word) =>
    matchWord(cleanUnaccented, word)
  );
  if (isAccentedToxic || isUnaccentedToxic) {
    return {status: "hidden", score: 1.0};
  }

  // 4. Match against Sensitive lists
  const isAccentedSensitive = ACCENTED_SENSITIVE_LIST.some((word) =>
    matchWord(cleanAccented, word)
  );
  const isUnaccentedSensitive = UNACCENTED_SENSITIVE_LIST.some((word) =>
    matchWord(cleanUnaccented, word)
  );
  if (isAccentedSensitive || isUnaccentedSensitive) {
    return {status: "pending", score: 0.5};
  }

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

  // 5. Fetch Python Server URL from Firestore
  let serverUrl = "https://34-21-243-141.sslip.io/chat";
  try {
    const configDoc = await db.collection("system_config").doc("chatbot").get();
    if (configDoc.exists) {
      const data = configDoc.data();
      if (data && data.server_url) {
        serverUrl = data.server_url;
      }
    }
  } catch (error) {
    console.error("Error fetching chatbot server URL config:", error);
  }

  // 6. Proxy to Python Server
  try {
    const response = await fetch(serverUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({query: query}),
    });

    if (!response.ok) {
      throw new Error(`Server error: ${response.status}`);
    }

    const result = await response.json();

    // 7. Save to Cache & Update Rate Limit
    const expireDate = new Date();
    expireDate.setDate(expireDate.getDate() + 30); // Cache expires after 30 days

    await Promise.all([
      cacheRef.set({
        answer: result.answer,
        sources: result.sources || [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expireAt: admin.firestore.Timestamp.fromDate(expireDate),
      }),
      limitRef.set({count: count + 1, lastReset: today}, {merge: true}),
    ]);

    return result;
  } catch (error) {
    console.error("Chatbot Proxy Error:", error);
    throw new HttpsError("internal", "Ú Em đang bận hoặc server đang bảo trì. Thử lại sau nhé!");
  }
});

/**
 * Semantic Search via Proxy
 */
export const semanticSearch = onCall(async (request) => {
  // 1. Security Layer: Check authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Bạn cần đăng nhập để thực hiện tìm kiếm.");
  }

  const {query, scope, tag, sort} = request.data;

  // 2. Fetch Python Server URL from Firestore
  let serverUrl = "https://34-142-139-17.sslip.io/search";
  try {
    const configDoc = await db.collection("system_config").doc("search").get();
    if (configDoc.exists) {
      const data = configDoc.data();
      if (data && data.server_url) {
        serverUrl = data.server_url;
      }
    }
  } catch (error) {
    console.error("Error fetching search server URL config:", error);
  }

  // 3. Proxy to Python Server (GET request with query params)
  try {
    const urlObj = new URL(serverUrl);
    if (query !== undefined && query !== null) {
      urlObj.searchParams.append("query", String(query));
    }
    if (scope !== undefined && scope !== null) {
      urlObj.searchParams.append("scope", String(scope));
    }
    if (tag !== undefined && tag !== null) {
      urlObj.searchParams.append("tag", String(tag));
    }
    if (sort !== undefined && sort !== null) {
      urlObj.searchParams.append("sort", String(sort));
    }

    const response = await fetch(urlObj.toString(), {
      method: "GET",
    });

    if (!response.ok) {
      throw new Error(`Search server error: ${response.status}`);
    }

    const result = await response.json();
    return result;
  } catch (error) {
    console.error("Semantic Search Proxy Error:", error);
    throw new HttpsError("internal", "Tìm kiếm đang gặp sự cố hoặc server đang bảo trì. Thử lại sau nhé!");
  }
});

/**
 * Daily cleanup for accounts scheduled for deletion (deleted after 3 days)
 */
export const cleanupDeletedAccounts = onSchedule("0 0 * * *", async () => {
  const now = admin.firestore.Timestamp.now();
  const expiredUsersQuery = await db.collection("users")
    .where("status", "==", "deleting")
    .where("scheduledDeleteAt", "<=", now)
    .get();

  if (expiredUsersQuery.empty) {
    console.log("No accounts scheduled for deletion at this time.");
    return;
  }

  const batch = db.batch();
  const promises: Promise<void>[] = [];

  for (const doc of expiredUsersQuery.docs) {
    const uid = doc.id;
    console.log(`Processing deletion for user UID: ${uid}`);

    // 1. Queue Firestore user document deletion
    batch.delete(doc.ref);

    // 2. Queue Firebase Auth user deletion
    promises.push(
      admin.auth().deleteUser(uid)
        .then(() => {
          console.log(`Successfully deleted Auth account for user UID: ${uid}`);
        })
        .catch((error) => {
          console.error(`Error deleting Auth account for user UID: ${uid}`, error);
        })
    );
  }

  // Commit firestore document deletions
  await batch.commit();
  // Wait for all Auth account deletions to complete
  await Promise.all(promises);
  console.log(`Cleaned up ${expiredUsersQuery.size} accounts.`);
});

/**
 * Gửi mã OTP đăng ký tài khoản (không tiết lộ trạng thái email)
 */
export const sendRegistrationOTP = onCall(async (request) => {
  const email = request.data.email;
  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Email không hợp lệ.");
  }

  try {
    // 1. Kiểm tra xem email đã tồn tại trong Auth chưa
    let emailExists = true;
    try {
      await admin.auth().getUserByEmail(email);
    } catch (error) {
      const err = error as {code?: string};
      if (err.code === "auth/user-not-found") {
        emailExists = false;
      } else {
        throw error;
      }
    }

    if (emailExists) {
      // Gửi email báo trùng tài khoản qua EmailJS
      await axios.post(
        "https://api.emailjs.com/api/v1.0/email/send",
        {
          service_id: "service_1oynodg",
          template_id: "template_4g8950q",
          user_id: "0JWFYtrABC8w_Cfcp",
          template_params: {
            user_email: email,
            from_name: "Đội ngũ phát triển MyUni",
          },
        },
        {
          headers: {
            "Content-Type": "application/json",
            "origin": "http://localhost",
          },
        }
      );
    } else {
      // Sinh mã OTP 6 số
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const expiresAt = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 60 * 1000));

      // Lưu OTP tạm vào Firestore
      await db.collection("pending_otps").doc(email).set({
        otp: otp,
        expiresAt: expiresAt,
      });

      // Gửi email chứa OTP qua EmailJS
      await axios.post(
        "https://api.emailjs.com/api/v1.0/email/send",
        {
          service_id: "service_1oynodg",
          template_id: "template_3ftz8sr",
          user_id: "0JWFYtrABC8w_Cfcp",
          template_params: {
            user_email: email,
            otp_code: otp,
            from_name: "Đội ngũ phát triển MyUni",
          },
        },
        {
          headers: {
            "Content-Type": "application/json",
            "origin": "http://localhost",
          },
        }
      );
    }

    // Luôn luôn trả về thành công
    return {success: true};
  } catch (error) {
    console.error("sendRegistrationOTP Error:", error);
    const err = error as Error;
    throw new HttpsError("internal", "Lỗi gửi mã xác thực: " + err.message);
  }
});

/**
 * Xác thực OTP và tiến hành tạo tài khoản người dùng
 */
export const verifyOTPAndCreateUser = onCall(async (request) => {
  const {email, otp, userData} = request.data;
  if (!email || !otp || !userData) {
    throw new HttpsError("invalid-argument", "Thiếu thông tin xác thực.");
  }

  const {displayName, password, university, studentId, cohort} = userData;
  if (!displayName || !password || !university || !studentId || !cohort) {
    throw new HttpsError("invalid-argument", "Thiếu thông tin người dùng.");
  }

  try {
    // 1. Kiểm tra OTP
    const otpDocRef = db.collection("pending_otps").doc(email);
    const otpDoc = await otpDocRef.get();

    if (!otpDoc.exists) {
      throw new HttpsError("invalid-argument", "Mã OTP không tồn tại hoặc đã hết hạn.");
    }

    const otpData = otpDoc.data();
    if (!otpData) {
      throw new HttpsError("internal", "Lỗi dữ liệu OTP.");
    }

    const expiresAt = otpData.expiresAt as admin.firestore.Timestamp;
    if (expiresAt.toDate() < new Date()) {
      await otpDocRef.delete();
      throw new HttpsError("invalid-argument", "Mã OTP đã hết hạn. Vui lòng gửi lại.");
    }

    if (otpData.otp !== otp) {
      throw new HttpsError("invalid-argument", "Mã OTP không chính xác.");
    }

    // 2. Tạo tài khoản Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    // 3. Tạo Firestore profile
    await db.collection("users").doc(userRecord.uid).set({
      displayName: displayName,
      email: email,
      university: university,
      studentId: studentId,
      cohort: cohort,
      faculty: null,
      dob: "",
      photoUrl: "",
      status: "active",
      isBanned: false,
      role: "student",
      isVerified: true,
      verificationMethod: "edu_email_otp",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verificationLevel: "student",
      violationCount: 0,
      suspensionCount: 0,
      lastBanReason: "",
      lastViolationAt: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Dọn dẹp OTP tạm
    await otpDocRef.delete();

    // 5. Sinh custom token để đăng nhập trên client
    const customToken = await admin.auth().createCustomToken(userRecord.uid);

    return {success: true, customToken: customToken};
  } catch (error) {
    console.error("verifyOTPAndCreateUser Error:", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    const err = error as {code?: string; message?: string};
    if (err.code === "auth/email-already-in-use") {
      throw new HttpsError("already-exists", "Email này đã được đăng ký.");
    }
    throw new HttpsError("internal", "Lỗi tạo tài khoản: " + (err.message || ""));
  }
});

