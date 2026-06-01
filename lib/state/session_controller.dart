import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models/app_user.dart';
import '../data/models/circle_member.dart';
import '../data/models/circle_summary.dart';
import '../data/models/subscription_status.dart';
import '../data/services/api_client.dart';
import '../data/services/auth_service.dart';
import '../data/services/auth_storage.dart';
import '../data/services/circle_service.dart';
import '../data/services/subscription_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    AuthService? authService,
    CircleService? circleService,
    SubscriptionService? subscriptionService,
    AuthStorage? authStorage,
  })  : _authService = authService ?? AuthService(),
        _circleService = circleService ?? CircleService(),
        _subscriptionService = subscriptionService ?? SubscriptionService(),
        _authStorage = authStorage ?? AuthStorage();

  final AuthService _authService;
  final CircleService _circleService;
  final SubscriptionService _subscriptionService;
  final AuthStorage _authStorage;

  AppUser? _currentUser;
  CircleSummary? _currentCircle;
  List<CircleMember> _circleMembers = const <CircleMember>[];
  SubscriptionStatus? _subscription;
  List<SubscriptionPayment> _subscriptionPayments =
      const <SubscriptionPayment>[];
  bool _isBootstrapping = false;
  bool _isAuthenticating = false;
  bool _isUpdatingCircle = false;
  bool _isLoadingCircleMembers = false;
  bool _isLoadingSubscription = false;
  bool _isUpgradingSubscription = false;
  bool _isCancellingPayment = false;
  bool _isCancellingSubscription = false;
  bool _isUploadingProfilePhoto = false;
  bool _hasLoadedCircleMembers = false;
  String? _circleMembersError;
  String? _subscriptionError;
  String? _profilePhotoError;
  int? _circleMembersCircleId;

  AppUser? get currentUser => _currentUser;
  CircleSummary? get currentCircle => _currentCircle;
  List<CircleMember> get circleMembers => List.unmodifiable(_circleMembers);
  SubscriptionStatus? get subscription => _subscription;
  List<SubscriptionPayment> get subscriptionPayments =>
      List.unmodifiable(_subscriptionPayments);
  bool get isLoggedIn => _currentUser != null;
  bool get isBootstrapping => _isBootstrapping;
  bool get isAuthenticating => _isAuthenticating;
  bool get isUpdatingCircle => _isUpdatingCircle;
  bool get isLoadingCircleMembers => _isLoadingCircleMembers;
  bool get isLoadingSubscription => _isLoadingSubscription;
  bool get isUpgradingSubscription => _isUpgradingSubscription;
  bool get isCancellingPayment => _isCancellingPayment;
  bool get isCancellingSubscription => _isCancellingSubscription;
  bool get isUploadingProfilePhoto => _isUploadingProfilePhoto;
  String? get circleMembersError => _circleMembersError;
  String? get subscriptionError => _subscriptionError;
  String? get profilePhotoError => _profilePhotoError;
  bool get isPremium => _subscription?.isPremium ?? false;
  bool get canLeaveCurrentCircle =>
      _currentCircle != null &&
      _currentUser != null &&
      !_currentCircle!.isOwnedBy(_currentUser!.id);
  bool get hasCircleMembersForCurrentCircle =>
      _currentCircle != null &&
      _circleMembersCircleId == _currentCircle!.id &&
      _hasLoadedCircleMembers;

  Future<bool> bootstrap() async {
    if (_isBootstrapping) {
      return isLoggedIn;
    }

    _isBootstrapping = true;
    notifyListeners();

    try {
      final cachedUser = await _authService.getCachedUser();
      final cachedCircle = await _authStorage.readCurrentCircle();
      if (cachedUser != null) {
        _currentUser = cachedUser;
      }
      _currentCircle = cachedCircle;
      notifyListeners();

      final hasToken = await _authService.isLoggedIn();
      if (!hasToken) {
        _clearSessionState();
        return false;
      }

      final authSession = await _authService.getCurrentUser();
      _currentUser = authSession.user;
      if (authSession.currentCircle != null) {
        _currentCircle = authSession.currentCircle;
      }
      await refreshCircleMembers(allowFailure: true);
      await refreshSubscription(allowFailure: true);
      return true;
    } on UnauthorizedException {
      await _authService.clearLocalSession();
      _clearSessionState();
      return false;
    } on ApiException {
      _clearSessionState();
      return false;
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isAuthenticating = true;
    notifyListeners();

    try {
      var authSession = await _authService.login(email, password);
      authSession = await _hydrateAuthSession(authSession);
      _currentUser = authSession.user;
      await _applyAuthCircle(authSession.currentCircle);
      _clearCircleMembersState();
      await refreshCircleMembers(allowFailure: true);
      await refreshSubscription(allowFailure: true);
      notifyListeners();
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
    String phone,
  ) async {
    _isAuthenticating = true;
    notifyListeners();

    try {
      var authSession = await _authService.register(
        name,
        email,
        password,
        passwordConfirmation,
        phone,
      );
      authSession = await _hydrateAuthSession(authSession);
      _currentUser = authSession.user;
      await _applyAuthCircle(authSession.currentCircle);
      _clearCircleMembersState();
      await refreshCircleMembers(allowFailure: true);
      await refreshSubscription(allowFailure: true);
      notifyListeners();
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_isAuthenticating) {
      return;
    }

    _isAuthenticating = true;
    notifyListeners();

    try {
      await _authService.logout();
    } on ApiException {
      // Local session is still cleared by the auth service.
    } finally {
      _clearSessionState();
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<String> joinCircle(String referalCode) async {
    if (_isUpdatingCircle) {
      return '';
    }

    _isUpdatingCircle = true;
    notifyListeners();

    try {
      final result = await _circleService.joinCircle(referalCode);
      _currentCircle = result.circle;
      await _authStorage.saveCurrentCircle(result.circle);
      await refreshCircleMembers(allowFailure: true);
      notifyListeners();
      return result.message;
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    } finally {
      _isUpdatingCircle = false;
      notifyListeners();
    }
  }

  Future<String> leaveCircle() async {
    if (_isUpdatingCircle) {
      return '';
    }

    _isUpdatingCircle = true;
    notifyListeners();

    try {
      final result = await _circleService.leaveCircle();
      _currentCircle = result.circle;
      await _authStorage.saveCurrentCircle(result.circle);
      await refreshCircleMembers(allowFailure: true);
      notifyListeners();
      return result.message;
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    } finally {
      _isUpdatingCircle = false;
      notifyListeners();
    }
  }

  Future<void> refreshSubscription({bool allowFailure = false}) async {
    if (_isLoadingSubscription) {
      return;
    }

    _isLoadingSubscription = true;
    _subscriptionError = null;
    notifyListeners();

    try {
      _subscription = await _subscriptionService.getSubscription();
    } on UnauthorizedException {
      await _handleUnauthorized();
      if (!allowFailure) {
        rethrow;
      }
    } on ApiException catch (e) {
      _subscriptionError = e.message;
      if (!allowFailure) {
        rethrow;
      }
    } finally {
      _isLoadingSubscription = false;
      notifyListeners();
    }
  }

  Future<void> refreshCircleMembers({bool allowFailure = false}) async {
    final circle = _currentCircle;
    if (circle == null) {
      _clearCircleMembersState();
      notifyListeners();
      return;
    }

    if (_isLoadingCircleMembers) {
      return;
    }

    final isNewCircle = _circleMembersCircleId != circle.id;
    _isLoadingCircleMembers = true;
    _hasLoadedCircleMembers = false;
    _circleMembersError = null;
    _circleMembersCircleId = circle.id;
    if (isNewCircle) {
      _circleMembers = const <CircleMember>[];
    }
    notifyListeners();

    try {
      final members = await _circleService.getCircleMembers(circle.id);
      if (_currentCircle?.id == circle.id) {
        _circleMembers = members;
        _circleMembersCircleId = circle.id;
        _hasLoadedCircleMembers = true;
      }
    } on UnauthorizedException {
      await _handleUnauthorized();
      if (!allowFailure) {
        rethrow;
      }
    } on ApiException catch (e) {
      if (_currentCircle?.id == circle.id) {
        _circleMembers = const <CircleMember>[];
        _circleMembersError = e.message;
        _circleMembersCircleId = circle.id;
        _hasLoadedCircleMembers = true;
      }

      if (!allowFailure) {
        rethrow;
      }
    } finally {
      _isLoadingCircleMembers = false;
      notifyListeners();
    }
  }

  Future<void> uploadProfilePhoto(XFile photo) async {
    if (_isUploadingProfilePhoto) {
      return;
    }

    _isUploadingProfilePhoto = true;
    _profilePhotoError = null;
    notifyListeners();

    try {
      final updatedUser = await _authService.uploadProfilePhoto(photo);
      _currentUser = updatedUser;
      _circleMembers = [
        for (final member in _circleMembers)
          member.userId == updatedUser.id
              ? member.copyWith(user: updatedUser)
              : member,
      ];
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    } on ApiException catch (e) {
      _profilePhotoError = e.message;
      rethrow;
    } finally {
      _isUploadingProfilePhoto = false;
      notifyListeners();
    }
  }

  Future<SubscriptionPayment> upgradePremium({
    String? returnUrl,
  }) async {
    if (_isUpgradingSubscription) {
      final pendingPayment = _subscription?.pendingPayment;
      if (pendingPayment != null) {
        return pendingPayment;
      }
    }

    _isUpgradingSubscription = true;
    _subscriptionError = null;
    notifyListeners();

    try {
      final payment = await _subscriptionService.upgradeToPremium(
        returnUrl: returnUrl,
      );
      await refreshSubscription(allowFailure: true);
      return payment;
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    } on ApiException catch (e) {
      _subscriptionError = e.message;
      rethrow;
    } finally {
      _isUpgradingSubscription = false;
      notifyListeners();
    }
  }

  Future<void> loadSubscriptionPayments() async {
    try {
      _subscriptionPayments = await _subscriptionService.getPayments();
      notifyListeners();
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    }
  }

  Future<void> cancelPendingPayment(String orderId) async {
    if (_isCancellingPayment) {
      return;
    }

    _isCancellingPayment = true;
    _subscriptionError = null;
    notifyListeners();

    try {
      await _subscriptionService.cancelPendingPayment(orderId);
      await refreshSubscription(allowFailure: true);
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    } on ApiException catch (e) {
      _subscriptionError = e.message;
      rethrow;
    } finally {
      _isCancellingPayment = false;
      notifyListeners();
    }
  }

  Future<void> cancelSubscription() async {
    if (_isCancellingSubscription) {
      return;
    }

    _isCancellingSubscription = true;
    _subscriptionError = null;
    notifyListeners();

    try {
      await _subscriptionService.cancelSubscription();
      await refreshSubscription(allowFailure: true);
    } on UnauthorizedException {
      await _handleUnauthorized();
      rethrow;
    } on ApiException catch (e) {
      _subscriptionError = e.message;
      rethrow;
    } finally {
      _isCancellingSubscription = false;
      notifyListeners();
    }
  }

  Future<void> _handleUnauthorized() async {
    await _authService.clearLocalSession();
    _clearSessionState();
    notifyListeners();
  }

  Future<AuthSession> _hydrateAuthSession(AuthSession authSession) async {
    if (authSession.currentCircle != null) {
      return authSession;
    }

    try {
      return await _authService.getCurrentUser();
    } on ApiException {
      return authSession;
    }
  }

  Future<void> _applyAuthCircle(CircleSummary? circle) async {
    _currentCircle = circle;
    if (circle == null) {
      await _authStorage.deleteCurrentCircle();
      return;
    }

    await _authStorage.saveCurrentCircle(circle);
  }

  void _clearSessionState() {
    _currentUser = null;
    _currentCircle = null;
    _profilePhotoError = null;
    _isUploadingProfilePhoto = false;
    _clearCircleMembersState();
    _clearSubscriptionState();
  }

  void _clearCircleMembersState() {
    _circleMembers = const <CircleMember>[];
    _circleMembersError = null;
    _circleMembersCircleId = null;
    _isLoadingCircleMembers = false;
    _hasLoadedCircleMembers = false;
  }

  void _clearSubscriptionState() {
    _subscription = null;
    _subscriptionPayments = const <SubscriptionPayment>[];
    _subscriptionError = null;
  }
}
