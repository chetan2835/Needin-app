import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final Color backgroundColor;
  final IconData bgIcon;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String description;
  final Color descriptionColor;
  final String buttonText;
  final Color buttonBgColor;
  final Color buttonTextColor;
  final Color? buttonBorderColor;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.backgroundColor,
    required this.bgIcon,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.description,
    required this.descriptionColor,
    required this.buttonText,
    required this.buttonBgColor,
    required this.buttonTextColor,
    this.buttonBorderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        // Using a more square aspect ratio like 16/14 to match the design cleanly 
        // while remaining fully responsive across devices.
        aspectRatio: 16 / 14,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Background Icon
              Positioned(
                right: -30,
                bottom: -40,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(
                    bgIcon,
                    size: screenWidth * 0.45,
                    color: Colors.white,
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Icon(
                            icon,
                            color: iconColor,
                            size: screenWidth * 0.08,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_outward,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: screenWidth * 0.06, // Responsive scaling
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: titleColor,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Flexible(
                      child: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: screenWidth * 0.035, // Responsive scaling
                          fontWeight: FontWeight.w500,
                          color: descriptionColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: buttonBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: buttonBorderColor != null ? Border.all(color: buttonBorderColor!) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            buttonText,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.bold,
                              color: buttonTextColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: screenWidth * 0.04,
                            color: buttonTextColor,
                          ),
                        ],
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
