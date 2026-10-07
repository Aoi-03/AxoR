import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/song_queue_table.dart';
import '../../utils/mode_manager.dart';

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen> {
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
                    'STUDY MODE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
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
                            color: AppColors.cyan,
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
                          color: AppColors.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.cyan.withValues(alpha: 0.3),
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
                              true,
                              () {
                                // Already in study mode
                              },
                            ),
                            const SizedBox(width: 6),
                            _buildModeToggle(
                              Icons.directions_car, 
                              AppColors.green, 
                              false,
                              () {
                                // Switch to drive mode
                                modeManager.setMode(2);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Start Study Button
                  CustomButton(
                    text: 'START STUDY',
                    onPressed: () {
                      setState(() {
                        _isRunning = !_isRunning;
                      });
                      // Start/stop timer logic here
                    },
                    gradient: AppColors.cyanGradient,
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
