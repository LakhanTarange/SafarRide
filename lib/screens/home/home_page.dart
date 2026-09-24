import 'package:flutter/material.dart';

import '../../config/app_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedService = 0;

  final List<ServiceItem> services = const [
    ServiceItem(
      title: 'Car',
      subtitle: 'Comfort rides',
      icon: Icons.directions_car_rounded,
    ),
    ServiceItem(
      title: 'Bike',
      subtitle: 'Quick & easy',
      icon: Icons.two_wheeler_rounded,
    ),
    ServiceItem(
      title: 'Auto',
      subtitle: 'City rides',
      icon: Icons.electric_rickshaw_rounded,
    ),
    ServiceItem(
      title: 'Travels',
      subtitle: 'Outstation',
      icon: Icons.directions_bus_rounded,
    ),
    ServiceItem(
      title: 'Cargo',
      subtitle: 'Move goods',
      icon: Icons.local_shipping_rounded,
    ),
    ServiceItem(
      title: 'Carpool',
      subtitle: 'Share a ride',
      icon: Icons.people_alt_rounded,
    ),
    ServiceItem(
      title: 'Rental',
      subtitle: 'Rent a vehicle',
      icon: Icons.key_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildBody(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      pinned: true,
      toolbarHeight: 72,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'Move freely',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(
            Icons.notifications_none_rounded,
            size: 27,
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFE8EEF9),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(),

          const SizedBox(height: 22),

          _buildBookingCard(),

          const SizedBox(height: 30),

          _buildSectionTitle(
            'Choose your ride',
            'Everything you need, in one place',
          ),

          const SizedBox(height: 15),

          _buildServices(),

          const SizedBox(height: 30),

          _buildPromoCard(),

          const SizedBox(height: 30),

          _buildSectionTitle(
            'Quick actions',
            'Plan your next journey faster',
          ),

          const SizedBox(height: 15),

          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Where are you going?',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          AppConfig.appTagline,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _locationField(
            icon: Icons.my_location_rounded,
            iconColor: const Color(0xFF2563EB),
            label: 'Pickup location',
            hint: 'Where should we pick you up?',
          ),

          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 25,
                width: 1,
                color: const Color(0xFFD9DEE8),
              ),
            ),
          ),

          _locationField(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFEF4444),
            label: 'Destination',
            hint: 'Where do you want to go?',
          ),

          const SizedBox(height: 17),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.search_rounded,
                size: 21,
              ),
              label: const Text(
                'Find a ride',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String hint,
  }) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'View all',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildServices() {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final service = services[index];
          final selected = selectedService == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedService = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 105,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2563EB)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE8ECF2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 43,
                    width: 43,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : const Color(0xFFF0F4FA),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      service.icon,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF2563EB),
                      size: 23,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    service.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF151922),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172554),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SAFARRIDE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'One app.\nEvery journey.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ride, rent, share or move.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 105,
            width: 105,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            icon: Icons.receipt_long_rounded,
            title: 'My bookings',
            subtitle: 'View trips',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickAction(
            icon: Icons.favorite_border_rounded,
            title: 'Saved places',
            subtitle: 'Your favourites',
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8ECF2),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FA),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      height: 72,
      selectedIndex: 0,
      backgroundColor: Colors.white,
      elevation: 8,
      onDestinationSelected: (index) {},
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.book_outlined),
          selectedIcon: Icon(Icons.book_rounded),
          label: 'Bookings',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}

class ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}