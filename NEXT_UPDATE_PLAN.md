# My-Uni Next Update Plan (Proxy Architecture & Content Moderation)

## Context
- **Project:** My-Uni (HCMUS Academic Companion)
- **Features:** 
  1. **"Ú Em" Chatbot (RAG-based):** Secure conversational AI assistant.
  2. **Semantic Search:** Shady link/IP hiding and secure vector search queries.
  3. **Global Content Moderation:** Filtering user-generated content (posts, reviews, materials) locally.
- **Upgrade Goal:** Production-ready, cost-optimized, secure, and robust system.

---

## Architectural Shift: "Firebase API Gateway"
Initially, all security and validation layers were planned directly on the Python FastAPI server. **To protect the FastAPI server IP, reduce direct load, and leverage Firebase Auth & Firestore caching, we implemented a proxy architecture using Firebase Cloud Functions.**

### 1. Chatbot Proxy (`chatWithUEm`) - 4-Layer Shield
1. **Security Layer:** Rejects anonymous requests automatically based on `request.auth` context.
2. **Rate Limit Layer:** Limit users to **10 questions/day** using Firestore (`usage_limits` collection).
3. **Caching Layer:** MD5 Hash-based caching in Firestore (`chat_cache` collection) to return instant answers for duplicate questions.
4. **Content Filter:** Built-in split-matching filter to reject toxic inputs locally.

### 2. Semantic Search Proxy (`semanticSearch`) - 2-Layer Shield
1. **Security Layer:** Rejects unauthenticated requests based on the caller's Firebase Auth context.
2. **Configuration Hiding Layer:** Hides the Python server IP and search endpoint URL from the client. Dynamic retrieval of the FastAPI endpoint from Firestore makes server migration seamless without requiring client-side updates.

---

## Global Content Moderation System
The same TypeScript filtering module (`analyzeContent`) runs on Firestore document triggers to moderate user-generated content before it becomes visible:

### 1. The Split Matching Logic (Resolving Accented Collisions)
To prevent normal words with accents (e.g. `du lịch`, `dự án`, `con cóc`, `kéo co`) from colliding with stripped toxic/sensitive words, the lists are split:
- **Accented Lists (`ACCENTED_BLACK_LIST`, `ACCENTED_SENSITIVE_LIST`):** Only matches target words containing specific accented letters (e.g., `địt`, `đụ`, `đéo`, `cút`, `lồn`, `cọc`, `kèo`, `cò`).
- **Unaccented/Acronym Lists (`UNACCENTED_BLACK_LIST`, `UNACCENTED_SENSITIVE_LIST`):** Matches acronyms and phrases that are always toxic/sensitive regardless of accent and have no safe Vietnamese vocabulary collisions (e.g., `dm`, `vcl`, `djt me`, `lua dao`, `scam`).
- **Vietnamese Boundary Helper (`matchWord`):** Preprocesses strings by replacing all punctuation with spaces and checking for whole words using regex `(^|\s)word(\s|$)` to bypass the broken standard JavaScript `\b` boundary which does not support Vietnamese characters.

### 2. Cloud Function Triggers
- **`moderateForumPost` (`forum_posts/{docId}`):** Scans the content of new forum posts.
- **`moderateReview` (`course_reviews/{docId}`):** Scans the course name and content of course reviews.
- **`moderateMaterial` (`study_materials/{docId}`):** Scans the file name and content of study materials.

### 3. Frontend & Database Flow
- Newly created/modified posts, reviews, and materials are initialized with `'status': 'pending'` on the frontend (`create_post_page.dart`, `create_review_page.dart`, `create_material_page.dart`).
- Item feeds query Firestore using `.where('status', isEqualTo: 'approved')` to only show moderated content.

---

## Technical Details

### Backend Infrastructure
- **Proxy Environment:** Firebase Cloud Functions (TypeScript).
  - **Runtime:** **Node 24** (upgraded from Node 18 in `package.json`).
  - **Region:** Singapore (`asia-southeast1`) for low-latency responses.
  - **Compiler Config:** Added `skipLibCheck: true` to `tsconfig.json` for clean builds.
- **AI / RAG Servers:** Python FastAPI backend.
- **Dynamic Configuration:**
  - Chatbot server URL is fetched from Firestore `system_config/chatbot` (`server_url`), falling back to `https://34-21-243-141.sslip.io/chat`.
  - Search server URL is fetched from Firestore `system_config/search` (`server_url`), falling back to `https://34-142-139-17.sslip.io/search`.

### Frontend Connection Details
The Flutter client communicates with Cloud Function proxies:
1. **Chatbot Endpoint:** `https://asia-southeast1-myuni-fe6d1.cloudfunctions.net/chatWithUEm`
   - Request wrapped in a `"data"` key: `{"data": {"query": userText}}` with UTF-8 encoding.
   - Extracts answer from `data['result']['answer']` or parses `data['error']['message']` on rate-limit errors.
2. **Semantic Search Endpoint:** `https://asia-southeast1-myuni-fe6d1.cloudfunctions.net/semanticSearch`
   - Request payload sent as: `{"data": {"query": cleanQuery, "scope": scopeString, "tag": tagParam, "sort": sortOrder}}`.
   - Returns a `List<dynamic>` of search items parsed from `data['result']`.

---

## Current Status & Next Steps
- [x] **Infrastructure Setup:** Configured Node 24 and Singapore region for Cloud Functions.
- [x] **Chatbot Proxy Function:** Implemented `chatWithUEm` with all 4 shields and dynamic Firestore URL configuration.
- [x] **Search Proxy Function:** Implemented `semanticSearch` with security check and dynamic search server URL retrieval.
- [x] **Global Moderation Triggers:** Implemented Firestore triggers (`moderateForumPost`, `moderateReview`, `moderateMaterial`) using local content filters.
- [x] **Chatbot Frontend Integration:** Updated `chatbot_page.dart` to call the Callable Cloud Function proxy and gracefully handle errors.
- [x] **Search Frontend Integration:** Updated `myuni_search_delegate.dart` to call the `semanticSearch` Cloud Function and extract query results.
- [x] **Content Submission Status:** Configured frontend creation pages to submit items as `'status': 'pending'` and list screens to only show `'approved'` content.
- [ ] **Next Action:** Perform end-to-end integration tests once the Cloud Functions are fully deployed and the Firestore configuration database is online.
