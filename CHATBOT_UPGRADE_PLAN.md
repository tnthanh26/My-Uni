# My-Uni Chatbot Upgrade Plan

## Context
- **Project:** My-Uni (HCMUS Academic Companion)
- **Feature:** "Ú Em" Chatbot (RAG-based)
- **Current State:** Using a direct HTTP POST call from the Flutter app to the FastAPI server. The app passes an ID Token for Auth and handles 429 status codes.
- **Upgrade Goal:** Production-ready, cost-optimized, and secure.

## Architectural Shift: "Firebase API Gateway"
Initially, the plan was to implement all security layers directly on the Python FastAPI server. **However, to ensure better security (hiding the server IP) and faster database interactions, we have shifted to a Proxy Architecture using Firebase Cloud Functions.**

### The 4-Layer Shield (Implemented in Cloud Functions)
1. **Security Layer:** Firebase Cloud Functions automatically verify the user's authentication context. The function rejects anonymous requests and forwards a validated request to Python.
2. **Rate Limit Layer:** Limit users to 20 questions/day using Firestore (`usage_limits` collection). Evaluated before pinging the AI.
3. **Caching Layer:** Implement MD5 Hash-based caching in Firestore (`chat_cache` collection) to return instant answers for duplicate questions, saving LLM costs.
4. **Content Filter:** Built-in blacklists and sensitive word filters to reject toxic prompts locally.

## Technical Details
- **Backend (Proxy):** Firebase Cloud Functions (TypeScript/Node.js).
- **Backend (AI):** FastAPI (Python), LangChain, ChromaDB.
- **Frontend:** Flutter, HTTP.
- **Model:** `gemini-1.5-flash`.
- **Database:** Firestore (for limits and cache).

## Current Status & Next Steps
- [x] **Frontend:** Updated `chatbot_page.dart` to extract Firebase ID Token and handle `429 Too Many Requests`.
- [x] **Proxy:** Developed the `chatWithUEm` Cloud Function in `functions/src/index.ts` with all 4 layers.
- [ ] **Pending Integration:** The Cloud Functions deployment is temporarily paused. The Flutter app is currently reverted to use the direct HTTP call `http://34.21.243.141:8000/chat`.
- [ ] **Next Action:** Focus on refining and finding the best API constraint/model for the Python FastAPI server. Once the Python server is finalized, deploy the Firebase Cloud Function and reconnect the App to use the secure proxy.
