# 🔥 Configuração do Firebase

## ⚠️ IMPORTANTE: Segurança

**NUNCA commite os arquivos de configuração do Firebase no repositório!**

Os arquivos `google-services.json` e `firebase_options.dart` contêm chaves de API que devem ser mantidas privadas, mesmo que sejam chaves de cliente.

## 📋 Passo a Passo

### 1. Obter arquivo `google-services.json`

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Selecione o projeto: `vehicle-maintenance-a9e32`
3. Vá em **Project Settings** (ícone de engrenagem)
4. Na aba **Your apps**, selecione o app Android
5. Baixe o arquivo `google-services.json`

### 2. Configurar arquivos localmente

**Copie os arquivos de exemplo e preencha com suas credenciais:**

```bash
# Copiar arquivo de exemplo do google-services.json
cp android/app/google-services.json.example android/app/google-services.json

# Editar e preencher com suas credenciais do Firebase Console
# (ou simplesmente copie o arquivo baixado do Firebase Console)
```

### 3. Gerar `firebase_options.dart`

Execute o comando para gerar o arquivo:

```bash
cd frontend
dart pub global activate flutterfire_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"
flutterfire configure --project=vehicle-maintenance-a9e32
```

**OU** copie o arquivo de exemplo e preencha manualmente:

```bash
# Copiar arquivo de exemplo
cp lib/firebase_options.dart.example lib/firebase_options.dart

# Editar e preencher com suas credenciais do Firebase Console
```

### 4. Verificar `.gitignore`

Certifique-se de que os arquivos sensíveis estão no `.gitignore`:

```
/android/app/google-services.json
/lib/firebase_options.dart
```

## ✅ Verificação

Após configurar, verifique se os arquivos estão funcionando:

```bash
# Verificar se os arquivos existem
ls -la android/app/google-services.json
ls -la lib/firebase_options.dart

# Verificar se estão no .gitignore (não devem aparecer no git status)
git status | grep -E "(google-services|firebase_options)"
```

Se aparecerem no `git status`, adicione-os ao `.gitignore` e remova do git:

```bash
git rm --cached android/app/google-services.json
git rm --cached lib/firebase_options.dart
```

## 🔐 Rotação de Chaves (se necessário)

Se suas chaves foram expostas:

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Vá em **Project Settings** > **Your apps**
3. Selecione o app Android
4. Clique em **Regenerate** para gerar novas chaves
5. Baixe o novo `google-services.json`
6. Atualize os arquivos localmente
7. Execute `flutterfire configure` novamente para atualizar `firebase_options.dart`
