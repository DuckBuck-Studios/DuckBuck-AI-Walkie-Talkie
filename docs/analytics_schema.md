# DuckBuck Analytics Schema Documentation

This document describes the Firebase Analytics event schema used throughout the DuckBuck app, with a focus on the authentication flow.

## Analytics Implementation Overview

DuckBuck uses Firebase Analytics to track user interactions, authentication events, screen navigation, and other important app usage metrics. This tracking is implemented using our centralized `FirebaseAnalyticsService` which provides custom methods for common analytics events.

### Core Analytics Services

- **Firebase Analytics Service**: Centralized service for tracking events and user properties
- **Logger Service**: Integrated with analytics for consistent logging and monitoring

## Authentication Flow Events

### Screen Views

| Screen Name | Class | Description |
|-------------|-------|-------------|
| `welcome_screen` | `WelcomeScreen` | Initial welcome/splash screen |
| `onboarding_container` | `OnboardingContainer` | Container for onboarding flow |
| `onboarding_page_1` | `OnboardingContainer` | First onboarding page |
| `onboarding_page_2` | `OnboardingContainer` | Second onboarding page |
| `onboarding_page_3` | `OnboardingContainer` | Third onboarding page |
| `onboarding_signup` | `OnboardingContainer` | Signup/login choice screen |
| `profile_completion_screen` | `ProfileCompletionScreen` | Profile setup screen |
| `profile_photo_selection` | `ProfileCompletionScreen` | Photo selection step |
| `profile_name_entry` | `ProfileCompletionScreen` | Name entry step |

### Authentication Events

#### Sign-In/Sign-Up Events

| Event Name | Parameters | Description |
|------------|------------|-------------|
| `auth_attempt` | `auth_method`, `timestamp` | User starts authentication |
| `auth_success` | `auth_method`, `user_id`, `is_new_user`, `timestamp` | Auth succeeded |
| `auth_failure` | `auth_method`, `reason`, `error_code`, `timestamp` | Auth failed |
| `new_user_signup` | `auth_method`, `user_id`, `has_email` | New user registration |
| `returning_user_login` | `auth_method`, `user_id` | Returning user login |

#### Phone Authentication Events

| Event Name | Parameters | Description |
|------------|------------|-------------|
| `phone_verification` | `country_code`, `phone_suffix`, `timestamp` | Phone verification initiated |
| `phone_verification_code_sent` | `timestamp` | SMS code sent successfully |
| `otp_entered` | `is_successful`, `is_auto_filled`, `timestamp` | OTP verification attempt |

#### Profile Completion Events

| Event Name | Parameters | Description |
|------------|------------|-------------|
| `profile_completion_check` | `user_id`, `is_new_user`, `needs_completion`, `reason`, `has_display_name`, `has_photo`, `auth_provider` | Check if profile completion is needed |
| `navigate_to_profile_completion` | `user_id`, `is_new_user`, `timestamp` | User sent to profile completion |
| `skip_profile_completion` | `user_id`, `reason`, `timestamp` | Profile completion skipped |
| `profile_completion_next_step` | `from_step`, `to_step`, `timestamp` | Navigation between profile steps |
| `profile_completion_previous_step` | `from_step`, `to_step`, `timestamp` | Navigation back in profile flow |
| `profile_image_selection_started` | `source` (`gallery`/`camera`), `timestamp` | User starts image selection |
| `profile_image_selected` | `source`, `file_size`, `timestamp` | Profile image successfully selected |
| `profile_image_selection_canceled` | `source`, `timestamp` | User canceled image selection |
| `profile_image_selection_error` | `source`, `error`, `timestamp` | Error during image selection |
| `profile_image_fullscreen_enter` | `timestamp` | User enters fullscreen image preview |
| `profile_image_fullscreen_exit` | `timestamp` | User exits fullscreen image preview |
| `profile_completed` | `has_photo`, `display_name_length`, `user_id`, `timestamp` | Profile setup completed |
| `profile_completion_error` | `error`, `user_id`, `timestamp` | Error in profile completion |

#### User Onboarding Events

| Event Name | Parameters | Description |
|------------|------------|-------------|
| `start_onboarding` | `source`, `timestamp` | User starts onboarding flow |
| `onboarding_page_view` | `page_number`, `page_name`, `timestamp` | User views specific onboarding page |
| `onboarding_complete` | `source`, `user_id`, `timestamp` | User completes onboarding |

### User Profile Events

| Event Name | Parameters | Description |
|------------|------------|-------------|
| `profile_update_start` | `user_id`, `fields_updated` | User starts updating profile |
| `profile_update_success` | `user_id`, `fields_updated` | Profile update successful |
| `profile_update_failure` | `reason`, `error_code` | Profile update failed |
| `user_sign_out` | `user_id`, `timestamp` | User signs out |

## User Properties

| Property Name | Description | Possible Values |
|--------------|-------------|-----------------|
| `onboarding_status` | Status of user onboarding | `profile_completion`, `completed` |
| `profile_completed` | Whether profile is fully set up | `true` |

## Best Practices

When adding new analytics events to the app, follow these guidelines:

1. **Use consistent naming**: Follow the established naming pattern
2. **Include timestamps**: Add timestamps to all events for accurate sequencing
3. **Add user_id when available**: Include user_id in all authenticated events
4. **Error tracking**: Ensure all error events include the error reason/message
5. **Add context**: Include relevant context parameters to make events more useful
6. **Screen tracking**: Always track screen views with appropriate screen names

## Log Level Guidelines

- `verbose`: Detailed debug information
- `debug`: General debugging information
- `info`: Standard operational messages
- `warning`: Potential issues that aren't errors
- `error`: Error events that allow the app to continue
- `wtf`: Critical failures that crash functionality
