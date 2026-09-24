import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../profile/profile_page.dart';
import 'add_driver_page.dart';
import 'add_vehicle_page.dart';
import 'driver_list_page.dart';
import 'partner_trips_page.dart';
import 'vehicle_list_page.dart';

class PartnerDashboard extends StatefulWidget {
  const PartnerDashboard({super.key});

  @override
  State<PartnerDashboard> createState() =>
      _PartnerDashboardState();
}

class _PartnerDashboardState
    extends State<PartnerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _PartnerHomePage(),
    PartnerTripsPage(),
    _PartnerSupportPage(),
  ];

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ProfilePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'No new notifications.',
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none,
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected:
            (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.dashboard,
            ),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.route_outlined,
            ),
            selectedIcon: Icon(
              Icons.route,
            ),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.support_agent_outlined,
            ),
            selectedIcon: Icon(
              Icons.support_agent,
            ),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}

class _PartnerHomePage
    extends StatelessWidget {
  const _PartnerHomePage();

  void _openPage(
    BuildContext context,
    Widget page,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => page,
      ),
    );
  }

  void _openTrips(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const PartnerTripsPage(),
      ),
    );
  }

  void _comingSoon(
    BuildContext context,
    String title,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '$title feature is coming soon.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Partner Dashboard',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage your vehicles, drivers and trips.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.add_circle_outline,
                    title: 'Add Vehicle',
                    onTap: () {
                      _openPage(
                        context,
                        const AddVehiclePage(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.person_add_alt_1,
                    title: 'Add Driver',
                    onTap: () {
                      _openPage(
                        context,
                        const AddDriverPage(),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.08,
              children: [
                _ManagementCard(
                  icon:
                      Icons.directions_car_outlined,
                  title: 'Vehicles',
                  subtitle:
                      'Manage vehicles',
                  onTap: () {
                    _openPage(
                      context,
                      const VehicleListPage(),
                    );
                  },
                ),
                _ManagementCard(
                  icon: Icons.people_outline,
                  title: 'Drivers',
                  subtitle:
                      'Manage drivers',
                  onTap: () {
                    _openPage(
                      context,
                      const DriverListPage(),
                    );
                  },
                ),
                _ManagementCard(
                  icon:
                      Icons.verified_user_outlined,
                  title: 'Driver KYC',
                  subtitle:
                      'Verify documents',
                  onTap: () {
                    _openPage(
                      context,
                      const DriverListPage(),
                    );
                  },
                ),
                _ManagementCard(
                  icon: Icons.route_outlined,
                  title: 'Trips',
                  subtitle:
                      'Booking requests',
                  onTap: () {
                    _openTrips(context);
                  },
                ),
                _ManagementCard(
                  icon:
                      Icons.local_shipping_outlined,
                  title: 'Cargo',
                  subtitle:
                      'Cargo trips',
                  onTap: () {
                    _comingSoon(
                      context,
                      'Cargo',
                    );
                  },
                ),
                _ManagementCard(
                  icon:
                      Icons.car_rental_outlined,
                  title: 'Rental',
                  subtitle:
                      'Rental trips',
                  onTap: () {
                    _comingSoon(
                      context,
                      'Rental',
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(
                        alpha: 0.15,
                      ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 30,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Manage your SafarRide business with ${AppConfig.companyName}.',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 30,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 38,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors
                      .grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerSupportPage
    extends StatelessWidget {
  const _PartnerSupportPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent,
              size: 70,
            ),
            SizedBox(height: 16),
            Text(
              'Partner Support',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Partner support and complaint management will be added in the next module.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}