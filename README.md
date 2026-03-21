# Alumni Nexus Portal

A full-featured Flutter mobile app for St. Cecilia's alumni community — connecting past, present, and future graduates through events, messaging, networking, and more.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Backend | Firebase (Firestore, Auth, Storage) |
| Image Hosting | Cloudinary (profile & cover photos) |
| State | setState + StreamBuilder |
| Fonts | Google Fonts (Cormorant Garamond + Inter) |

### Key Packages
```yaml
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
firebase_storage: ^12.3.3
image_picker: ^1.1.2
cached_network_image: ^3.4.0
http: ^1.2.0
intl: ^0.19.0
fl_chart: ^0.68.0
url_launcher: ^6.2.5
```

---

## Features

### Authentication
- Email/password login and registration
- Role-based access: `alumni`, `admin`, `registrar`, `staff`, `moderator`
- Password reset via email
- Account deletion

### Dashboard
- Personalized welcome with real user data (batch, course, location)
- Live stats: total members, upcoming events, active courses
- Quick action circles with live notification badges
- Friend request banner with accept/decline
- Curated opportunities feed
- Upcoming events calendar
- Alumni near you (real Firestore data)

### Profile
- View and edit profile (name, headline, about, location, phone)
- Profile picture and cover photo upload via **Cloudinary**
- Experience and education sections
- Public profile visible to other alumni

### Friends & Network
- Send, accept, decline, and cancel friend requests
- **Alumni-to-alumni only** connections
- Follow/unfollow (alumni + admin can follow)
- Connections tab, Requests tab (Received/Sent), Following tab
- Search alumni by name

### Messaging
- Real-time chat between any two users
- Unread message counts
- Chat creation on first message

### Events
- Event list with Upcoming / Past / All filters
- Event detail with hero image, location, date, likes, comments
- Create events (admin/staff/moderator/registrar)
- Edit and delete events
- Virtual event and Important flags
- RSVP placeholder
- Like and comment on events

### Announcements
- Post, edit, delete announcements (staff/admin)
- Mark as Important with highlighted badge
- Filter: All / Important
- Full detail view as bottom sheet

### Notifications
- Real-time bell icon with unread count
- Friend request notifications (with inline Accept/Decline)
- Friend accepted notifications
- Event and announcement broadcast notifications
- Mark individual or all as read

### Settings
- Edit profile navigation
- Change email (Firebase verification)
- Change password (reset email)
- Notification toggles (push, email, messages, events)
- Copy User ID for support
- Help & FAQ bottom sheet
- Contact support (email deep link)
- Privacy Policy
- About dialog
- Log out with confirmation
- Delete account with double confirmation

### Admin Panel
- Job Board Management
- User Verification & Moderation
- Event Planning
- Chapter Management
- Career Milestones
- Announcement Management
- Growth Metrics

---

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   └── constants/
│       └── app_colors.dart
└── features/
    ├── auth/
    │   └── presentation/screens/
    │       ├── login_screen.dart
    │       ├── register_screen.dart
    │       └── settings_screen.dart
    ├── dashboard/
    │   └── presentation/screens/
    │       ├── dashboard_screen.dart
    │       └── admin_dashboard_web.dart
    ├── profile/
    │   └── presentation/screens/
    │       ├── profile_screen.dart
    │       └── edit_profile_screen.dart
    ├── communication/
    │   ├── messages_screen.dart
    │   ├── chat_screen.dart
    │   └── alumni_search_screen.dart      ← also AlumniPublicProfileScreen
    ├── network/
    │   └── friends_screen.dart
    ├── event/
    │   └── presentation/screens/
    │       ├── event_list_screen.dart
    │       ├── event_screen.dart
    │       ├── add_event_screen.dart
    │       ├── edit_event_screen.dart
    │       ├── announcements_screen.dart
    │       ├── announcement_detail_screen.dart
    │       ├── add_announcement_screen.dart
    │       └── discussions_screen.dart
    ├── notification/
    │   ├── notification_service.dart
    │   └── notification_screen.dart
    ├── gallery/
    │   └── presentation/screens/
    │       └── gallery_screen.dart
    └── admin/
        └── presentation/screens/
            ├── growth_metrics_screen.dart
            ├── user_verification_moderation_screen.dart
            ├── event_planning_screen.dart
            ├── job_board_management_screen.dart
            ├── chapter_management_screen.dart
            ├── reunion_planning_screen.dart
            ├── career_milestones_screen.dart
            └── announcement_management_screen.dart
```

---

## Firestore Data Model

```
users/{uid}
  ├── name, email, role, batch, course, location
  ├── profilePictureUrl, coverPhotoUrl
  ├── headline, about, phone
  ├── experience[], education[]
  ├── followersCount, followingCount, connectionsCount
  ├── followers/{followerUid}
  ├── following/{followingUid}
  └── connections/{connectedUid}

friend_requests/{fromUid_toUid}
  └── fromUid, toUid, status, createdAt

chats/{chatId}
  ├── memberIds[], lastMessage, lastMessageAt
  ├── unreadCount: { uid1: 0, uid2: 2 }
  └── messages/{messageId}
        └── text, senderId, createdAt

notifications/{id}
  └── toUid, fromUid, type, title, body, refId, read, createdAt

events/{eventId}
  ├── title, description, location, type
  ├── startDate, endDate, heroImageUrl
  ├── isVirtual, isImportant, maxAttendees
  ├── likes/{uid}
  └── comments/{commentId}

announcements/{id}
  └── title, content, important, publishedAt, createdBy

opportunities/{id}
  └── title, type, company, location, createdAt
```

---

## Firestore Security Rules Summary

- All authenticated users can read most collections
- `connections`, `friend_requests` — open write for authenticated users
- `notifications` — users can only read/update/delete their own
- `events`, `announcements`, `courses` — write restricted to staff roles
- `chats/messages` — only chat members can read/write
- Catch-all: `allow read, write: if request.auth != null`

---

## Required Firestore Indexes

| Collection | Fields |
|-----------|--------|
| notifications | `toUid` ASC, `createdAt` DESC |
| chats | `memberIds` ARRAY, `lastMessageAt` DESC |
| friend_requests | `toUid` ASC, `status` ASC |
| friend_requests | `fromUid` ASC, `status` ASC |

---

## Cloudinary Setup

Profile and cover photos are uploaded to Cloudinary (free tier).

1. Create account at [cloudinary.com](https://cloudinary.com)
2. Create an **unsigned upload preset** named `alumni_uploads`
3. Update in `edit_profile_screen.dart`:
```dart
static const _cloudName = 'your_cloud_name';
static const _uploadPreset = 'alumni_uploads';
```

---

## Firebase Setup

1. Create a Firebase project
2. Enable **Authentication** (Email/Password)
3. Enable **Firestore Database**
4. Enable **Storage**
5. Run `flutterfire configure` to generate `firebase_options.dart`
6. Deploy Firestore rules from the Rules section above

---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/yourname/alumni-nexus-portal.git
cd alumni-nexus-portal

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## Role Permissions Summary

| Feature | Alumni | Admin | Registrar | Staff | Moderator |
|---------|--------|-------|-----------|-------|-----------|
| Send friend requests | ✅ alumni only | ❌ | ❌ | ❌ | ❌ |
| Follow users | ✅ | ❌ | ❌ | ❌ | ❌ |
| Create events | ❌ | ✅ | ✅ | ✅ | ✅ |
| Post announcements | ❌ | ✅ | ✅ | ✅ | ✅ |
| Delete events/comments | ❌ | ✅ | ✅ | ✅ | ✅ |
| Access admin panel | ❌ | ✅ | ✅ | ✅ | ✅ |
| Message anyone | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Design System

| Token | Value |
|-------|-------|
| Brand Red | `#991B1B` |
| Dark Text | `#111827` |
| Muted Text | `#6B7280` |
| Border Subtle | `#E5E7EB` |
| Card White | `#FFFFFF` |
| Soft White | `#F9FAFB` |
| Display Font | Cormorant Garamond |
| Body Font | Inter |

---

## License

© 2026 St. Cecilia's Alumni. All rights reserved.
