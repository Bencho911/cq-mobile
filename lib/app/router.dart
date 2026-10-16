import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../data/history.dart';
import '../features/account/album.dart';
import '../features/account/edit_profile.dart';
import '../features/account/preferences.dart';
import '../features/account/invoice.dart';
import '../features/account/order_details.dart';
import '../features/account/orders.dart';
import '../features/account/privacy.dart';
import '../features/account/profile.dart';
import '../features/account/rating_review.dart';
import '../features/auth/account_loading.dart';
import '../features/auth/confirm_otp.dart';
import '../features/auth/create_pin.dart';
import '../features/auth/input_pin.dart';
import '../features/auth/login.dart';
import '../features/auth/onboarding.dart';
import '../features/auth/otp_loading.dart';
import '../features/auth/register.dart';
import '../features/auth/unlock.dart';
import '../features/checkout/checkout.dart';
import '../features/checkout/checkout_loading.dart';
import '../features/checkout/order_success.dart';
import '../features/checkout/payment_method.dart';
import '../features/checkout/track_order.dart';
import '../features/checkout/vouchers.dart';
import '../features/shop/home.dart';
import '../features/shop/menu.dart';
import '../features/shop/notifications.dart';
import '../features/shop/stores.dart';
import '../state/account.dart';
import 'shell.dart';

/// Argumentos de «Pedido recibido».
class OrderSuccessArgs {
  const OrderSuccessArgs({this.orderId, this.earned = 0});
  final int? orderId;
  final int earned;
}

/// Pantallas de pantalla completa que reemplazan a la anterior (esperas,
/// confirmaciones): entran con un fundido corto en lugar de deslizarse.
Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: CQMotion.medium,
      reverseTransitionDuration: CQMotion.fast,
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: CQMotion.easeOut), child: child),
    );

/// Las pestañas cambian al instante (sin transición).
Page<void> _instant(GoRouterState state, Widget child) => NoTransitionPage<void>(key: state.pageKey, child: child);

T? _extra<T>(GoRouterState s) => s.extra is T ? s.extra as T : null;

/// Rutas que se pueden ver sin sesión.
const _publicRoutes = {
  '/onboarding',
  '/login',
  '/input-pin',
  '/register',
  '/otp-loading',
  '/confirm-otp',
  '/create-pin',
  '/account-loading',
};

/// Con sesión abierta no tiene sentido volver a la bienvenida o al ingreso.
const _signedOutOnly = {'/onboarding', '/login', '/register'};

/// Router con la sesión: sin cuenta abierta lleva a la bienvenida; con la
/// sesión bloqueada (biometría) lleva a la pantalla de desbloqueo.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth.loggedIn && auth.locked) return loc == '/unlock' ? null : '/unlock';
      if (!auth.loggedIn) return _publicRoutes.contains(loc) ? null : '/onboarding';
      if (loc == '/unlock' || _signedOutOnly.contains(loc)) return '/home';
      return null;
    },
    routes: _routes,
  );
});

final _routes = <RouteBase>[
    // ── Acceso ──
    GoRoute(path: '/onboarding', pageBuilder: (c, s) => _fade(s, const OnboardingScreen())),
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/input-pin', builder: (c, s) => InputPinScreen(phone: _extra<String>(s))),
    GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
    // extra: OtpArgs (teléfono, código de prueba, modo recuperar) o String teléfono.
    GoRoute(
      path: '/otp-loading',
      pageBuilder: (c, s) {
        final a = OtpArgs.from(s.extra);
        return _fade(s, OtpLoadingScreen(phone: a.phone, code: a.code, recover: a.recover));
      },
    ),
    GoRoute(
      path: '/confirm-otp',
      pageBuilder: (c, s) {
        final a = OtpArgs.from(s.extra);
        return _fade(s, ConfirmOtpScreen(phone: a.phone, code: a.code, recover: a.recover));
      },
    ),
    GoRoute(path: '/create-pin', builder: (c, s) => CreatePinScreen(recover: OtpArgs.from(s.extra).recover)),
    GoRoute(path: '/account-loading', pageBuilder: (c, s) => _fade(s, const AccountLoadingScreen())),
    GoRoute(path: '/unlock', pageBuilder: (c, s) => _fade(s, const UnlockScreen())),

    // ── Pestañas ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => TabShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', pageBuilder: (c, s) => _instant(s, const HomeScreen()))]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/menu', pageBuilder: (c, s) => _instant(s, MenuScreen(category: _extra<String>(s)))),
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/album', pageBuilder: (c, s) => _instant(s, const AlbumScreen()))]),
        StatefulShellBranch(routes: [GoRoute(path: '/orders', pageBuilder: (c, s) => _instant(s, const OrdersScreen()))]),
      ],
    ),

    GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
    GoRoute(path: '/stores', builder: (c, s) => const StoresScreen()),
    GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),

    // ── Pago y seguimiento ──
    GoRoute(path: '/checkout', builder: (c, s) => const CheckoutScreen()),
    GoRoute(path: '/checkout-loading', pageBuilder: (c, s) => _fade(s, const CheckoutLoadingScreen())),
    GoRoute(
      path: '/order-success',
      pageBuilder: (c, s) {
        final a = _extra<OrderSuccessArgs>(s);
        return _fade(s, OrderSuccessScreen(orderId: a?.orderId, earned: a?.earned ?? 0));
      },
    ),
    GoRoute(path: '/track-order', pageBuilder: (c, s) => _fade(s, TrackOrderScreen(orderId: _extra<int>(s)))),
    GoRoute(path: '/order-details', builder: (c, s) => OrderDetailsScreen(orderId: _extra<int>(s))),
    GoRoute(
      path: '/invoice/:id',
      builder: (c, s) => InvoiceScreen(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0, order: _extra<PastOrder>(s)),
    ),

    // ── Extra ──
    GoRoute(path: '/rating-review', builder: (c, s) => RatingReviewScreen(orderId: _extra<int>(s))),
    GoRoute(path: '/payment-method', builder: (c, s) => const PaymentMethodScreen()),
    GoRoute(path: '/vouchers', builder: (c, s) => const VouchersScreen()),
    GoRoute(path: '/loyalty', redirect: (c, s) => '/album'),
    GoRoute(path: '/privacy', builder: (c, s) => const PrivacyScreen()),
    GoRoute(path: '/edit-profile', builder: (c, s) => const EditProfileScreen()),
    GoRoute(path: '/preferences', builder: (c, s) => const PreferencesScreen()),
];
