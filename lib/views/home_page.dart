import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/vehicle_cover_avatar.dart';
import '../../widgets/vehicle_identity.dart';
import 'auth/login_hub_page.dart';
import 'profile/profile_edit_page.dart';
import 'profile/settings_page.dart';
import 'vehicles/vehicle_form_page.dart';
import 'vehicles/vehicle_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const VehiclesPage(key: PageStorageKey('vehicles-tab')),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/brand/lockup-horizontal.png',
            height: 32,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF0B1C2C),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: 'Veículos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  static int initStateCallCount = 0;

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  @override
  void initState() {
    super.initState();
    VehiclesPage.initStateCallCount++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<VehicleRepository>().load();
    });
  }

  Future<void> _refresh(VehicleRepository repository) {
    return repository.load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleRepository>(
      builder: (context, repository, _) {
        final vehicles = repository.vehicles;
        final isInitialLoad = vehicles.isEmpty &&
            repository.isRefreshing &&
            repository.error == null;

        if (isInitialLoad) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return _buildBody(context, repository, vehicles);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    VehicleRepository repository,
    List<Vehicle> vehicles,
  ) {
    if (vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum veículo cadastrado',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione um veículo para começar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VehicleFormPage(),
                  ),
                );
                if (result == true) {
                  await context.read<VehicleRepository>().invalidate();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Veículo'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (repository.isRefreshing && vehicles.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(repository),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  final maintenances = vehicle.maintenances ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: VehicleCoverAvatar(
                        coverPhotoUrl: vehicle.coverPhotoUrl,
                        coverPhotoPortraitUrl: vehicle.coverPhotoPortraitUrl,
                        coverPhotoThumbUrl: vehicle.coverPhotoThumbUrl,
                        size: 48,
                      ),
                      title: Text(
                        vehicle.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VehicleIdentity(vehicle: vehicle),
                          const SizedBox(height: 4),
                          Text('${vehicle.year} - ${vehicle.color ?? 'N/A'}'),
                          if (maintenances.isNotEmpty)
                            Text(
                              '${maintenances.length} manutenção(ões)',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VehicleDetailPage(
                              vehicleId: vehicle.id!,
                              initialVehicle: vehicle,
                            ),
                          ),
                        );
                        if (result == true) {
                          await context.read<VehicleRepository>().invalidate();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VehicleFormPage(),
            ),
          );
          if (result == true) {
            await context.read<VehicleRepository>().invalidate();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Veículo'),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _refreshUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.getCurrentUser();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginHubPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              UserAvatar(
                name: user?['name']?.toString(),
                avatarUrl: user?['avatar_url']?.toString(),
              ),
              const SizedBox(height: 24),
              Text(
                user?['name'] ?? 'Usuário',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                user?['email'] ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Meus Dados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditPage(),
                      ),
                    );
                    if (result == true) {
                      await _refreshUser();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configurações'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
