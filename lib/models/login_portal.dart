import 'package:flutter/material.dart';

enum LoginPortal {
  usuario,
  lojista,
  oficina,
  admin,
}

extension LoginPortalX on LoginPortal {
  String get apiValue => name;

  String get title => switch (this) {
        LoginPortal.usuario => 'Área do Proprietário',
        LoginPortal.lojista => 'Área do Lojista',
        LoginPortal.oficina => 'Área da Oficina',
        LoginPortal.admin => 'Painel Administrador',
      };

  String get subtitle => switch (this) {
        LoginPortal.usuario => 'Histórico de veículos e manutenções',
        LoginPortal.lojista => 'Gerencie estoque e manutenções da sua loja',
        LoginPortal.oficina => 'Gerencie serviços e o perfil da sua oficina',
        LoginPortal.admin => 'Acesso exclusivo para gestão da plataforma',
      };

  String get hubTitle => switch (this) {
        LoginPortal.usuario => 'Proprietário de veículo',
        LoginPortal.lojista => 'Lojista / Garagem',
        LoginPortal.oficina => 'Oficina',
        LoginPortal.admin => 'Administrador',
      };

  String get hubSubtitle => switch (this) {
        LoginPortal.usuario => 'Histórico pessoal de carros e manutenções',
        LoginPortal.lojista => 'Estoque de veículos e revisões pré-venda',
        LoginPortal.oficina => 'Serviços realizados e perfil no diretório',
        LoginPortal.admin => 'Gestão da plataforma e catálogo',
      };

  IconData get icon => switch (this) {
        LoginPortal.usuario => Icons.person_outline,
        LoginPortal.lojista => Icons.storefront_outlined,
        LoginPortal.oficina => Icons.build_outlined,
        LoginPortal.admin => Icons.settings_outlined,
      };

  Color get accent => switch (this) {
        LoginPortal.usuario => const Color(0xFF1D4ED8),
        LoginPortal.lojista => const Color(0xFF047857),
        LoginPortal.oficina => const Color(0xFFCA8A04),
        LoginPortal.admin => const Color(0xFFEA580C),
      };

  bool get showInHub =>
      this == LoginPortal.usuario || this == LoginPortal.lojista;

  /// Só proprietário. O backend aceita auto-cadastro apenas para `user`
  /// ("Public registration is only available for vehicle owners"); contas de
  /// lojista e de oficina são criadas pelo portal web.
  bool get canRegister => this == LoginPortal.usuario;

  bool get supportsSocialLogin =>
      this == LoginPortal.usuario || this == LoginPortal.lojista;

  String get registerCta => 'Criar conta gratuita';
}
