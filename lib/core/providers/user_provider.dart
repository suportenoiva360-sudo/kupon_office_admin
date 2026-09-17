import 'package:flutter/material.dart';
import 'package:kupon_office_admin/core/auth/auth_service.dart';
import 'package:kupon_office_admin/repositories/user_repository.dart';
import 'package:kupon_office_admin/repositories/wallet_repository.dart';
import 'package:kupon_office_admin/repositories/subscriptions_repository.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final UserRepository _userRepo = UserRepository();
  final WalletRepository _walletRepo = WalletRepository();
  final SubscriptionsRepository _subRepo = SubscriptionsRepository();

  Map<String, dynamic>? _profile;
  int _balance = 0;
  Map<String, dynamic>? _subscription;
  List<Map<String, dynamic>> _recentTrips = [];
  bool _isLoading = false;
  Map<String, String> _provinces = {};

  Map<String, dynamic>? get profile => _profile;
  int get balance => _balance;
  Map<String, dynamic>? get subscription => _subscription;
  List<Map<String, dynamic>> get recentTrips => _recentTrips;
  bool get isLoading => _isLoading;

  String get userName => _profile?['name'] ?? 'Utilizador';
  String? get userPhoto => _profile?['photo_url'];
  String get userEmail => _profile?['email'] ?? '';
  String get userPhone => _profile?['phone'] ?? '';
  String? get userProvinceId => _profile?['province_id'] as String?;
  String? get userProvinceName =>
      userProvinceId != null ? _provinces[userProvinceId] : null;
  String get subscriptionPlanName =>
      _subscription?['subscription_plans']?['name'] ?? 'Sem plano';
  int get tripCount => _recentTrips.length;

  double get avgRating {
    double total = 0;
    int count = 0;
    for (final trip in _recentTrips) {
      final rating = (trip['passenger_rating'] as num?)?.toInt();
      if (rating != null) {
        total += rating;
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  Future<void> loadAll() async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _userRepo.getProfile(userId),
        _walletRepo.getBalance(userId),
        _subRepo.getActiveSubscription(userId),
        _userRepo.getTrips(userId),
        _userRepo.getProvinces(),
      ]);

      _profile = results[0] as Map<String, dynamic>?;
      _balance = (results[1] as num?)?.toInt() ?? 0;
      _subscription = results[2] as Map<String, dynamic>?;
      _recentTrips = (results[3] as List<Map<String, dynamic>>)
          .where((t) => t['status'] == 'completed')
          .toList();
      final provincesList = results[4] as List<Map<String, dynamic>>;
      _provinces = {for (final p in provincesList) p['id'] as String: p['name'] as String};
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadAll();

  void updateBalance(int newBalance) {
    _balance = newBalance;
    notifyListeners();
  }
}
