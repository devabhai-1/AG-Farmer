/// Cross-tab actions (course hub prompts → main chat, etc.).
class ScreenActions {
  ScreenActions._();

  /// Optional: send a prompt into the main Chat tab.
  void Function(String text, {String? cropId})? sendChat;
}

final screenActions = ScreenActions._();
