# MyUni - Hyperlocal Campus Platform

> **MyUni** is a multifunctional mobile application and Web administration platform designed for Vietnamese university students. It combines academic productivity tools, campus community interaction, and an AI-powered student assistant.

---

## Key Features

### 1. Authentication & Identity Management
* Institutional email verification (`@vnu.edu.vn`) ensuring a trusted academic environment.
* Role-based access control (Student, Collaborator, Moderator).

### 2. Community Module
* **Official News:** Verified campus announcements with automated daily AI news summaries.
* **Forum:** Interactive discussion environment supporting hashtags, comments, reactions, and anonymous posting.
* **Course Reviews:** Student learning experience sharing, instructor ratings, and course workload reviews.
* **Study Materials:** Educational resource repository for lecture notes, exam papers, and filtering.

### 3. Academic Management (MySpace)
* **MySpace Workspace:** Calendar-oriented personal academic schedule timeline.
* **Moodle Synchronization:** Automated LMS course and deadline sync with local credential encryption via `Flutter Secure Storage`.
* **Deadline Tracker:** Assignment deadline management with proactive push notifications (FCM).
* **Weather Service:** Personalized weather forecast widget for indoor/outdoor schedule planning (OpenWeatherMap API).

### 4. Campus Events & QR Attendance
* Extracurricular event discovery, details, and registration.
* Built-in mobile camera QR code scanner for real-time event attendance verification.

### 🤖 5. Intelligent Search & AI Assistant
* **Semantic Search:** Vector-based search engine on the main search bar for discovering community posts, official announcements, forum discussions, and study materials based on query intent and semantic similarity.
* **AI Chatbot (RAG):** Conversational student assistant utilizing Retrieval-Augmented Generation, powered by serverless Firebase Cloud Functions and the Google Gemini API.

### 🖥️ 6. Administration Web Panel
* Desktop-optimized responsive Web Application:
  * **Moderator Panel:** Content moderation interface for reviewing and resolving reported posts.
  * **Collaborator Panel:** Event management dashboard and live QR attendance code generator.

---

## 🛠️ Tech Stack & Architecture

* **Mobile Client:** Flutter (Dart) - Cross-platform Android & iOS.
* **Web Portal:** Flutter Web Application (Desktop Browser Optimized).
* **Backend Infrastructure:** Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Messaging).
* **Serverless API Gateway:** Firebase Cloud Functions (Region `asia-southeast1`).
* **AI & RAG Pipeline:** Google Gemini API (`Gemini 1.5 Flash`) + Vector Database.
* **Local Security Storage:** `flutter_secure_storage` (Keychain for iOS & Keystore for Android).

---

## 💻 Getting Started

### Prerequisites
* Flutter SDK (`>= 3.0.0`)
* Dart SDK
* Android Studio / VS Code

### Setup & Execution
1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/My-Uni.git
   cd My-Uni
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the mobile application:**
   ```bash
   flutter run
   ```

4. **Run the administration Web panel:**
   ```bash
   flutter run -d chrome
   ```
