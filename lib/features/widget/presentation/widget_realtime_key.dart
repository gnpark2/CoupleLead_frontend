class WidgetRealtimeKey {
  final int coupleId;
  final int partnerId;

  const WidgetRealtimeKey({
    required this.coupleId,
    required this.partnerId,
  });

  @override
  bool operator ==(
    Object other,
  ) {
    return other
            is WidgetRealtimeKey &&
        other.coupleId ==
            coupleId &&
        other.partnerId ==
            partnerId;
  }

  @override
  int get hashCode =>
      Object.hash(
        coupleId,
        partnerId,
      );
}