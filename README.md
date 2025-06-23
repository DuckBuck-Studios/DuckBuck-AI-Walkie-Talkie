# DuckBuck

<div align="center">
  <img src="assets/logo.png" alt="DuckBuck Logo" width="250" />
</div>

DuckBuck is a feature-rich mobile application built with Flutter that provides a secure and intuitive platform for social connections, real-time voice communication, and comprehensive relationship management.

## 📚 Comprehensive Documentation

Explore the complete technical documentation for DuckBuck's advanced features and architecture:

### 🔐 **Authentication System Documentation**
**Multi-provider authentication with enhanced UserModel and premium features**

📁 **[`docs/auth/`](docs/auth/)**
- **[Authentication Architecture](docs/auth/auth_architecture.md)** - Complete technical architecture with enhanced UserModel structure
- **[Authentication User Flows](docs/auth/auth_user_flows.md)** - Detailed sequence diagrams for multi-provider auth flows
- **[Authentication Code Organization](docs/auth/auth_code_organization.md)** - Code structure and implementation details

**Key Features:**
- Multi-Provider Support (Google, Apple, Phone)
- Premium Features with Agent Time Management  
- Soft Delete Support with 90-day Recovery
- Smart Field Management based on Auth Method
- FCM Token Management and Device Integration

### 👥 **Friends System Documentation**
**Unified relationship management with smart caching and real-time updates**

📁 **[`docs/friends/`](docs/friends/)**
- **[Friends Architecture](docs/friends/friends_architecture.md)** - Enhanced v2.0 unified SharedFriendsProvider architecture
- **[Friends User Flows](docs/friends/friends_user_flows.md)** - Comprehensive relationship management flows
- **[Friends Code Organization](docs/friends/friends_code_organization.md)** - Repository-level caching and state management
- **[Friends Overview](docs/friends/README.md)** - Quick start guide and component overview

**Key Features:**
- Unified SharedFriendsProvider (Single Source of Truth)
- Repository-Level Smart Caching (5-minute validity)
- Real-time Firebase Streams with Auto-reconnection
- Comprehensive Relationship States (pending, accepted, blocked, declined)
- Enhanced RelationshipModel and UserModel Integration
- Memory Optimization and Performance Features

### 🎙️ **Walkie-Talkie System Documentation**
**Production-ready real-time voice communication with background service architecture**

📁 **[`docs/walkie-talkie/`](docs/walkie-talkie/)**
- **[Walkie-Talkie Architecture](docs/walkie-talkie/walkie_talkie_architecture.md)** - Complete Kotlin service layer and Agora RTC integration
- **[Walkie-Talkie User Flows](docs/walkie-talkie/walkie_talkie_user_flows.md)** - Comprehensive call lifecycle and FCM processing
- **[Call State Optimization Summary](docs/walkie-talkie/callstate-optimization-summary.md)** - Simplified state machine details
- **[FCM Receiver Flow](docs/walkie-talkie/fcm-receiver-flow.md)** - Firebase Cloud Messaging integration
- **[Walkie-Talkie Overview](docs/walkie-talkie/README.md)** - Feature overview and technical specifications

**Key Features:**
- Foreground Service Architecture for Background Persistence
- Simplified Call State Management (JOINING → ACTIVE → ENDING → ENDED)
- Advanced FCM Processing with Auto-Connect
- Agora RTC Integration with Professional Audio Quality
- Cross-Platform Bridge (Flutter ↔ Kotlin)
- Smart Notification System with Speaker Detection
- Audio Management with Hardware Integration

### 🤖 **AI Agent System Documentation**
**Intelligent voice conversations with time-based usage management and real-time audio**

📁 **[`docs/ai-agent/`](docs/ai-agent/)**
- **[AI Agent Architecture](docs/ai-agent/ai_agent_architecture.md)** - Complete system design with Agora RTC and backend integration
- **[AI Agent User Flows](docs/ai-agent/ai_agent_user_flows.md)** - Comprehensive conversation flows and platform-specific behaviors
- **[AI Agent Code Organization](docs/ai-agent/ai_agent_code_organization.md)** - Layered architecture and component relationships
- **[AI Agent Backend Integration](docs/ai-agent/ai_agent_backend_integration.md)** - API endpoints, authentication, and data synchronization
- **[AI Agent Time Management](docs/ai-agent/ai_agent_time_management.md)** - Real-time time tracking and Firebase synchronization
- **[AI Agent Error Handling](docs/ai-agent/ai_agent_error_handling.md)** - Comprehensive error recovery and user experience patterns
- **[AI Agent Overview](docs/ai-agent/README.md)** - Feature overview and quick start guide

**Key Features:**
- Real-Time Voice Conversations with AI Assistant
- Time-Based Usage System (1 hour default allocation)
- Agora RTC Integration with Professional Audio Quality
- Firebase Real-Time Time Synchronization
- Two-Phase Session Start (Immediate UI Update + Background Connection)
- Proximity Sensor Integration for Earpiece Mode
- Cross-Platform UI (iOS Cupertino + Android Material)
- Comprehensive Error Handling with Graceful Degradation
- Circuit Breaker Pattern for Backend Resilience
- Memory-Efficient Resource Management

## 🏗️ **Architecture Overview**

DuckBuck implements a comprehensive **layered architecture** across all features:

```
🎨 UI Layer (Flutter)
    ├── Platform-specific interfaces (iOS/Android)
    ├── Real-time state management with Providers
    ├── Cross-platform bridge communication
    └── Responsive and accessible design

🔄 Provider Layer
    ├── SharedFriendsProvider (Unified friends management)
    ├── AuthStateProvider (Multi-provider authentication)
    ├── Settings and user preference management
    └── Real-time stream coordination

📂 Repository Layer
    ├── RelationshipRepository (Smart caching & analytics)
    ├── UserRepository (Profile and auth coordination)
    ├── Repository-level caching strategies
    └── Business logic coordination

⚙️ Service Layer
    ├── Firebase integrations (Auth, Firestore, FCM)
    ├── Agora RTC service (Voice communication)
    ├── Local database service (Offline support)
    └── Analytics and monitoring services

🌐 External Services
    ├── Firebase ecosystem (Auth, Firestore, Storage, FCM)
    ├── Agora RTC platform (Real-time communication)
    ├── Android system services (Audio, notifications)
    └── Cross-platform native integrations
```

## 📱 **Core Features**

### **Authentication & User Management**
- **Multi-Provider Auth**: Google, Apple, and Phone authentication
- **Premium Features**: Agent time management with time-based access
- **Account Management**: Soft delete with recovery, profile management
- **Security**: Enhanced token management and session handling

### **Friends & Relationships** 
- **Unified Management**: Single provider for all relationship operations
- **Real-time Updates**: Live synchronization across devices
- **Smart Caching**: Offline support with background refresh
- **Privacy Controls**: Comprehensive blocking and privacy management

### **Walkie-Talkie Communication**
- **Instant Voice**: Auto-connect calls via FCM notifications
- **Background Operation**: Persistent service architecture
- **Professional Audio**: Agora RTC with optimized quality
- **Smart Notifications**: Speaker detection with self-filtering

### **AI Agent Conversations**
- **Voice AI Assistant**: Real-time conversations with intelligent responses
- **Time-Based Usage**: 1-hour default allocation with real-time tracking
- **Professional Audio**: Agora RTC integration with proximity sensor support
- **Seamless Experience**: Two-phase connection with immediate UI feedback
- **Cross-Platform**: Native iOS and Android interfaces with platform-specific optimizations

## 🎯 **Getting Started**

1. **Explore the Documentation**: Start with the feature you're interested in
2. **Architecture Deep Dive**: Review the enhanced v2.0 architecture documents
3. **Implementation Details**: Check the code organization guides
4. **User Flows**: Understand the complete user journey sequences

## 🔧 **Technical Highlights**

- **Flutter Framework**: Cross-platform mobile development
- **Firebase Integration**: Authentication, database, and messaging
- **Agora RTC**: Professional real-time communication
- **Kotlin Service Layer**: Background processing and native integration
- **Smart Caching**: Repository-level optimization strategies
- **Real-time Streams**: Live data synchronization
- **Memory Optimization**: Efficient resource management
- **Performance**: Optimized for production deployment

---

For detailed setup instructions, development workflows, and deployment guides, please refer to the comprehensive documentation in the respective feature folders.
