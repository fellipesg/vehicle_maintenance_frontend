# Versões do Android Build

Este arquivo documenta as versões atuais das ferramentas de build Android.

## Versões Atuais (Atualizado)

- **Android Gradle Plugin (AGP)**: 8.9.1
- **Gradle Wrapper**: 8.11.1
- **Kotlin**: 2.1.0
- **compileSdkVersion**: 36
- **targetSdkVersion**: 36
- **minSdkVersion**: Definido pelo Flutter (flutter.minSdkVersion)
- **Java Compatibility**: VERSION_17
- **Kotlin JVM Target**: 17

## Compatibilidade

- AGP 8.9.1 requer Gradle 8.11.1 ou superior ✅
- compileSdkVersion 36 é suportado pelo AGP 8.9.1 ✅
- Kotlin 2.1.0 é compatível com AGP 8.9.1 ✅

## Arquivos de Configuração

- `settings.gradle`: Define AGP e Kotlin versions
- `build.gradle`: Define classpath do AGP e Kotlin
- `app/build.gradle`: Define compileSdkVersion, targetSdkVersion, etc.
- `gradle/wrapper/gradle-wrapper.properties`: Define versão do Gradle

## Limpeza de Cache

Se encontrar problemas de build, execute:

```bash
cd frontend
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
```

Ou use o script:
```bash
./clean-and-build.sh debug
```
