# AI Agent Documentation

The AI Agent feature enables users to have voice conversations with an AI assistant through real-time audio communication using Agora RTC integration with AI-enhanced audio quality.

## Table of Contents

- [Architecture Overview](./ai_agent_architecture.md)
- [User Flows](./ai_agent_user_flows.md)
- [Code Organization](./ai_agent_code_organization.md)
- [Backend Integration](./ai_agent_backend_integration.md)
- [Time Management System](./ai_agent_time_management.md)
- [Error Handling](./ai_agent_error_handling.md)
- [AI Audio Configuration](./ai_audio_configuration.md) ⭐ **NEW**

## Key Features

### 🎙️ Real-Time Voice Communication
- Agora RTC integration with AI audio enhancements
- AI-powered noise suppression and echo cancellation
- Microphone and speaker controls with intelligent audio routing
- Real-time audio state management
- Proximity sensor integration for earpiece mode

### 🤖 AI Audio Enhancements ⭐ **NEW**
- **AI Denoising**: Intelligent background noise removal
- **AI Echo Cancellation**: Advanced echo elimination for clearer conversations
- **AI Audio Scenario**: Optimized audio parameters for conversational AI
- **Dynamic Reconfiguration**: Automatic audio optimization on route changes
- **Fallback Support**: Graceful degradation when AI features are unavailable

### ⏱️ Time-Based Usage System
- Users receive 1 hour of AI agent time by default
- Real-time time tracking during conversations
- Automatic session termination when time expires
- Firebase-based time persistence and synchronization

### 🤖 AI Agent Integration
- Backend AI agent service connection
- Channel-based audio routing
- Automatic agent invocation and management
- State synchronization between frontend and backend

### 📱 Cross-Platform Support
- iOS (Cupertino) and Android (Material) UI
- Platform-specific audio controls
- Proximity sensor integration for iOS
- Haptic feedback and native animations

### 🔄 State Management
- Comprehensive state tracking (idle, starting, running, stopping, error)
- Real-time UI updates with animation
- Memory-efficient resource management
- Automatic cleanup and disposal

## Architecture Highlights

The AI Agent system follows a layered architecture:

1. **UI Layer**: Platform-specific screens with real-time state updates
2. **Provider Layer**: State management with `AiAgentProvider`
3. **Repository Layer**: Business logic orchestration in `AiAgentRepository`
4. **Service Layer**: Core services for API, Agora, and time management
5. **Model Layer**: Data structures for AI agent responses and sessions

## Quick Start

### Prerequisites
- Agora RTC SDK integration
- Firebase authentication
- Backend AI agent service
- User time management system

### Basic Usage
```dart
// Initialize provider
final provider = context.read<AiAgentProvider>();
await provider.initialize(userUid);

// Start AI agent session
final success = await provider.startAgent();

// Stop AI agent session
await provider.stopAgent();
```

## Documentation Structure

Each documentation file covers a specific aspect of the AI Agent system:

- **Architecture**: System design, components, and data flow
- **User Flows**: Step-by-step user interaction patterns
- **Code Organization**: File structure and component relationships
- **Backend Integration**: API endpoints and communication patterns
- **Time Management**: Usage tracking and Firebase synchronization
- **Error Handling**: Exception types and recovery mechanisms

## Related Systems

The AI Agent integrates with several other systems:

- **Authentication**: User identity and session management
- **Agora**: Real-time communication infrastructure
- **Firebase**: User data persistence and real-time updates
- **User Service**: Profile and time management
- **Sensor Service**: Proximity detection for earpiece mode
