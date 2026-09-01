class ChatRealtimeState {
  final bool connected;
  final bool partnerTyping;

  /*
   * 상대방 메시지가 새로 들어올 때마다 +1
   */
  final int incomingMessageVersion;

  /*
   * 가장 최근 상대방 메시지 내용
   */
  final String? latestIncomingContent;

  const ChatRealtimeState({
    this.connected = false,
    this.partnerTyping = false,
    this.incomingMessageVersion = 0,
    this.latestIncomingContent,
  });

  ChatRealtimeState copyWith({
    bool? connected,
    bool? partnerTyping,
    int? incomingMessageVersion,
    String? latestIncomingContent,
  }) {
    return ChatRealtimeState(
      connected: connected ?? this.connected,
      partnerTyping: partnerTyping ?? this.partnerTyping,
      incomingMessageVersion:
          incomingMessageVersion ?? this.incomingMessageVersion,
      latestIncomingContent:
          latestIncomingContent ?? this.latestIncomingContent,
    );
  }
}
