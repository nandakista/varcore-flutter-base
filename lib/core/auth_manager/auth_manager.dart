import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:varcore_flutter_base/core/database/get_storage/get_storage_box.dart';
import 'package:varcore_flutter_base/core/database/get_storage/get_storage_manager.dart';
import 'package:varcore_flutter_base/core/database/secure_storage/secure_storage_manager.dart';
import 'package:varcore_flutter_base/core/database/shared_preferences/shared_preference_manager.dart';
import 'package:varcore_flutter_base/core/auth_manager/auth_state.dart';
import 'package:varcore_flutter_base/data/data_sources/auth/auth_api_impl.dart';
import 'package:varcore_flutter_base/data/models/user.dart';
import 'package:varcore_flutter_base/ui/view/auth/login/login_view.dart';
import 'package:varcore_flutter_base/ui/view/auth/splash/splash_view.dart';
import 'package:varcore_flutter_base/ui/view/home/home_page.dart';

/// This class is called first time when your app is open.
///
/// This class help you to manage authentication process.
/// Contains auth general function such as [login], [logout], and first install/[setup]
class AuthManager extends GetxController {
  static AuthManager get to => Get.find<AuthManager>();

  String TAG = 'AUTH_MANAGER';
  Rxn<AuthState> authState = Rxn<AuthState>();
  Stream<AuthState?> get stream => authState.stream;
  AuthState? get state => authState.value;

  var getStorage = GetStorageManager.to;
  var secureStorage = SecureStorageManager.to;
  var sp = SharedPreferenceManager.to;

  @override
  void onInit() {
    authState.value = const AuthState(appStatus: AppType.INITIAL);
    super.onInit();
  }

  @override
  void onReady() async {
    ever(authState, authChanged);
    authChanged(state);
    super.onReady();
  }

  authChanged(AuthState? state) async {
    if (state?.appStatus == AppType.INITIAL) {
      await setup();
      checkUser();
    } else if (state?.appStatus == AppType.UNAUTHENTICATED) {
      clearData();
      Get.offAllNamed(LoginView.route);
    } else if (state?.appStatus == AppType.AUTHENTICATED) {
      Get.offAllNamed(HomePage.route);
    } else {
      Get.toNamed(SplashView.route);
    }
    update();
  }

  setup() async {
    final firstInstall = sp.getIsFirstInstall();
    if (firstInstall) {
      sp.setIsFirstInstall(value: false);
      await secureStorage.setToken(value: '');
    }
  }

  /// This function to used for checking is valid token to API Server use GET User Endpoint (token required).
  /// If response is Error it will passed to [logout] process.
  Future<void> checkUser() async {
    AuthApiImpl authApi = AuthApiImpl();
    final String? _token = await secureStorage.getToken();
    User? _user = getStorage.get(GetStorageBox.USERS);

    try {
      await authApi
          .verifyToken(userId: _user?.id ?? 0, token: _token.toString())
          .then((res) async {
        if (res.isActiveEmail ?? false) {
          login(
            user: res,
            token: res.token.toString(),
            refreshToken: res.refreshToken.toString(),
          );
        } else {
          logout();
        }
      });
    } catch (err) {
      logout();
    }
    // if (getStorage.has(GetStorageBox.USERS)) {
    //   setAuth();
    // } else {
    //   logout();
    // }
  }

  /// Just call this function to managed logout process.
  /// It will stream state and auto redirect your apps to page based on their state
  /// with [authChanged] function
  /// * No need to navigate manually (Get.to or Get.off)
  Future<void> logout() async {
    await secureStorage.logout();
    getStorage.logout();
    sp.logout();
    authState.value = const AuthState(appStatus: AppType.UNAUTHENTICATED);
  }

  /// Just call this function to managed login process.
  /// It will stream state and auto redirect your apps to page based on their state
  /// with [authChanged] function
  /// * No need to navigate manually (Get.to or Get.off).
  Future<void> login({
    required User user,
    required String token,
    required String refreshToken,
  }) async {
    saveAuthData(user: user, token: token, refreshToken: refreshToken);
    authState.value = const AuthState(appStatus: AppType.AUTHENTICATED);
  }

  Future<void> saveAuthData({
    required User user,
    required String token,
    required String refreshToken,
  }) async {
    getStorage.write(GetStorageBox.USERS, user.toJson());
    await secureStorage.setToken(value: token);
    await secureStorage.setRefreshToken(value: refreshToken);
  }

  void clearData() {
    if (getStorage.has(GetStorageBox.USERS)) {
      getStorage.delete(GetStorageBox.USERS);
    }
  }

  /// Get User data from GetStorage
  /// * No need to decode or call fromJson again when you used this helper
  User? get user {
    if (getStorage.has(GetStorageBox.USERS)) {
      return User.fromJson(getStorage.get(GetStorageBox.USERS));
    } else {
      return null;
    }
  }
}