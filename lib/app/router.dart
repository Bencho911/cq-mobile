import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../data/history.dart';
import '../features/account/album.dart';
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

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    // ── Acceso ──
    GoRoute(path: '/onboarding', pageBuilder: (c, s) => _fade(s, const OnboardingScreen())),
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/input-pin', builder: (c, s) => InputPinScreen(phone: _extra<String>(s))),
    GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
    GoRoute(path: '/otp-loading', pageBuilder: (c, s) => _fade(s, OtpLoadingScreen(phone: _extra<String>(s)))),
    GoRoute(path: '/confirm-otp', pageBuilder: (c, s) => _fade(s, ConfirmOtpScreen(phone: _extra<String>(s)))),
    GoRoute(path: '/create-pin', builder: (c, s) => const CreatePinScreen()),
    GoRoute(path: '/account-loading', pageBuilder: (c, s) => _fade(s, const AccountLoadingScreen())),

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
    GoRoute(path: '/rating-review', builder: (c, s) => const RatingReviewScreen()),
    GoRoute(path: '/payment-method', builder: (c, s) => const PaymentMethodScreen()),
    GoRoute(path: '/vouchers', builder: (c, s) => const VouchersScreen()),
    GoRoute(path: '/loyalty', redirect: (c, s) => '/album'),
    GoRoute(path: '/privacy', builder: (c, s) => const PrivacyScreen()),
  ],
);
