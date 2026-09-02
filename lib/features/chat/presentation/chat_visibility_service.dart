class ChatVisibilityService {
  ChatVisibilityService._();

  static int? _currentCoupleId;

  static int? get currentCoupleId => _currentCoupleId;

  static bool isViewing(
    int coupleId,
  ) {
    return _currentCoupleId == coupleId;
  }

  static void enter(
    int coupleId,
  ) {
    _currentCoupleId = coupleId;

    print(
      '[CHAT VISIBILITY] '
      'ENTER coupleId=$coupleId',
    );
  }

  static void leave(
    int coupleId,
  ) {
    /*
     * 다른 ChatPage가 이미 열려 있는 경우
     * 잘못 null 처리하지 않기 위한 방어.
     */
    if (_currentCoupleId == coupleId) {
      _currentCoupleId = null;
    }

    print(
      '[CHAT VISIBILITY] '
      'LEAVE coupleId=$coupleId '
      'current=$_currentCoupleId',
    );
  }
}
