# Vehicle Maintenance - Flutter App

Aplicativo mobile Flutter para registro de manutenções de veículos.

## Pré-requisitos

- Flutter SDK (versão 3.0 ou superior)
- Dart SDK
- Android Studio / Xcode (para desenvolvimento mobile)

## Instalação

1. Instale o Flutter seguindo a [documentação oficial](https://flutter.dev/docs/get-started/install)

2. Clone ou navegue até o diretório do projeto:
```bash
cd ~/vehicle_maintenance/frontend
```

3. Instale as dependências:
```bash
flutter pub get
```

## Executando o App

### Android
```bash
flutter run
```

### iOS
```bash
flutter run
```

### Web (para testes)
```bash
flutter run -d chrome
```

## Estrutura do Projeto

```
lib/
├── models/          # Modelos de dados
├── services/        # Serviços (API, storage, etc.)
├── views/           # Telas/Views
├── controllers/     # Controllers/ViewModels
└── widgets/         # Widgets reutilizáveis
```

## Configuração da API

Edite o arquivo `lib/services/api_service.dart` e altere a `baseUrl` para o endereço do seu backend:

```dart
ApiService(baseUrl: 'http://seu-ip:8080/api/v1')
```

Para Android, use `10.0.2.2` em vez de `localhost` quando testando no emulador.

## Funcionalidades

- [ ] Cadastro de veículos (placa/RENAVAM)
- [ ] Registro de manutenções
- [ ] Upload de notas fiscais (PDF)
- [ ] Checklist inicial e final
- [ ] Histórico completo de manutenções
- [ ] Exportação para PDF
- [ ] Busca de veículos por placa/RENAVAM

## Desenvolvimento

Este é um projeto em desenvolvimento. As funcionalidades serão implementadas progressivamente.

