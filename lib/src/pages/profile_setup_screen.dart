import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/media_service.dart';
import 'common.dart';
import 'theme/app_theme.dart';
import 'theme/liquid_glass.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.api});
  final Api api;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;
  late final TextEditingController _spotifyController;
  late final TextEditingController _linkedinController;

  String? _photo;
  final List<String> _photos = [];
  String? _relationshipStatus;
  String? _goal;
  final Set<String> _interests = {};

  bool _busy = false;
  String? _errorMessage;

  static const List<String> _relationshipOptions = [
    'Solteiro(a)',
    'Em um relacionamento sério',
    'Relacionamento aberto',
    'Enrolado(a)',
    'Prefiro não rotular',
  ];

  static const List<String> _goalOptions = [
    'Amizade e boas conversas',
    'Namoro sério',
    'Conhecer pessoas novas',
    'Bate-papo casual',
    'Companhia para eventos e rolês',
    'Networking profissional',
  ];

  static const List<String> _suggestedInterests = [
    'Café',
    'Música',
    'Cinema',
    'Arte',
    'Viagens',
    'Corrida',
    'Livros',
    'Fotografia',
    'Gastronomia',
    'Jogos',
    'Trilhas',
    'Shows',
  ];

  @override
  void initState() {
    super.initState();
    final me = widget.api.me ?? {};
    _nameController = TextEditingController(text: me['name']?.toString() ?? '');
    _bioController = TextEditingController(text: me['bio']?.toString() ?? '');

    final currentSocials = me['socials'] is Map
        ? Map<String, dynamic>.from(me['socials'] as Map)
        : <String, dynamic>{};
    _instagramController = TextEditingController(
      text: currentSocials['instagram']?.toString() ?? '',
    );
    _tiktokController = TextEditingController(
      text: currentSocials['tiktok']?.toString() ?? '',
    );
    _spotifyController = TextEditingController(
      text: currentSocials['spotify']?.toString() ?? '',
    );
    _linkedinController = TextEditingController(
      text: currentSocials['linkedin']?.toString() ?? '',
    );

    final rawPhoto = me['photo']?.toString() ?? '';
    if (rawPhoto.isNotEmpty) {
      _photo = rawPhoto;
      _photos.add(rawPhoto);
    }
    if (me['photos'] is List) {
      for (final p in me['photos'] as List) {
        final str = p.toString();
        if (str.isNotEmpty && !_photos.contains(str)) {
          _photos.add(str);
        }
      }
    }

    final rawRel = me['relationship_status']?.toString() ?? '';
    if (rawRel.isNotEmpty) _relationshipStatus = rawRel;

    final rawGoal = me['goal']?.toString() ?? '';
    if (rawGoal.isNotEmpty) _goal = rawGoal;

    if (me['interests'] is List) {
      for (final i in me['interests'] as List) {
        _interests.add(i.toString());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _spotifyController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool camera}) async {
    try {
      final picked = await pickPhoto(camera: camera);
      if (picked != null && mounted) {
        setState(() {
          _photo = picked;
          if (!_photos.contains(picked)) {
            _photos.insert(0, picked);
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _saveProfile() async {
    if (_busy) return;

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();

    // 1. Validar Foto
    if (_photo == null || _photo!.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Adicione uma foto de perfil para continuar.';
      });
      toast(context, 'Adicione uma foto de perfil para continuar.');
      return;
    }

    // 2. Validar Nome
    if (name.length < 2) {
      setState(() {
        _errorMessage = 'Informe seu nome de exibição (mínimo de 2 caracteres).';
      });
      toast(context, 'Informe seu nome de exibição.');
      return;
    }

    // 3. Validar Bio
    if (bio.length < 10) {
      setState(() {
        _errorMessage =
            'Escreva uma breve descrição na sua bio (mínimo de 10 caracteres).';
      });
      toast(
        context,
        'Escreva uma breve descrição sobre você (pelo menos 10 caracteres).',
      );
      return;
    }

    // 4. Validar Status de Relacionamento
    if (_relationshipStatus == null || _relationshipStatus!.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Selecione seu status de relacionamento.';
      });
      toast(context, 'Selecione seu status de relacionamento.');
      return;
    }

    // 5. Validar O que Procura
    if (_goal == null || _goal!.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Selecione o que você procura no Tevi.';
      });
      toast(context, 'Selecione o que você procura no Tevi.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final socials = <String, String>{};
      if (_instagramController.text.trim().isNotEmpty) {
        socials['instagram'] = _instagramController.text.trim();
      }
      if (_tiktokController.text.trim().isNotEmpty) {
        socials['tiktok'] = _tiktokController.text.trim();
      }
      if (_spotifyController.text.trim().isNotEmpty) {
        socials['spotify'] = _spotifyController.text.trim();
      }
      if (_linkedinController.text.trim().isNotEmpty) {
        socials['linkedin'] = _linkedinController.text.trim();
      }

      await widget.api.request('PATCH', '/me', {
        'name': name,
        'bio': bio,
        'goal': _goal,
        'relationship_status': _relationshipStatus,
        'photo': _photo,
        'photos': _photos,
        'interests': _interests.toList(),
        'socials': socials,
      });

      await widget.api.refresh();
      if (mounted) {
        toast(context, 'Perfil completo! Bem-vindo ao Tevi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
        });
        toast(context, 'Erro ao salvar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Deseja sair agora? Você poderá continuar a configuração do seu perfil quando entrar novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              widget.api.logout();
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurar Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _busy ? null : _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Hero
                LiquidGlassContainer(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.coral.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_pin_rounded,
                          size: 36,
                          color: context.coral,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Complete seu perfil',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Para começar a cruzar caminhos e garantir conexões autênticas, monte seu perfil inicial obrigatório.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 1. FOTO DE PERFIL (OBRIGATÓRIA)
                _buildSectionHeader(
                  title: '1. Foto de Perfil',
                  subtitle: 'Obrigatória • Uma foto nítida e recente do seu rosto',
                  icon: Icons.photo_camera_rounded,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              context.coral,
                              const Color(0xFF6F4BD8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.coral.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: PersonAvatar(
                          {
                            'name': _nameController.text.isNotEmpty
                                ? _nameController.text
                                : 'Você',
                            'photo': _photo ?? '',
                          },
                          radius: 56,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.coral,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF141724) : Colors.white,
                              width: 2.5,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _pickImage(camera: false),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galeria'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _pickImage(camera: true),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Câmera'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 2. NOME DE EXIBIÇÃO (OBRIGATÓRIO)
                _buildSectionHeader(
                  title: '2. Seu Nome',
                  subtitle: 'Obrigatório • Como as pessoas verão você',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Nome ou como gosta de ser chamado(a)',
                    hintText: 'Ex: Alex Silva',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // 3. BIO COM BREVE DESCRIÇÃO (OBRIGATÓRIA)
                _buildSectionHeader(
                  title: '3. Bio / Descrição',
                  subtitle: 'Obrigatória • Breve resumo sobre você (mín. 10 caracteres)',
                  icon: Icons.notes_rounded,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bioController,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Um pouco sobre você',
                    hintText: 'Ex: Apaixonado por cafés, música indie e caminhadas no parque. Sempre aberto a boas conversas e novas conexões.',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // 4. STATUS DE RELACIONAMENTO (OBRIGATÓRIO)
                _buildSectionHeader(
                  title: '4. Status de Relacionamento',
                  subtitle: 'Obrigatório • Seja transparente sobre seu momento',
                  icon: Icons.favorite_border_rounded,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _relationshipOptions.map((opt) {
                    final isSelected = _relationshipStatus == opt;
                    return ChoiceChip(
                      label: Text(opt),
                      selected: isSelected,
                      selectedColor: context.coral.withValues(alpha: 0.22),
                      side: BorderSide(
                        color: isSelected
                            ? context.coral
                            : (isDark ? Colors.white24 : Colors.black12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _relationshipStatus = val ? opt : null;
                          _errorMessage = null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // 5. O QUE PROCURA (OBRIGATÓRIO)
                _buildSectionHeader(
                  title: '5. O que Você Procura?',
                  subtitle: 'Obrigatório • Alinhe expectativas com quem cruzar seus passos',
                  icon: Icons.explore_outlined,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goalOptions.map((opt) {
                    final isSelected = _goal == opt;
                    return ChoiceChip(
                      label: Text(opt),
                      selected: isSelected,
                      selectedColor: const Color(0xFF6F4BD8).withValues(alpha: 0.22),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF6F4BD8)
                            : (isDark ? Colors.white24 : Colors.black12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _goal = val ? opt : null;
                          _errorMessage = null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // 6. REDES SOCIAIS (OPCIONAL)
                _buildSectionHeader(
                  title: '6. Redes Sociais',
                  subtitle: 'Opcional • Mostre seus links para conexões mais profundas',
                  icon: Icons.share_rounded,
                ),
                const SizedBox(height: 12),
                LiquidGlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _instagramController,
                        decoration: const InputDecoration(
                          labelText: 'Instagram (opcional)',
                          hintText: '@seu.usuario',
                          prefixIcon: Icon(
                            Icons.camera_alt_outlined,
                            color: Color(0xFFE1306C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tiktokController,
                        decoration: const InputDecoration(
                          labelText: 'TikTok (opcional)',
                          hintText: '@seu.usuario',
                          prefixIcon: Icon(
                            Icons.music_note_rounded,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _spotifyController,
                        decoration: const InputDecoration(
                          labelText: 'Spotify (opcional)',
                          hintText: 'Nome de perfil ou artista',
                          prefixIcon: Icon(
                            Icons.headphones_rounded,
                            color: Color(0xFF1DB954),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _linkedinController,
                        decoration: const InputDecoration(
                          labelText: 'LinkedIn (opcional)',
                          hintText: 'seu-usuario',
                          prefixIcon: Icon(
                            Icons.work_outline_rounded,
                            color: Color(0xFF0A66C2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 7. SEUS INTERESSES (OPCIONAL)
                _buildSectionHeader(
                  title: '7. Interesses em Comum',
                  subtitle: 'Opcional • Selecione até 10 temas que combinam com você',
                  icon: Icons.tag_rounded,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestedInterests.map((interest) {
                    final isSelected = _interests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (_interests.length < 10) {
                              _interests.add(interest);
                            } else {
                              toast(context, 'Máximo de 10 interesses.');
                            }
                          } else {
                            _interests.remove(interest);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 36),

                // BOTÃO FINAL DE SUBMISSÃO
                FilledButton(
                  onPressed: _busy ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: context.coral,
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Concluir perfil e entrar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ],
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.coral.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: context.coral),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: context.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
