# 🎓 My-Uni Project Context & Architecture Overview

Welcome to the **My-Uni** project. This document serves as a comprehensive developer reference and onboarding guide, detailing the mobile client, web admin panels, and backend cloud functions.

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
The core settings and packaging are defined in [pubspec.yaml](file:///c:/Users/TUF/StudioProjects/My-Uni/pubspec.yaml). Key components include:

- **Framework:** Flutter ^3.10.8 (Dart SDK ^3.10.8).
- **Backend Services:** Firebase Core (`firebase_core`), Authentication (`firebase_auth`), Cloud Firestore (`cloud_firestore`), and Firebase Cloud Messaging (`firebase_messaging`).
- **AI Integration:** Google Generative AI (`google_generative_ai`) for the chatbot module.
- **State Management:** Provider pattern (`provider`) via [app_provider.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/app_provider.dart).
- **Routing:** 
  - **Mobile:** Named native routing (implemented in [main.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/main.dart)).
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
- [user_status_gate.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/user_status_gate.dart): Gatekeeper checking if the user is authenticated, has complete data, or is blocked.
- [login_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/login_page.dart) / [signup_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/signup_page.dart): Core user onboarding UI.
- [otp_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/otp_page.dart) & [forgot_password_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/forgot_password_page.dart): Recovery and validation.
- [blocked_account_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/blocked_account_page.dart): Error/Moderation page for suspended users.
- [deleting_account_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/credential/deleting_account_page.dart): UI warning page for accounts scheduled for deletion. Allows students to cancel the request and restore their status to active within 3 days.

### 2. Home Dashboard (`lib/features/home/`)
The primary landing space for logged-in students. It is split into multiple tabs and interactive cards:
- [home_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/home_page.dart): Assembles the home dashboard layout.
- [animated_bottom_nav.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/animated_bottom_nav.dart): Interactive, animated bottom navigation bar.
- `official_tab.dart`: Displays official university announcements and event feeds.
- [daily_digest_card.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/daily_digest_card.dart): Retrieves and displays daily generative AI summaries of announcements.
- `forum_tab.dart`: Social feed allowing students to read/write posts, participate in polls, and discuss campus topics.
- `material_tab.dart`: Repository for uploading and downloading student study guides, slides, and files.
- `review_tab.dart`: Feedback loop containing reviews of classes, lecturers, and courses.
- [create_post_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/create_post_page.dart) / [create_material_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/create_material_page.dart) / [create_review_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/create_review_page.dart): Forms to submit content, posts, reviews, or materials. Features real-time autocomplete suggestions for course and lecturer inputs using [CourseTeacherData](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/utils/course_teacher_data.dart) and [SearchableAutocompleteField](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/widgets/searchable_autocomplete_field.dart). Runs pre-submit checks against a local sensitive-word blacklist.
- [post_detail_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/post_detail_page.dart) / [post_action_row.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/post_detail_page.dart): Renders detailed post discussions with nested comment trees. Features real-time Firestore stream subscriptions (`snapshots()`) for instant post edit updates, graceful `onError` stream error handling, and optimized whitespace rendering when post content is empty.
- [poll_widget.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/poll_widget.dart): Displays interactive posts containing votes or surveys.
- [onboarding_dialog.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/home/onboarding_dialog.dart): Introductory onboarding helper dialog for new students.

### 3. Student Workspace (`lib/features/myspace/`)
The personal hub where students coordinate academic tasks.
- [myspace_screen.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_screen.dart): Interactive dashboard displaying class calendars, task lists, and weather conditions. Features a 24-hour grid (`00:00` to `23:00`) with smooth auto-scroll focus to the first class of the day.
- [myspace_deadline_section.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_deadline_section.dart): Groups student deadlines into clear timeframes ("Trong 7 ngày tới" and "Xa hơn (Trên 7 ngày)").
- [local_storage_helper.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/local_storage_helper.dart): Custom local caching engine for schedules, deadlines, and Moodle integration settings using SharedPreferences.
- [myspace_firebase_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_firebase_service.dart): Syncs personal calendars and deadlines with Cloud Firestore.
- [myspace_weather_banner_section.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_weather_banner_section.dart) & [weather_alert_card.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/weather_alert_card.dart): Integrates local weather conditions to alert students about rain or extreme weather.
- [campus_data.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/campus_data.dart): Static data defining HCMUS campus buildings, rooms, locations, and coordinates.
- [create_deadlines_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/create_deadlines_page.dart) & [create_schedule_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/create_schedule_page.dart): Manual deadline and schedule entry forms.
- **Services:**
    - [moodle_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/services/moodle_service.dart): Syncs university academic deadlines automatically from the Moodle API using REST endpoints (`core_calendar_get_calendar_upcoming_view`).
    - [moodle_token_storage.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/services/moodle_token_storage.dart): Secure token storage for Moodle integration credentials.
    - [weather_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/services/weather_service.dart): Open-Meteo REST API wrapper for hourly forecasts.
    - [weather_alert_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/services/weather_alert_service.dart): Analyzes forecasts during scheduled class times to determine alert levels (giông sét, mưa to, mưa nhẹ).
    - [myspace_weather_coordinator.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/services/myspace_weather_coordinator.dart): Intermediary connecting schedules, weather forecasts, and locations to publish UI-ready weather alerts.

### 4. Events (`lib/features/event/`)
Event discovery, category browsing, and RSVP tracking.
- `discover_event_tab.dart`: Aggregates active events sorted by category (Tech, Art, Graduation, etc.).
- `my_event_tab.dart` / `interested_event_tab.dart`: Tracks user-registered and bookmarked events.
- `create_personal_event_page.dart` / `create_community_event_page.dart`: Allows scheduling personal items or requesting official event listings.
- [event_qr_scanner_dialog.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/event/event_qr_scanner_dialog.dart): Dialog utilizing hardware camera scan logic for student attendance.
- `student_attendance_history_tab.dart`: Lists events attended by the student.

### 5. AI Chatbot (`lib/features/chatbot/`)
- [chatbot_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/chatbot/chatbot_page.dart): Chat window using the Gemini SDK to answer student questions and offer learning guidance. Queries are proxied through a secure Cloud Function backend.

### 6. Course & Site Search (`lib/features/search/`)
- [myuni_search_delegate.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/search/myuni_search_delegate.dart): Global search engine using Flutter SearchDelegate to search courses, forum posts, and pages.
- [course_review_list_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/search/course_review_list_page.dart): Lists reviews and ratings written for a specific lecturer or course.

### 7. Profile & Settings (`lib/features/account/`)
- `account_page.dart`: Profile overview showing student information, total posts, and settings link.
- `setting_page.dart`: Allows switching languages and toggling dark mode. Updates [app_provider.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/app_provider.dart) states.
- [change_password_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/account/change_password_page.dart) / [edit_profile_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/account/edit_profile_page.dart): Profile settings details.
- [department_contacts_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/account/department_contacts_page.dart): Searchable contact phone book for school departments and staff.
- [utilities_page.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/account/utilities_page.dart): Dashboard containing links to the student portal, Moodle, training points (DRL), fees, handbook, etc.

### 8. Global Services & Helpers (`lib/features/services/` & `lib/utils/`)
- [course_teacher_data.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/utils/course_teacher_data.dart): Embedded dataset containing 30 HCMUS courses and 46 professors. Implements a hybrid sync architecture with Cloud Firestore collection `hcmus_courses_teachers` (documents: `courses` and `teachers`) to auto-seed and dynamically register new custom items.
- [searchable_autocomplete_field.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/widgets/searchable_autocomplete_field.dart): Custom reusable Flutter widget providing an overlay dropdown for real-time text filtering and selection.
- [content_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/services/content_service.dart): Client-side word filter utilizing regex patterns to match accented/unaccented Vietnamese toxic and sensitive terms.
- [daily_active_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/services/daily_active_service.dart): Registers a login activity record under the `daily_active_users` collection for analytics.
- [notification_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/services/notification_service.dart): Handles FCM push configurations, listens to Firestore collections, manages 1-to-1 chat notifications, and schedules local notifications.

### 9. Web Moderation & Collaborator Panels (`lib/web_mod/`)
A dedicated admin view compiling moderation workflows (loaded in web context).
- [mod_dashboard.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/mod_dashboard.dart): Main administrator portal containing lists of reported posts, user lists, and post moderation.
- [collaborator_dashboard.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/collaborator_dashboard.dart): Dashboard with collaborator tools.
- **Collaborator Sub-pages (`lib/web_mod/collaborator/`):**
    - `sidebar.dart` & `overview_page.dart`: Shell navigation layout and summaries.
    - `activities_page.dart` / `create_activity_page.dart`: Event schedule controls.
    - `attendance_page.dart` / `widgets/attendance_table.dart`: Tracks student attendance.
- **Services:**
    - [mod_log_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/services/mod_log_service.dart): Logs administrator actions to `moderation_logs` collection.
    - [user_moderation_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/services/user_moderation_service.dart): Suspends, bans, restores user accounts, and posts status change alerts.
    - [post_moderation_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/web_mod/services/post_moderation_service.dart): Controls to approve/hide content and delete comments recursively.

---

## ⚡ Firebase Cloud Functions Backend (`functions/src/index.ts`)
The serverless backend logic written in TypeScript governs moderation, chatbot security/caching, and account registration.
- **Content Moderation (`moderateForumPost`, `moderateReview`, `moderateMaterial`):**
  Triggered on Firestore document creation. Runs server-side toxic-word and sensitive-word checks using normalized Vietnamese diacritic removal. Automatically updates status to `hidden` (for toxicity) or `pending` (for sensitivity review) to protect the forum.
- **Rate-Limited Chat Proxy (`chatWithUEm`):**
  Secures and restricts Gemini chatbot requests to **10 questions per user per day**. Hashes prompt keys and stores responses in a 30-day cache database (`chat_cache`) to optimize costs. Calls the external Python FastAPI backend.
- **Registration OTP System (`sendRegistrationOTP`, `verifyOTPAndCreateUser`):**
  Validates university email domain ownership. Sends 6-digit verification codes via an EmailJS proxy integration. On verification, registers the authentication user, updates profile details, and returns a secure token with transaction safety rollback rules.
- **Account Deletion Sync (`cleanupDeletedAccounts`):**
  A scheduled cron job running daily (`0 0 * * *`) that query-deletes Firebase Auth records and matching Firestore profile documents for users whose scheduled deletion grace period (3 days) has expired.
- **Semantic Search (`semanticSearch`):**
  A Callable cloud function proxying semantic text searches to the search server.

---

## 🔄 App Architecture & Patterns

### State Management
The project uses the `provider` state pattern:
- **Global Settings:** Managed by `AppProvider` in [app_provider.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/app_provider.dart). This holds values for:
  - Theme mode (Dark, Light, System) - persisted locally.
  - Locale (Default: `vi` - Vietnamese, supports English options).
  - Notifications toggle status.
- **Local / Feature State:** Features use dedicated controllers and repositories syncing locally or with Firestore.

### Routing Rules (Configured in [main.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/main.dart))
The app utilizes a dual-routing pattern:
- **Mobile app:** Normal MaterialApp routing (`initialRoute: '/'`) using a predefined routes map.
  - Starts with the [splash_screen.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/splash_screen.dart) (`/`), which routes to `/welcome` or `/home` based on logged-in state.
- **Web admin:** Uses GoRouter (`MaterialApp.router`).
  - Automatically filters authenticated emails. Admins (`allowedAdmins`) are redirected to `/mod`; collaborators (`allowedCollaborators`) are redirected to `/collaborator`. Others are blocked.

### Caching and Synchronization Strategy
To support robust offline capability and prevent redundant API calls:
1. **Local Reads First:** The workspace reads schedules and deadlines from [local_storage_helper.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/local_storage_helper.dart).
2. **Background Sync:** Local changes (e.g. adding a deadline) are immediately pushed to Cloud Firestore when network is available via [myspace_firebase_service.dart](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/myspace_firebase_service.dart).
3. **Moodle Scraping/Sync:** Synchronizes university academic deadlines automatically with local tasks when the Moodle credentials configuration is enabled.

---

## 🎨 Asset Guidelines

All local resources are cataloged in [pubspec.yaml](file:///c:/Users/TUF/StudioProjects/My-Uni/pubspec.yaml):
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
   - Any modifications to student schedules or deadlines MUST call the appropriate method in [LocalStorageHelper](file:///c:/Users/TUF/StudioProjects/My-Uni/lib/features/myspace/local_storage_helper.dart) to persist changes offline, and then update remote Firestore if connected.

4. **Localization and Date Formatting:**
   - Always use the `intl` package for formatting currency, numbers, and dates.
   - Use the `timeago` package to format user-friendly post/comment timestamps relative to the current time.
