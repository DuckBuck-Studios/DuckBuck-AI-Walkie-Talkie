import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/service_locator.dart';
import '../controllers/message_feature_controller.dart';
import '../../../core/repositories/message_repository.dart';
import '../../../core/repositories/friend_repository.dart';

/// Creates and provides the MessageFeatureController
class MessageProvider extends StatelessWidget {
  final Widget child;

  /// Creates a new MessageProvider
  const MessageProvider({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MessageFeatureController(
        messageRepository: serviceLocator<MessageRepository>(),
        friendRepository: serviceLocator<FriendRepository>(),
      ),
      child: child,
    );
  }
}
