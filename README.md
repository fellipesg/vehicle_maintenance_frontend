# Vehicle Maintenance — Frontend (Flutter)

App Flutter para registro e consulta do histórico de manutenções veiculares, integrado à API Laravel.

> Backend: [`vehicle_maintenance`](https://github.com/fellipesg/vehicle_maintenance)

## Stack

| Área | Tecnologia |
|------|------------|
| Framework | Flutter 3 · Dart 3 |
| Estado | Provider |
| HTTP | Dio / http |
| Auth | Token local (`shared_preferences`) + OAuth via WebView |
| Arquivos | `file_picker`, PDF (`pdf` / `printing`) |
| Push | Firebase Cloud Messaging |

## Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0 (`flutter doctor` limpo)
- Android Studio / Xcode conforme a plataforma alvo
- Backend rodando (veja o README do repositório backend)

## Início rápido

```bash
git clone https://github.com/fellipesg/vehicle_maintenance_frontend.git
cd vehicle_maintenance_frontend

flutter pub get
```

### Configurar URL da API

A base URL é definida via `--dart-define` (recomendado) ou pelo valor padrão em `lib/main.dart`.

| Ambiente | URL sugerida |
|----------|----------------|
| Emulador Android | `http://10.0.2.2:8000/api/v1` |
| Simulador iOS | `http://127.0.0.1:8000/api/v1` |
| Device físico | `http://<IP-da-sua-máquina>:8000/api/v1` |
| Túnel (ngrok/cloudflare) | `https://<seu-host>/api/v1` |

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

> Em Android 9+, HTTP claro exige `usesCleartextTraffic` / network security config no emulador/dev. Em produção use HTTPS.

### Rodar

```bash
# listar devices
flutter devices

flutter run
# ou
flutter run -d chrome          # web (smoke test)
flutter run -d macos           # desktop, se habilitado
```

## Firebase (opcional, push notifications)

Arquivos com chaves **não** entram no git:

- `android/app/google-services.json`
- `lib/firebase_options.dart`

Setup:

```bash
cp android/app/google-services.json.example android/app/google-services.json
cp lib/firebase_options.dart.example lib/firebase_options.dart
# preencha com dados do Firebase Console
# ou:
dart pub global activate flutterfire_cli
flutterfire configure
```

Detalhes: [FIREBASE_SETUP.md](./FIREBASE_SETUP.md).

Sem Firebase configurado, remova/comente a inicialização em `main.dart` antes de rodar, ou complete o setup acima.

## Build de release

```bash
# Android APK
flutter build apk --release \
  --dart-define=API_BASE_URL=https://sua-api.exemplo.com/api/v1

# Android App Bundle (Play Store)
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://sua-api.exemplo.com/api/v1

# iOS (macOS + Xcode)
flutter build ios --release \
  --dart-define=API_BASE_URL=https://sua-api.exemplo.com/api/v1
```

Há também scripts auxiliares no repositório (`build-apk.sh`, `clean-and-build.sh`) para builds locais.

## Estrutura

```
lib/
├── main.dart
├── models/          # DTOs (vehicle, maintenance, invoice…)
├── services/        # API, auth, storage
├── views/           # Telas
├── controllers/     # ViewModels / estado
└── widgets/         # Componentes reutilizáveis
```

## Funcionalidades

- Login / registro (API + OAuth quando habilitado no backend)
- Cadastro e listagem de veículos
- Registro de manutenções e itens
- Upload de notas fiscais
- Histórico e exportação (via API)
- Notificações push (Firebase)

## Qualidade

```bash
flutter analyze
flutter test
```

## Segurança

- Não committe `google-services.json`, `firebase_options.dart` nem keystores
- Prefira HTTPS + `--dart-define` para a URL da API em builds distribuídos
- Tokens ficam em `shared_preferences` — trate device loss / logout adequadamente

## Licença

MIT
