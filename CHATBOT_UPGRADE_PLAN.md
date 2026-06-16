# My-Uni Chatbot Upgrade Plan

## Context
- **Project:** My-Uni (HCMUS Academic Companion)
- **Feature:** "Ú Em" Chatbot (RAG-based)
- **Current State:** Using a direct server call to FastAPI with Gemini API Key.
- **Upgrade Goal:** Production-ready, cost-optimized, and secure.

## The Strategy: "The 4-Layer Shield"
1. **Security Layer:** Use Firebase ID Token (JWT) from Flutter to FastAPI for authentication.
2. **Rate Limit Layer:** Limit users to 20 questions/day using Firestore (`usage_limits` collection).
3. **Caching Layer:** Implement Hash-based caching in Firestore (`chat_cache` collection) to avoid redundant LLM calls.
4. **Optimization Layer:** Migrate/Stay on Gemini 1.5 Flash for the best price-performance ratio.

## Technical Details
- **Backend:** FastAPI (Python), LangChain, ChromaDB.
- **Frontend:** Flutter, Provider, Firebase Auth.
- **Model:** `gemini-1.5-flash`.
- **Database:** Firestore (for limits and cache).

## Next Steps for Tomorrow
1. Set up `firebase-admin` on the FastAPI server.
2. Implement the Middleware for Authentication & Rate Limiting.
3. Add logic for Caching question/answer pairs.
4. Update `lib/features/chatbot/chatbot_page.dart` to include the `Authorization` header.
