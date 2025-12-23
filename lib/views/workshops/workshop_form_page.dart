import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'dart:convert';
import '../../models/workshop.dart';
import '../../services/api_service.dart';

class WorkshopFormPage extends StatefulWidget {
  final Workshop? workshop;

  const WorkshopFormPage({super.key, this.workshop});

  @override
  State<WorkshopFormPage> createState() => _WorkshopFormPageState();
}

class _WorkshopFormPageState extends State<WorkshopFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingCep = false;

  @override
  void initState() {
    super.initState();
    if (widget.workshop != null) {
      _populateForm(widget.workshop!);
    }
    _cepController.addListener(_onCepChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _cepController.removeListener(_onCepChanged);
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _populateForm(Workshop workshop) {
    _nameController.text = workshop.name;
    _phoneController.text = workshop.phone;
    _whatsappController.text = workshop.whatsapp ?? '';
    _emailController.text = workshop.email ?? '';
    _facebookController.text = workshop.facebook ?? '';
    _instagramController.text = workshop.instagram ?? '';
    _cepController.text = workshop.formattedCep;
    _streetController.text = workshop.street;
    _numberController.text = workshop.number;
    _complementController.text = workshop.complement ?? '';
    _neighborhoodController.text = workshop.neighborhood;
    _cityController.text = workshop.city;
    _stateController.text = workshop.state;
  }

  void _onCepChanged() {
    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length == 8) {
      _fetchCepData(cep);
    }
  }

  Future<void> _fetchCepData(String cep) async {
    setState(() {
      _isLoadingCep = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['erro'] == null) {
          setState(() {
            _streetController.text = data['logradouro'] ?? '';
            _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
            _stateController.text = data['uf'] ?? '';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CEP não encontrado'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Silently fail - user can fill manually
    } finally {
      setState(() {
        _isLoadingCep = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'facebook': _facebookController.text.trim().isEmpty
            ? null
            : _facebookController.text.trim(),
        'instagram': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'cep': _cepController.text.replaceAll(RegExp(r'\D'), ''),
        'street': _streetController.text.trim(),
        'number': _numberController.text.trim(),
        'complement': _complementController.text.trim().isEmpty
            ? null
            : _complementController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim().toUpperCase(),
      };

      Response response;
      if (widget.workshop != null) {
        response = await apiService.updateWorkshop(
          widget.workshop!.id.toString(),
          data,
        );
      } else {
        response = await apiService.createWorkshop(data);
      }

      if (response.data['success'] == true && mounted) {
        // If creating a new workshop, return the created workshop object
        // so it can be automatically selected
        if (widget.workshop == null) {
          final createdWorkshop = Workshop.fromJson(response.data['data']);
          Navigator.of(context).pop(createdWorkshop);
        } else {
          Navigator.of(context).pop(true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.workshop != null
                ? 'Oficina atualizada com sucesso!'
                : 'Oficina cadastrada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response.data['message'] ?? 'Erro ao salvar oficina');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.workshop != null ? 'Editar Oficina' : 'Nova Oficina'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nome
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Oficina *',
                    prefixIcon: Icon(Icons.build_circle),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nome é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Telefone e WhatsApp
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Telefone *',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Telefone é obrigatório';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _whatsappController,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                          prefixIcon: Icon(Icons.chat),
                          border: OutlineInputBorder(),
                          helperText: 'Deixe vazio para usar o telefone',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      if (!value.contains('@')) {
                        return 'Email inválido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Redes Sociais
                TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook (URL)',
                    prefixIcon: Icon(Icons.facebook),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram (URL)',
                    prefixIcon: Icon(Icons.camera_alt),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),

                // Endereço
                const Text(
                  'Endereço',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // CEP
                TextFormField(
                  controller: _cepController,
                  decoration: InputDecoration(
                    labelText: 'CEP *',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: _isLoadingCep
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    helperText: 'Digite o CEP para preencher automaticamente',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  validator: (value) {
                    final cep = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (cep.isEmpty) {
                      return 'CEP é obrigatório';
                    }
                    if (cep.length != 8) {
                      return 'CEP deve ter 8 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Logradouro
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Logradouro *',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Logradouro é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Número e Complemento
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _numberController,
                        decoration: const InputDecoration(
                          labelText: 'Número *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Número é obrigatório';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _complementController,
                        decoration: const InputDecoration(
                          labelText: 'Complemento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Bairro
                TextFormField(
                  controller: _neighborhoodController,
                  decoration: const InputDecoration(
                    labelText: 'Bairro *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Bairro é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Cidade e Estado
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'Cidade *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Cidade é obrigatória';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'UF *',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 2,
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'UF é obrigatória';
                          }
                          if (value.length != 2) {
                            return 'UF deve ter 2 letras';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Botão Salvar
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.workshop != null
                              ? 'Atualizar Oficina'
                              : 'Cadastrar Oficina',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
