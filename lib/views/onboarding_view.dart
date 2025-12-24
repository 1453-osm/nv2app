import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../viewmodels/onboarding_viewmodel.dart';
import '../viewmodels/location_viewmodel.dart';
import '../models/location_model.dart';
import '../viewmodels/prayer_times_viewmodel.dart';
import '../services/theme_service.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> with WidgetsBindingObserver {
  // Kullanılmayan controller'ları kaldırdık
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LocationViewModel>().loadCountries();
        // Ekrana gelince izinleri tazele
        context.read<OnboardingViewModel>().refreshPermissions();
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<OnboardingViewModel>().refreshPermissions();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Dinamik tema rengini al
          final themeColor = themeService.currentThemeColor;
          
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: themeColor,
            ),
            child: SafeArea(
              child: Consumer<OnboardingViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        const _HeaderWidget(),
                        
                        const SizedBox(height: 20),
                        
                        _LocationSelectionCard(
                          searchController: _searchController,
                          searchFocusNode: _searchFocusNode,
                        ),
                        
                        const SizedBox(height: 20),
                        
                        const _PermissionsAndStartSection(),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// Ayrıştırılmış Widget'lar

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.mosque,
            size: 30,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Namaz Vaktim',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationSelectionCard extends StatelessWidget {
  const _LocationSelectionCard({
    required this.searchController,
    required this.searchFocusNode,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 200, sigmaY: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Consumer<LocationViewModel>(
            builder: (context, locationViewModel, child) {
              return _LocationSelectionContent(
                searchController: searchController,
                searchFocusNode: searchFocusNode,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LocationSelectionContent extends StatefulWidget {
  const _LocationSelectionContent({
    required this.searchController,
    required this.searchFocusNode,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  @override
  State<_LocationSelectionContent> createState() => _LocationSelectionContentState();
}

class _LocationSelectionContentState extends State<_LocationSelectionContent> {
  void _performCitySearch(String query, LocationViewModel locationViewModel) async {
    try {
      await locationViewModel.searchAllCities(query);
    } catch (e) {
      // Hata durumunda sessizce geç
    }
  }

  void _selectCityFromSearch(City city, LocationViewModel locationViewModel) async {
    widget.searchController.clear();
    widget.searchFocusNode.unfocus();
    await locationViewModel.selectCityById(city.id);
    if (mounted) {
      context.read<PrayerTimesViewModel>().loadPrayerTimes(city.id);
      await context.read<OnboardingViewModel>().refreshPermissions();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LocationViewModel>(
      builder: (context, locationViewModel, child) {
        return Column(
          children: [
            const _InstructionText(),
            const SizedBox(height: 20),
            _AutoLocationCard(locationViewModel: locationViewModel),
            const SizedBox(height: 16),
            _SearchBar(
              searchController: widget.searchController,
              searchFocusNode: widget.searchFocusNode,
              onCitySearch: _performCitySearch,
              onCitySelect: _selectCityFromSearch,
            ),
            if (locationViewModel.selectedLocationText != 'Konum seçilmedi')
              _SelectedLocationDisplay(locationViewModel: locationViewModel),
            if (locationViewModel.errorMessage.isNotEmpty)
              _ErrorMessageDisplay(errorMessage: locationViewModel.errorMessage),
          ],
        );
      },
    );
  }
}

// Ayrıştırılmış küçük widget'lar

class _InstructionText extends StatelessWidget {
  const _InstructionText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Başlamak için konum seçin',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

class _AutoLocationCard extends StatelessWidget {
  const _AutoLocationCard({required this.locationViewModel});

  final LocationViewModel locationViewModel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: locationViewModel.isLoading
                  ? null
                  : () async {
                      await locationViewModel.getCurrentLocationFromGPS();
                      if (context.mounted) {
                        await context.read<OnboardingViewModel>().refreshPermissions();
                      }
                      if (context.mounted && locationViewModel.isLocationSelected) {
                        context.read<PrayerTimesViewModel>()
                            .loadPrayerTimes(locationViewModel.selectedCity!.id);
                      }
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    locationViewModel.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.my_location, size: 20, color: Colors.white.withValues(alpha: 0.8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locationViewModel.isLoading 
                            ? 'Konum Alınıyor...' 
                            : 'Otomatik Konum',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.searchController,
    required this.searchFocusNode,
    required this.onCitySearch,
    required this.onCitySelect,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Function(String, LocationViewModel) onCitySearch;
  final Function(City, LocationViewModel) onCitySelect;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LocationViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: [
            _buildSearchInput(viewModel),
            if (widget.searchController.text.isNotEmpty && viewModel.cities.isNotEmpty)
              _buildSearchResults(viewModel),
          ],
        );
      },
    );
  }

  Widget _buildSearchInput(LocationViewModel viewModel) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: TextField(
            controller: widget.searchController,
            focusNode: widget.searchFocusNode,
            onChanged: (value) {
              if (value.isNotEmpty) {
                widget.onCitySearch(value, viewModel);
              } else {
                viewModel.cities.clear();
                if (mounted) setState(() {});
              }
            },
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Şehir ara...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.6)),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(LocationViewModel viewModel) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: viewModel.cities.length,
              itemBuilder: (context, index) {
                final city = viewModel.cities[index];
                return _SearchResultItem(
                  city: city,
                  onTap: () => widget.onCitySelect(city, viewModel),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({
    required this.city,
    required this.onTap,
  });

  final City city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  city.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.6),
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedLocationDisplay extends StatelessWidget {
  const _SelectedLocationDisplay({required this.locationViewModel});

  final LocationViewModel locationViewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationViewModel.selectedLocationText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _ErrorMessageDisplay extends StatelessWidget {
  const _ErrorMessageDisplay({required this.errorMessage});

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade100,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade100,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsAndStartSection extends StatelessWidget {
  const _PermissionsAndStartSection();

  @override
  Widget build(BuildContext context) {
    return Consumer2<OnboardingViewModel, LocationViewModel>(
      builder: (context, onboardingVm, locationVm, child) {
        final canStart = locationVm.isLocationSelected;

        return Column(
          children: [
            const SizedBox(height: 12),
            _PermissionTile(
              icon: Icons.notifications_active,
              title: 'Bildirim İzni',
              description: 'Vakit bildirimleri gönderebilmek için gereklidir.',
              granted: onboardingVm.notificationGranted,
              onTap: () => onboardingVm.requestNotificationPermission(),
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              icon: Icons.location_on,
              title: 'Konum İzni',
              description: 'Konuma göre doğru namaz vakitlerini göstermek için gereklidir.',
              granted: onboardingVm.locationGranted,
              onTap: () async {
                await onboardingVm.requestLocationPermission();
              },
            ),
            const SizedBox(height: 12),
            _PermissionTile(
              icon: Icons.battery_saver,
              title: 'Pil Optimizasyonundan Çıkar (Android)',
              description: 'Arka planda güvenilir bildirim/hatırlatıcı için önerilir.',
              granted: onboardingVm.ignoringBatteryOptimizations,
              onTap: () async {
                await onboardingVm.requestIgnoreBatteryOptimizations();
              },
            ),
            const SizedBox(height: 20),
            _StartButton(canStart: canStart),
          ],
        );
      },
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                        InkWell(
                          onTap: granted ? null : onTap,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: granted ? Colors.green.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              granted ? 'Verildi' : 'İzin Ver',
                              style: TextStyle(
                                color: granted ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.canStart});

  final bool canStart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 200, sigmaY: 200),
          child: Container(
            decoration: BoxDecoration(
              color: canStart ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: canStart ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canStart ? () => _completeOnboarding(context) : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Başla',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: canStart ? Colors.white : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _completeOnboarding(BuildContext context) async {
  final viewModel = context.read<OnboardingViewModel>();
  await viewModel.completeOnboarding();
  if (context.mounted) {
    Navigator.of(context).pushReplacementNamed('/home');
  }
} 