# 🎓 My-Uni Project Context for Gemini CLI

## 📌 Project Overview
- **Name:** My-Uni
- **Type:** Flutter Mobile Application (Academic Companion)
- **Target:** University students (specifically optimized for HCMUS students based on assets like `hcmus_bg.png`).
- **Framework:** Flutter ^3.10.8 (Dart).
- **Backend:** Firebase (Core, Auth, Firestore, Messaging).

## 📂 Project Structure (`lib/`)
- `lib/features/`: Main modules of the app.
  - `credential/`: Auth flows (Login, Register).
  - `home/`: Dashboard, news, and daily overview.
  - `event/`: Discovery (`discover_event_tab.dart`), categories (Tech, Art, Graduation, etc.).
  - `myspace/`: Student workspace.
    - `models/`: `myspace_models.dart`, `weather_models.dart`.
    - `services/`: Weather coordination, local storage.
    - `myspace_screen.dart`: UI for schedule and deadlines.
  - `chatbot/`: AI assistant integration.
  - `notification/`: Push & local notification management.
  - `account/`: Profile management.
  - `services/`: Global services like Firebase and HTTP.
- `lib/models/`: Global data entities.
- `lib/web_mod/`: Web-specific modules or integrations.
- `main.dart`: Entry point.
- `app_provider.dart`: Global State management (Provider).
- `splash_screen.dart`: Initial loading screen.

## 🛠️ Tech Stack & Key Dependencies
- **State Management:** `provider`
- **Routing:** `go_router`
- **AI:** `google_generative_ai` (Gemini SDK)
- **Database:** `cloud_firestore`
- **Local Storage:** `shared_preferences`, `flutter_secure_storage`
- **UI Components:** `table_calendar`, `flutter_markdown`, `flutter_svg`, `qr_flutter`.
- **Media/Files:** `image_picker`, `flutter_image_compress`, `file_picker`, `open_filex`.
- **System:** `permission_handler`, `path_provider`, `url_launcher`.
- **Notifications:** `flutter_local_notifications`, `firebase_messaging`, `timezone`.

## 🎨 Assets & Resources
- **Icons:** SVG format in `assets/icons/` (event, chat, space, account, home).
- **Images:** `assets/images/`
  - Themes: `hcmus_bg.png`, `background.jpg`.
  - Event categories: tech, art, sport, job, scholarship, etc.
  - App: `logoApp1.png`, `MyUni.png`, `chatbot_avt.png`.
  - Memes: `no_deadline_meme.gif`, `no_class_meme.png`.

## 📝 Coding Standards
- Use **GoRouter** for all navigation.
- Use **Provider** for state management and follow the repository/service pattern.
- Localization/Formatting: Use `intl` for dates and `timeago` for relative timestamps.
- **Responsiveness:** Ensure layouts handle different device sizes (use `MediaQuery` or `LayoutBuilder`).
- **Firebase:** All remote data must be synced with local storage (`LocalStorageHelper`) for offline support where applicable.
