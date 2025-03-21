# Contributing to DuckBuck

First off, thank you for considering contributing to DuckBuck! It's people like you that make DuckBuck such a great tool.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Issues](#issues)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Project Structure](#project-structure)
- [Communication](#communication)

## Code of Conduct

This project and everyone participating in it is governed by the DuckBuck Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Getting Started

### Issues

- **Bug Reports**: Please use the bug report template and include as many details as possible.
- **Feature Requests**: Please use the feature request template.
- **Questions**: Feel free to ask questions in the discussions section.

Before submitting a new issue, please check if a similar issue already exists.

### Pull Requests

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Development Setup

1. Ensure you have Flutter SDK v3.19+ installed
2. Set up Firebase & Agora accounts
3. Clone your fork of the repository
4. Run `flutter pub get` to install dependencies
5. Configure your local environment with necessary API keys
6. Run tests to ensure everything is working: `flutter test`

## Coding Standards

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Write comments for complex logic
- Keep functions small and focused
- Use the MVVM architectural pattern for new features

### File Naming Conventions

- Flutter components: `snake_case.dart`
- Class files: `snake_case.dart` (with PascalCase class names inside)
- Test files: `{file_name}_test.dart`

## Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Updates to build process, tools, etc.

Example: `feat(audio): add background noise cancellation`

## Testing

- Write unit tests for utilities and services
- Write widget tests for UI components
- Add integration tests for critical user flows
- Ensure all tests pass before submitting a PR

## Documentation

- Update documentation when changing functionality
- Document public APIs and complex code
- Keep README and other documentation up to date

## Project Structure

```
├── android/                  # Android native code
│   └── app/src/main/kotlin/  # Kotlin code for native integrations
├── ios/                      # iOS native code
├── lib/
│   ├── main.dart             # App entry point
│   ├── models/               # Data models
│   ├── providers/            # State management
│   ├── screens/              # UI screens
│   ├── services/             # Business logic and API integrations
│   ├── utils/                # Utilities and helpers
│   └── widgets/              # Reusable UI components
├── test/                     # Tests
└── pubspec.yaml              # Dependencies and app metadata
```

## Communication

- GitHub Issues: Bug reports, feature requests
- GitHub Discussions: General questions and discussions
- Pull Requests: Code reviews and feature implementations

Thank you for contributing to DuckBuck!

---

*This document was last updated on March 21, 2025*
