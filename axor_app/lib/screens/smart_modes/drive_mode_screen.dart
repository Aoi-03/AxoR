import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/song_queue_table.dart';
import '../../utils/mode_manager.dart';

class DriveModeScreen extends StatefulWidget {
  const DriveModeScreen({super.key});

  @override
  State<DriveModeScreen> createState() => _DriveModeScreenState();
}

class _DriveModeScreenState extends State<DriveModeScreen> {
  final String _timerText = '00:00:00';
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  const Text(
                    'DRIVE MODE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Timer Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Timer Circle - centered
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.green,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _timerText,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'stopwatch',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.lightGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Mode Toggle - Top right corner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeToggle(
                              Icons.fitness_center, 
                              AppColors.red, 
                              false,
                              () {
                                // Switch to gym mode
                                modeManager.setMode(0);
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildModeToggle(
                              Icons.menu_book, 
                              AppColors.cyan, 
                              false,
                              () {
                                // Switch to study mode
                                modeManager.setMode(1);
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildModeToggle(
                              Icons.directions_car, 
                              AppColors.green, 
                              true,
                              () {
                                // Already in drive mode
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Start Drive Button
                  CustomButton(
                    text: 'START DRIVE',
                    onPressed: () {
                      setState(() {
                        _isRunning = !_isRunning;
                      });
                      // Start/stop timer logic here
                    },
                    gradient: AppColors.greenGradient,
                  ),
                  const SizedBox(height: 40),
                  
                  // Song Queue
                  const SongQueueTable(),
                  const SizedBox(height: 100), // Space for bottom player and nav bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(IconData icon, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? Border.all(color: color, width: 1) : null,
        ),
        child: Icon(
          icon,
          color: isActive ? color : AppColors.lightGray,
          size: 18,
        ),
      ),
    );
  }
}
