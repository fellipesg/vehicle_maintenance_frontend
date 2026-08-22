sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  const LoginSuccess();
}

class LoginNeedsTwoFactor extends LoginResult {
  const LoginNeedsTwoFactor({required this.challengeToken});

  final String challengeToken;
}

class LoginFailure extends LoginResult {
  const LoginFailure();
}
