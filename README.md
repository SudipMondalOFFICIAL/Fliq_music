# Filq - Flutter Telegram-like Messaging App

A complete Flutter application for Android/iOS/Web that integrates with the Filq backend API. Built with Provider for state management, WebSocket for real-time messaging, and SQLite for offline caching.

## 📋 Project Structure

```
lib/
├── main.dart                      # App entry point + Login/Home screens
├── constants/
│   └── api_config.dart           # API endpoints and configuration
├── models/                        # Data models with serialization
│   ├── user.dart
│   ├── chat.dart
│   ├── message.dart
│   ├── bot.dart
│   ├── story.dart
│   ├── call.dart
│   └── ... (other models)
├── services/                      # Core services
│   ├── api_service.dart          # HTTP client (25+ endpoints)
│   ├── websocket_service.dart    # Real-time messaging
│   ├── auth_service.dart         # JWT token management
│   └── storage_service.dart      # SQLite local cache
├── providers/                     # State management
│   ├── chat_provider.dart        # Chat list and operations
│   ├── message_provider.dart     # Messages and reactions
│   └── ... (other providers)
└── screens/                       # User interface
    ├── chat_list_screen.dart     # Main chat list with search
    └── ... (other screens)
```

## 🚀 Getting Started

### 1. Prerequisites
- Flutter 3.0+ with Dart
- Android Studio or Xcode (for native development)
- A running Filq backend server

### 2. Installation

```bash
# Navigate to project directory
cd flutter_app

# Get dependencies
flutter pub get

# Generate build files (if needed)
flutter pub run build_runner build

# Run app on connected device/emulator
flutter run
```

### 3. Configuration

**Update Backend URL** in `lib/constants/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = "http://YOUR_SERVER_IP:8000";
  // Update to your actual backend server address
}
```

For production, update this to your Render.com deployment URL.

## 🔧 Core Services

### ApiService
Handles all HTTP communication with the backend. Automatically manages JWT Bearer token authentication.

```dart
// Example usage
final apiService = context.read<ApiService>();
final user = await apiService.login(email: 'user@example.com', password: 'pass');
apiService.setToken(user.token);
```

**Coverage**: Auth, chats, messages, bots, stories, calls, uploads

### WebSocketService
Manages real-time bidirectional WebSocket connection for live messaging updates.

```dart
final ws = context.read<WebSocketService>();
ws.connect(
  url: wsUrl,
  onMessage: (data) => handleWebSocketEvent(data),
  onError: (error) => showError(error),
  onDone: () => reconnect(),
);

// Send messages in real-time
ws.sendMessage(chatId: 'chat123', text: 'Hello!');
ws.sendTyping('chat123');  // Show typing indicator
```

### AuthService
Manages JWT token lifecycle and user session persistence using shared_preferences.

```dart
final auth = context.read<AuthService>();

// Login/logout
await auth.login(email: 'user@example.com', password: 'pass');
await auth.logout();

// Token management
bool loggedIn = auth.isLoggedIn();
String? token = auth.getToken();
```

### StorageService
SQLite local database for caching chats and messages with offline support.

```dart
final storage = context.read<StorageService>();

// Save and retrieve data
await storage.saveChat(chat);
final chats = await storage.getChats();

await storage.saveMessage(message);
final messages = await storage.getMessages(chatId);

// Clear old data
await storage.clearOldMessages(chatId, daysOld: 30);
```

## 📱 State Management (Provider)

### ChatProvider
Manages chat list, current chat selection, and group operations.

```dart
final chatProv = context.read<ChatProvider>();

// Load and search
await chatProv.loadChats();
final results = chatProv.searchChats('query');

// Operations
await chatProv.createGroup(name: 'Friends', memberIds: [...]);
await chatProv.selectChat(chatId);
await chatProv.leaveChat(chatId);
```

### MessageProvider
Manages messages for current chat, handles real-time updates.

```dart
final msgProv = context.read<MessageProvider>();

// Load and send
await msgProv.loadMessages(chatId);
final sent = await msgProv.sendMessage(
  chatId: chatId,
  text: 'Hello!',
  replyToId: replyId,
);

// Update and delete
await msgProv.editMessage(messageId: msgId, newText: 'Edited');
await msgProv.deleteMessage(messageId: msgId);

// Reactions
await msgProv.reactMessage(messageId: msgId, emoji: '👍');

// WebSocket integration
msgProv.addMessageFromWebSocket(message);
msgProv.updateMessageFromWebSocket(msgId, {'is_pinned': true});
```

## 📡 Features

### ✅ Completed
- [x] User authentication (register/login)
- [x] Chat list with search
- [x] Real-time messaging via WebSocket
- [x] Offline message caching
- [x] Group chat support
- [x] Message reactions
- [x] Message editing/deletion
- [x] User token persistence

### 🔄 In Progress
- [ ] Chat detail screen with full UI
- [ ] Message input with media picker
- [ ] Firebase push notifications
- [ ] Stories (24h disappearing media)
- [ ] Voice/video calls via LiveKit
- [ ] Bot management
- [ ] User profiles and settings

### 📋 Planned
- [ ] Message search across chats
- [ ] Chat encryption (E2E)
- [ ] Channel support
- [ ] Payment integration
- [ ] Advanced bot commands
- [ ] Analytics integration

## 🔐 Authentication Flow

```
1. User enters email/password
2. Login screen calls auth.login()
3. Backend returns JWT token
4. Token saved to shared_preferences
5. ApiService uses token for Bearer auth
6. On app restart, saved token auto-loads
7. WebSocket connects using token in URL query param
8. If token expires, refresh flow handles re-auth
```

## 📞 WebSocket Events

Events received from backend:
```
new_message       → New message in chat
typing            → User is typing
stop_typing       → User stopped typing
message_edited    → Message was edited
message_deleted   → Message was deleted
reaction_updated  → Reaction added/removed
member_joined     → New member joined group
member_left       → Member left group
call_initiated    → Incoming call
call_ended        → Call finished
```

## 🛠️ Development

### Running with Hot Reload
```bash
flutter run
# Press 'r' to reload, 'R' to restart
```

### Building for Release
```bash
# Android
flutter build apk
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web
```

### Code Generation (if using build_runner)
```bash
flutter pub run build_runner build
```

## 📦 Dependencies

- **http** - HTTP client for REST API
- **web_socket_channel** - WebSocket client
- **provider** - State management
- **firebase_core** - Firebase integration
- **firebase_messaging** - Push notifications
- **sqflite** - Local SQLite database
- **shared_preferences** - Key-value storage
- **image_picker** - Camera/gallery access
- **cached_network_image** - Image caching
- **livekit_client** - Voice/video calls
- **material_design_icons_flutter** - Icons

## ⚙️ Configuration

### Environment Variables (if using)
Create `.env` file in project root:
```
BACKEND_URL=http://your-server:8000
WS_URL=ws://your-server:8000
FIREBASE_PROJECT_ID=your-project-id
```

Then update `api_config.dart` to read these.

### Firebase Setup
1. Create Firebase project in Console
2. Add Android app (google-services.json)
3. Add iOS app (GoogleService-Info.plist)
4. Enable Cloud Messaging in Firebase Console

## 🐛 Debugging

### Enable Debug Logging
```dart
// In main.dart
void main() {
  // Enable HTTP logging
  HttpOverrides.global = MyHttpOverrides();
  
  // Enable WebSocket debugging
  // Set logging level in WebSocketService
  
  runApp(...);
}
```

### Common Issues

**Backend URL not connecting:**
- Check backend is running: `curl http://your-ip:8000/docs`
- Verify URL in api_config.dart
- Check firewall/port access

**WebSocket connection fails:**
- Ensure your backend supports WebSocket
- Check token is valid (log in first)
- Verify ws:// protocol is used (not http://)

**Offline mode not working:**
- Check StorageService is initialized
- Verify sqflite database permissions
- Check device allows local database storage

## 📚 API Documentation

Backend API docs available at:
```
http://your-backend:8000/docs  (Swagger UI)
http://your-backend:8000/redoc (ReDoc)
```

## 🤝 Contributing

When adding new features:
1. Create model in `lib/models/`
2. Add API methods to `ApiService`
3. Create or update Provider for state
4. Build Screen for UI
5. Integrate WebSocket events if needed
6. Update this README

## 📄 License

This project is part of the Filq messaging platform.

## 🆘 Support

For issues:
1. Check the Backend API docs at `/docs`
2. Review WebSocket event format
3. Check console logs in Flutter DevTools
4. Verify network connectivity and backend availability
