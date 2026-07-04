# 🎓 My-Uni Project Context & Architecture Overview

Welcome to the **My-Uni** project. This document serves as a comprehensive developer reference and onboarding guide, tailored specifically for AI agents and human developers alike.

---

## 📌 Project Overview
- **Name:** My-Uni
- **Core Purpose:** An Academic Companion application designed to support university students throughout their daily campus life, course progression, study schedules, deadlines, and social/official campus activities.
- **Target Audience:** Specifically optimized for HCMUS (Ho Chi Minh City University of Science) students, as featured by local imagery assets (e.g., `hcmus_bg.png`) and default academic flows.
- **Core Capabilities:** 
  - **Academic Workspace:** Class schedule calendars, manual deadlines tracking, and automated sync from university Moodle.
  - **Gemini Assistant:** Integrated AI chatbot powered by Google Generative AI to answer student queries.
  - **Campus & Social Hub:** Official announcements, student discussion forum tabs, shared study materials, and peer course reviews.
  - **Multiplatform Operation:** Mobile app client for students and a Moderation/Collaboration web panel for administrators and moderators.

---

## 🛠️ Tech Stack & Dependencies
The core settings and packaging are defined in [pubspec.yaml](file:///C:/Users/TUF/StudioProjects/My-Uni/pubspec.yaml). Key components include:

- **Framework:** Flutter ^3.10.8 (Dart SDK ^3.10.8).
- **Backend Services:** Firebase Core (`firebase_core`), Authentication (`firebase_auth`), Cloud Firestore (`cloud_firestore`), and Firebase Cloud Messaging (`firebase_messaging`).
- **AI Integration:** Google Generative AI (`google_generative_ai`) for the chatbot module.
- **State Management:** Provider pattern (`provider`) via [app_provider.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/app_provider.dart).
- **Routing:** 
  - **Mobile:** Named native routing (implemented in [main.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/main.dart)).
  - **Web:** GoRouter (`go_router`) with path strategies and auth-state redirection rules.
- **Local Persistence:** Shared Preferences (`shared_preferences`) for settings/offline scheduling, and Secure Storage (`flutter_secure_storage`) for sensitive credentials.
- **Key UI Plugins:**
  - `table_calendar`: Interactive calendar UI in the workspace.
  - `flutter_svg`: Vector graphic icon rendering.
  - `flutter_markdown`: Render Markdown formatting (e.g. for AI chatbot replies).
  - `qr_flutter` & `mobile_scanner`: QR code generation and hardware scanning for attendance tracking.

---

## 📂 Project Structure & Feature Mapping

All primary codebase logic is located in the `lib/` directory:

### 1. Credentials & Authentication (`lib/features/credential/`)
Handles user enrollment, account verification, login state, and safety gates.
- [user_status_gate.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/user_status_gate.dart): Gatekeeper checking if the user is authenticated, has complete data, or is blocked.
- [login_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/login_page.dart) / [signup_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/signup_page.dart): Core user onboarding UI.
- [otp_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/otp_page.dart) & [forgot_password_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/forgot_password_page.dart): Recovery and validation.
- [blocked_account_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/blocked_account_page.dart): Error/Moderation page for suspended users.

### 2. Home Dashboard (`lib/features/home/`)
The primary landing space for logged-in students. It is split into multiple tabs:
- [home_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/home/home_page.dart): Assembles the home dashboard, featuring an interactive animated bottom navigation.
- `official_tab.dart`: Displays official university announcements and event feeds.
- `forum_tab.dart`: Social feed allowing students to read/write posts, participate in polls, and discuss campus topics.
- `material_tab.dart`: Repository for uploading and downloading student study guides, slides, and files.
- `review_tab.dart`: Feedback loop containing reviews of classes, lecturers, and courses.

### 3. Student Workspace (`lib/features/myspace/`)
The personal hub where students coordinate academic tasks.
- [myspace_screen.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_screen.dart): Interactive dashboard displaying class calendars, task lists, and weather conditions.
- [local_storage_helper.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/local_storage_helper.dart): Custom local caching engine for schedules, deadlines, and Moodle integration settings using SharedPreferences.
- [myspace_firebase_service.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_firebase_service.dart): Syncs personal calendars and deadlines with Cloud Firestore.
- `myspace_weather_banner_section.dart` & `weather_alert_card.dart`: Integrates local weather conditions to alert students about rain or extreme weather.

### 4. Events (`lib/features/event/`)
Event discovery, category browsing, and RSVP tracking.
- `discover_event_tab.dart`: Aggregates active events sorted by category (Tech, Art, Graduation, etc.).
- `my_event_tab.dart` / `interested_event_tab.dart`: Tracks user-registered and bookmarked events.
- `create_personal_event_page.dart` / `create_community_event_page.dart`: Allows scheduling personal items or requesting official event listings.

### 5. AI Chatbot (`lib/features/chatbot/`)
- [chatbot_page.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/chatbot/chatbot_page.dart): Chat window using the Gemini SDK (`google_generative_ai`) to answer student questions and offer learning guidance.

### 6. Course & Site Search (`lib/features/search/`)
- [myuni_search_delegate.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/search/myuni_search_delegate.dart): Global search engine using Flutter SearchDelegate to search courses, forum posts, and pages.

### 7. Profile & Settings (`lib/features/account/`)
- `account_page.dart`: Profile overview showing student information, total posts, and settings link.
- `setting_page.dart`: Allows switching languages and toggling dark mode. Updates [app_provider.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/app_provider.dart) states.

### 8. Web Moderation Panel (`lib/web_mod/`)
A dedicated admin view compiling moderation workflows (only loaded when run in web context).
- [mod_dashboard.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/mod_dashboard.dart): Main administrator portal containing lists of reported posts, user lists, and post moderation.
- [collaborator_dashboard.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/collaborator_dashboard.dart): A dashboard with a subset of moderator tools.
- `student_qr_scanner_dialog.dart`: Web-based scanner for logging student attendance via event QR codes.

---

## 🔄 App Architecture & Patterns

### State Management
The project uses the `provider` state pattern:
- **Global Settings:** Managed by `AppProvider` in [app_provider.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/app_provider.dart). This holds values for:
  - Theme mode (Dark, Light, System) - persisted locally.
  - Locale (Default: `vi` - Vietnamese, supports English options).
  - Notifications toggle status.
- **Local / Feature State:** Features use dedicated controllers and repositories syncing locally or with Firestore.

### Routing Rules (Configured in [main.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/main.dart))
The app utilizes a dual-routing pattern:
- **Mobile app:** Normal MaterialApp routing (`initialRoute: '/'`) using a predefined routes map.
  - Starts with the [splash_screen.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/splash_screen.dart) (`/`), which routes to `/welcome` or `/home` based on logged-in state.
- **Web admin:** Uses GoRouter (`MaterialApp.router`).
  - Automatically filters authenticated emails. Admins (`allowedAdmins`) are redirected to `/mod`; collaborators (`allowedCollaborators`) are redirected to `/collaborator`. Others are blocked.

### Caching and Synchronization Strategy
To support robust offline capability and prevent redundant API calls:
1. **Local Reads First:** The workspace reads schedules and deadlines from [local_storage_helper.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/local_storage_helper.dart).
2. **Background Sync:** Local changes (e.g. adding a deadline) are immediately pushed to Cloud Firestore when network is available via [myspace_firebase_service.dart](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_firebase_service.dart).
3. **Moodle Scraping/Sync:** Synchronizes university academic deadlines automatically with local tasks when the Moodle credentials configuration is enabled.

---

## 🎨 Asset Guidelines

All local resources are cataloged in [pubspec.yaml](file:///C:/Users/TUF/StudioProjects/My-Uni/pubspec.yaml):
- **Icons:** SVG assets located in `assets/icons/` (e.g., `event.svg`, `space.svg`, `chat.svg`). Always use `SvgPicture.asset()` to display.
- **Meme Indicators:** Memes are used for empty states:
  - No deadlines: `assets/images/no_deadline_meme.gif`
  - No classes: `assets/images/no_class_meme.png`
- **Branding:** App logos like `logoApp.png`, `MyUni.png`, and HCMUS background `hcmus_bg.png` are stored in `assets/images/`.

---

## 📝 Coding Standards & Guidelines for AI Assistants

When developing or modifying this codebase, you **must** adhere to the following rules:

1. **Routing:**
   - For Mobile components, use standard navigator calls (e.g., `Navigator.pushNamed(context, '/routeName')`). Do not mix with GoRouter paths unless explicitly refactoring the mobile route engine.
   - For Web components (`lib/web_mod/`), use GoRouter context navigation (e.g., `context.go('/mod')`).

2. **UI & Theme Synchronization:**
   - Always reference colors and sizes from the configured active `Theme.of(context)` system. Do not hardcode raw colors (`0xFF...`) in views.
   - Support responsiveness by testing widgets against different device bounds using `MediaQuery` or `LayoutBuilder` blocks.

3. **Data Updates:**
   - Any modifications to student schedules or deadlines MUST call the appropriate method in [LocalStorageHelper](file:///C:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/local_storage_helper.dart) to persist changes offline, and then update remote Firestore if connected.

4. **Localization and Date Formatting:**
   - Always use the `intl` package for formatting currency, numbers, and dates.
   - Use the `timeago` package to format user-friendly post/comment timestamps relative to the current time.
