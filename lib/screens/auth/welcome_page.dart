import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),

              // Brand icon
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.20),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                AppConfig.appTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE7EBF2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      size: 19,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ride • Rent • Share • Move',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF2563EB),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create an account',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              Text(
                'Powered by ${AppConfig.companyName}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}