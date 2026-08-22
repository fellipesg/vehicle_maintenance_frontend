import 'package:flutter/material.dart';

enum LoginPortal {
  usuario,
  lojista,
  admin,
}

extension LoginPortalX on LoginPortal {
  String get apiValue => name;

  String get title => switch (this) {
        LoginPortal.usuario => 'Área do Proprietário',
        LoginPortal.lojista => 'Área do Lojista',
        LoginPortal.admin => 'Painel Administrador',
      };

  String get subtitle => switch (this) {
        LoginPortal.usuario => 'Histórico de veículos e manutenções',
        LoginPortal.lojista => 'Gerencie estoque e manutenções da sua loja',
        LoginPortal.admin => 'Acesso exclusivo para gestão da plataforma',
      };

  String get hubTitle => switch (this) {
        LoginPortal.usuario => 'Proprietário de veículo',
        LoginPortal.lojista => 'Lojista / Garagem',
        LoginPortal.admin => 'Administrador',
      };

  String get hubSubtitle => switch (this) {
        LoginPortal.usuario => 'Histórico pessoal de carros e manutenções',
        LoginPortal.lojista => 'Estoque de veículos e revisões pré-venda',
        LoginPortal.admin => 'Gestão da plataforma e catálogo',
      };

  IconData get icon => switch (this) {
        LoginPortal.usuario => Icons.person_outline,
        LoginPortal.lojista => Icons.storefront_outlined,
        LoginPortal.admin => Icons.settings_outlined,
      };

  Color get accent => switch (this) {
        LoginPortal.usuario => const Color(0xFF1D4ED8),
        LoginPortal.lojista => const Color(0xFF047857),
        LoginPortal.admin => const Color(0xFFEA580C),
      };

  bool get canRegister => this != LoginPortal.admin;

  String get registerUserType => switch (this) {
        LoginPortal.lojista => 'garage',
        LoginPortal.admin => 'user',
        LoginPortal.usuario => 'user',
      };

  String get registerCta => switch (this) {
        LoginPortal.lojista => 'Cadastre sua loja',
        _ => 'Criar conta gratuita',
      };
}
