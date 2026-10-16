# Café Quindío · app móvil

App nativa (Android e iOS) en Flutter para pedir antes de llegar, recoger sin
fila y llenar el álbum de aves con los puntos. Es la versión móvil de
[cq-frontend](https://github.com/Bencho911/cq-frontend) (web en React), con el
mismo sistema de diseño «Fachadas».

## Requisitos

- Flutter 3.47 o superior (Dart 3.13)
- Android Studio (SDK de Android) y/o Xcode para iOS

## Correr la app

```bash
flutter pub get
flutter run                     # con datos de prueba (mocks)
```

Contra el backend real (kiora-backend):

```bash
flutter run \
  --dart-define=USE_MOCKS=false \
  --dart-define=API_URL=https://tu-gateway/api \
  --dart-define=KIOSK_API_KEY=...
```

| Variable | Por defecto | Qué hace |
|---|---|---|
| `USE_MOCKS` | `true` | Usa datos locales etiquetados como mock cuando no hay backend. |
| `API_URL` | `http://10.0.2.2:3000/api` | Base del API Gateway (10.0.2.2 es el localhost del emulador de Android). |
| `KIOSK_API_KEY` | vacío | Llave pública del kiosco para pedidos sin sesión. |

## Verificar

```bash
flutter analyze
flutter test
```

## Probar en iPhone (Codemagic + TestFlight)

`codemagic.yaml` tiene dos flujos que se lanzan a mano desde Codemagic:
**iOS · TestFlight** (compila, firma y sube a TestFlight) y **Android · APK de
prueba**. La primera vez hay que preparar la cuenta de Apple:

1. **Apple Developer Program** activo (cuenta de empresa o personal).
2. En [developer.apple.com](https://developer.apple.com/account/resources/identifiers)
   → Identifiers, registrar el App ID `co.com.cafequindio.app`.
3. En [App Store Connect](https://appstoreconnect.apple.com) → Apps → «+»,
   crear la app con ese bundle ID. Copiar su **Apple ID** numérico
   (Información de la app) y ponerlo en `APP_STORE_APPLE_ID` de `codemagic.yaml`.
4. App Store Connect → Usuarios y acceso → Integraciones → **Llaves del API**:
   crear una con rol *App Manager* y descargar el `.p8` (solo se puede una vez).
5. En Codemagic → Ajustes del equipo → Integraciones → **Developer Portal**:
   agregar la llave con el nombre `cq-app-store-connect` (Issuer ID, Key ID y el `.p8`).
6. Codemagic → Ajustes del equipo → **Code signing identities**: generar un
   certificado de distribución de iOS y luego «Fetch profiles» para el bundle ID.
7. Agregar el repositorio `cq-mobile` en Codemagic, elegir el flujo
   **iOS · TestFlight** y lanzar la compilación.
8. Cuando termine (y Apple procese la compilación, unos minutos), agregarse como
   probador interno en TestFlight e instalar desde la app **TestFlight** del iPhone.

El APK de Android sale como artefacto descargable de la compilación; se instala
en el teléfono permitiendo «instalar apps de origen desconocido».

## Estructura

```
lib/
  app/        router (go_router) y barra de pestañas
  core/       tema (colores, tipografía, movimiento), formato y configuración
  data/       modelos del API, cliente HTTP, servicios y datos mock
  state/      carrito, lealtad (puntos y aves), personalización, repetir pedido
  widgets/    componentes de marca: zócalo, fachada, estampilla, puerta, arco…
  features/   pantallas por área: auth, shop, checkout, account
assets/       fuentes, ilustraciones de marca, fotos de producto, sonidos
```

## Diseño

- **Colores**: blanco cal con texto y acciones en azul tinta (#18303C); tintas
  de las fachadas (mostaza, rosa, teal, verde, rojo) a pleno.
- **Tipografía**: Bricolage Grotesque (titulares), Neutra Text (interfaz),
  Neutra Text TF (precios y puntos).
- **Formas con un solo uso**: puerta = categorías, arco = armar el pedido,
  estampilla = lealtad. El zócalo rojo y tinta cierra las fachadas.
- **Movimiento**: poco en lo que se usa a diario, más en los momentos raros
  (apertura, pedido recibido, álbum). Todo respeta «reducir movimiento».

## Pendientes conocidos

- Confirmar la licencia de Neutra Text (House Industries) para uso en apps.
- Regla real de puntos: hoy es una estimación provisional (1 punto por cada $5.000).
- Perfil, historial de pedidos y saldo de puntos son mock hasta que el backend los exponga.
