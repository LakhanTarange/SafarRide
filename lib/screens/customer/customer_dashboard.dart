import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../profile/profile_page.dart';
import 'carpool_page.dart';
import 'cargo_booking_page.dart';
import 'my_bookings_page.dart';
import 'nearby_vehicles_page.dart';
import 'rental_booking_page.dart';
import 'travels_booking_page.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _CustomerHomePage(),
    MyBookingsPage(),
    _CustomerSupportPage(),
  ];

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications.')),
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}

class _CustomerHomePage extends StatelessWidget {
  const _CustomerHomePage();

  void _openNearbyVehicles(BuildContext context, {String type = 'All'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NearbyVehiclesPage(initialType: type),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    final String userName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'Customer';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $userName 👋',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              AppConfig.appTagline,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),

            const SizedBox(height: 24),

            _QuickBookingCard(
              icon: Icons.near_me,
              title: 'Nearby Vehicles',
              subtitle: 'Find available vehicles near you',
              onTap: () {
                _openNearbyVehicles(context);
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Our Services',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.08,
              children: [
                _ServiceCard(
                  icon: Icons.directions_car_outlined,
                  title: 'Car',
                  subtitle: 'Book a nearby car',
                  onTap: () {
                    _openNearbyVehicles(context, type: 'Car');
                  },
                ),

                _ServiceCard(
                  icon: Icons.two_wheeler,
                  title: 'Bike',
                  subtitle: 'Book a nearby bike',
                  onTap: () {
                    _openNearbyVehicles(context, type: 'Bike');
                  },
                ),

                _ServiceCard(
                  icon: Icons.local_taxi_outlined,
                  title: 'Auto',
                  subtitle: 'Book a nearby auto',
                  onTap: () {
                    _openNearbyVehicles(context, type: 'Auto');
                  },
                ),

                _ServiceCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Tempo',
                  subtitle: 'Goods transport',
                  onTap: () {
                    _openNearbyVehicles(context, type: 'Tempo');
                  },
                ),

                _ServiceCard(
                  icon: Icons.directions_bus_outlined,
                  title: 'Travels',
                  subtitle: 'Bus & traveller',
                  onTap: () {
                    _openPage(context, const TravelsBookingPage());
                  },
                ),

                _ServiceCard(
                  icon: Icons.groups_outlined,
                  title: 'Carpool',
                  subtitle: 'Share your journey',
                  onTap: () {
                    _openPage(context, const CarpoolPage());
                  },
                ),

                _ServiceCard(
                  icon: Icons.car_rental_outlined,
                  title: 'Rental',
                  subtitle: 'Rent a vehicle',
                  onTap: () {
                    _openPage(context, const RentalBookingPage());
                  },
                ),

                _ServiceCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Cargo',
                  subtitle: 'Move your goods',
                  onTap: () {
                    _openPage(context, const CargoBookingPage());
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Travel with convenience through ${AppConfig.appName}.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

class _QuickBookingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickBookingCard({
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
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(radius: 30, child: Icon(icon, size: 30)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ServiceCard({
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
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerSupportPage extends StatelessWidget {
  const _CustomerSupportPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent, size: 70),
            SizedBox(height: 16),
            Text(
              'Customer Support',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Support and complaint management will be added in the next module.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
