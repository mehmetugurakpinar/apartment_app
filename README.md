# Apartment Management App - Flutter Frontend

A cross-platform mobile application for apartment/building management built with Flutter. Features include financial tracking, maintenance requests, community forum, social timeline, direct messaging, visitor management, reservations, and package tracking — all with real-time WebSocket notifications.

## Tech Stack

| Technology | Version | Purpose |
|---|---|---|
| **Flutter** | 3.41.4 | Cross-platform UI framework |
| **Dart** | >=3.2.0 | Programming language |
| **Riverpod** | 2.5.1 | State management |
| **GoRouter** | 14.2.0 | Declarative routing |
| **Dio** | 5.4.3 | HTTP client |
| **Hive** | 2.2.3 | Local storage (tokens, settings) |
| **fl_chart** | 0.68.0 | Charts & analytics |
| **flutter_map** | 7.0.2 | Map & location picker |
| **web_socket_channel** | 3.0.0 | Real-time WebSocket |
| **Google Fonts** | 6.2.1 | Typography (Inter) |
| **Material 3** | Built-in | Design system |

## Architecture

Feature-first architecture with shared core modules:

```
lib/
├── main.dart                              # App entry point
├── core/                                  # Shared infrastructure
│   ├── api/
│   │   ├── api_client.dart                # Dio HTTP client (80+ endpoints)
│   │   └── ws_service.dart                # WebSocket real-time service
│   ├── config/
│   │   └── app_config.dart                # API URLs, timeouts, pagination
│   ├── constants/
│   │   └── app_constants.dart             # Enums & constant values
│   ├── l10n/
│   │   └── app_localizations.dart         # English & Turkish translations
│   ├── providers/
│   │   └── providers.dart                 # Global Riverpod providers
│   ├── router/
│   │   └── app_router.dart                # All route definitions
│   ├── storage/                           # Hive boxes (auth, settings)
│   ├── theme/
│   │   └── app_theme.dart                 # Light & dark Material 3 themes
│   ├── utils/
│   │   └── time_utils.dart                # Date/time formatting
│   └── widgets/                           # Reusable UI components
│       ├── empty_state.dart               # Empty state placeholder
│       ├── map_location_picker.dart        # Map-based location selector
│       ├── skeleton_loader.dart            # Loading shimmer effects
│       └── stat_card.dart                 # Statistics display card
│
└── features/                              # Feature modules (18 modules)
    ├── auth/                              # Login, register
    ├── home/                              # Dashboard home screen
    ├── building/                          # Building management
    ├── units/                             # Unit management
    ├── dues/                              # Financial dues
    ├── maintenance/                       # Maintenance requests
    ├── forum/                             # Building forum
    ├── timeline/                          # Community social feed
    ├── social/                            # User profiles & follows
    ├── messaging/                         # Direct messaging
    ├── notifications/                     # Notifications center
    ├── visitors/                          # Visitor pass management
    ├── reservations/                      # Common area reservations
    ├── packages/                          # Package tracking
    ├── analytics/                         # Dashboard & charts
    └── profile/                           # User settings
```

## Quick Start

### Prerequisites
- Flutter SDK 3.x
- Running backend (see `apartment-backend/README.md`)

### 1. Install Dependencies

```bash
cd apartment_app
flutter pub get
```

### 2. Configure API URL

Edit `lib/core/config/app_config.dart`:

```dart
class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8080/api/v1';
  static const String wsUrl = 'ws://localhost:8080/ws';
}
```

For physical device testing, replace `localhost` with your machine's IP address.

### 3. Run

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# Web
flutter run -d chrome

# macOS
flutter run -d macos
```

## Features

### Home Screen
- Personalized greeting (time-of-day based)
- Building overview stats (units, members, requests)
- Quick action grid: Dues, Maintenance, Forum, Visitors, Reservations, Packages, Announcements, Analytics
- Recent activity feed
- Unread messages badge in app bar
- Building selector for multi-building users

### Building Management
- View building details, members, and roles
- Invite new members via email (manager)
- Leave building (with confirmation)
- Remove members (manager)

### Units
- List all apartment units with status indicators
- Create, edit, delete units (manager)
- Status tracking: occupied, vacant, maintenance
- Resident count per unit

### Financial — Dues
- Create monthly/annual dues plans (manager)
- Per-unit payment status (color-coded: green=paid, yellow=pending)
- Record payments with notes
- Payment limit enforcement (can't overpay)
- Financial reports with collection rates
- "All paid" banner when plan is fully collected

### Maintenance
- Submit maintenance requests with priority (emergency/high/normal/low)
- Approval workflow: pending → approved/rejected → in_progress → resolved
- Priority color coding throughout
- Manager approval/reject actions

### Forum
- Building-specific discussion forum
- Category filtering
- Create posts with title and body
- Comments and voting (+1/-1)
- Media/image upload support

### Timeline (Community Feed)
- Social media-style feed
- Post types: Text, Poll, Location-tagged
- Like, comment, repost interactions
- Poll creation with multiple options
- Nearby posts discovery (geolocation)
- Post detail screen with threaded comments

### Social
- User search and discovery
- User profiles with follower/following counts
- Follow/unfollow with real-time notifications
- Navigate to profile from anywhere (timeline, search, followers list)
- "Send Message" button on profiles

### Direct Messaging
- Conversation list with last message preview
- "You:" prefix for sent messages
- Unread message count badges
- Real-time message delivery via WebSocket
- Chat bubbles (left/right aligned)
- Auto-scroll on new messages

### Notifications
- Centralized notification center
- Types: like, comment, follow, repost, announcement, maintenance, payment
- Mark as read
- Real-time delivery via WebSocket
- Notification preferences per category

### Announcements (Manager)
- Create building-wide announcements
- Type selector: announcement, warning, info
- Sends to all building members
- Accessible from home screen quick actions

### Visitors
- Create visitor passes with QR codes
- Visitor details: name, phone, purpose, vehicle plate
- Check-in / check-out tracking
- Status tabs: Expected, Checked In, History
- QR code scanning for security

### Reservations
- 3-tab layout: Areas, Calendar, Reservations
- Create common areas (manager): name, capacity, hours, approval requirement
- Calendar view with horizontal date selector
- Per-area reservation display for selected date
- Color-coded status: green=approved, yellow=pending, red=rejected
- Overlap prevention

### Packages
- Log incoming packages (manager/doorman)
- Track carrier and tracking number
- Notify residents of package arrival
- Mark as picked up
- "My Packages" view for residents

### Analytics Dashboard
- Building overview statistics
- Financial pie chart (collected/pending/overdue)
- Maintenance status bar chart
- Quick statistics cards
- Example data display when no real data exists

## Navigation

### Bottom Navigation (5 tabs)
1. **Home** — Dashboard & quick actions
2. **Building** — Building management
3. **Notifications** — Notification center
4. **Forum** — Building discussions
5. **Timeline** — Community feed

### Standalone Screens
| Route | Screen | Description |
|---|---|---|
| `/profile` | ProfileScreen | Settings, theme, language |
| `/user-search` | UserSearchScreen | Find & follow users |
| `/timeline/:postId` | TimelinePostDetailScreen | Post + comments |
| `/messages` | ConversationsScreen | Message inbox |
| `/messages/:convId` | ChatScreen | Direct messages |
| `/users/:id` | UserProfileScreen | User profile + follow |
| `/users/:id/followers` | FollowersScreen | Followers list |
| `/users/:id/following` | FollowersScreen | Following list |
| `/dues` | DuesScreen | Financial management |
| `/maintenance` | MaintenanceScreen | Maintenance requests |
| `/units` | UnitsScreen | Unit management |
| `/visitors` | VisitorsScreen | Visitor passes |
| `/reservations` | ReservationsScreen | Area reservations |
| `/packages` | PackagesScreen | Package tracking |
| `/analytics` | AnalyticsScreen | Dashboard charts |

## Theming

### Color Palette
| Color | Hex | Usage |
|---|---|---|
| Primary | `#006A6A` | Main brand color (teal) |
| Primary Light | `#4D9999` | Lighter variant |
| Primary Dark | `#003F3F` | Darker variant |
| Accent | `#FFB300` | Highlights (gold) |
| Success | `#4CAF50` | Positive status |
| Warning | `#FF9800` | Caution status |
| Error | `#E53935` | Error/danger |
| Info | `#2196F3` | Information |

### Theme Modes
- **Light** — White background, teal accents
- **Dark** — Dark gray background, teal accents
- **System** — Follows device setting (default)

Change theme: Profile → Theme setting

## Localization

Supports **English** and **Turkish** with 100+ localization keys.

Change language: Profile → Language setting

Both languages are available for all screens including:
- Navigation labels
- Form labels and validation messages
- Status texts and notifications
- Date/time formatting (via `intl` package)

## State Management

### Riverpod Providers

| Provider | Type | Purpose |
|---|---|---|
| `authProvider` | StateNotifier | Auth state (login/logout/token refresh) |
| `apiClientProvider` | Provider | Dio HTTP client instance |
| `userBuildingsProvider` | FutureProvider | User's building list |
| `selectedBuildingIdProvider` | StateProvider | Currently active building |
| `localeProvider` | StateProvider | App language (persisted) |
| `themeModeProvider` | StateProvider | Theme mode (persisted) |
| `routerProvider` | Provider | GoRouter instance |
| `wsServiceProvider` | Provider | WebSocket service |

Feature-specific providers are defined within each feature module using `FutureProvider.autoDispose` for automatic cleanup.

## API Client

The `ApiClient` class in `core/api/api_client.dart` wraps Dio with:
- **Base URL configuration** from AppConfig
- **JWT token injection** via interceptor
- **Token refresh** on 401 responses
- **80+ endpoint methods** covering all features
- **Multipart upload** support for media

## WebSocket

Real-time event handling via `ws_service.dart`:
- Auto-connects with JWT token
- Auto-reconnects on disconnect
- Event types: `new_message`, `new_notification`
- Integrates with Riverpod for UI updates

## Dependencies

### Production
```yaml
flutter_riverpod: ^2.5.1      # State management
go_router: ^14.2.0             # Navigation
dio: ^5.4.3+1                  # HTTP client
hive: ^2.2.3                   # Local storage
hive_flutter: ^1.1.0           # Hive Flutter bindings
fl_chart: ^0.68.0              # Charts
shimmer: ^3.0.0                # Loading skeletons
cached_network_image: ^3.3.1   # Image caching
flutter_svg: ^2.0.10+1         # SVG support
google_fonts: ^6.2.1           # Typography
intl: ^0.20.2                  # Internationalization
json_annotation: ^4.9.0        # JSON serialization
equatable: ^2.0.5              # Value equality
uuid: ^4.4.0                   # UUID generation
url_launcher: ^6.3.0           # Open URLs
image_picker: ^1.1.1           # Camera/gallery picker
permission_handler: ^11.3.1    # Permission management
flutter_map: ^7.0.2            # Maps
latlong2: ^0.9.1               # Coordinates
web_socket_channel: ^3.0.0     # WebSocket
```

### Dev
```yaml
flutter_lints: ^4.0.0          # Linter rules
build_runner: ^2.4.9           # Code generation
json_serializable: ^6.8.0      # JSON codegen
riverpod_generator: ^2.4.0     # Riverpod codegen
hive_generator: ^2.0.1         # Hive codegen
```

## Build

```bash
# Generate code (JSON serialization, Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Build APK (Android)
flutter build apk --release

# Build IPA (iOS)
flutter build ipa --release

# Build Web
flutter build web --release
```
