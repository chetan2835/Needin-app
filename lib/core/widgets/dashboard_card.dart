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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 280,
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
                  size: 200,
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
                          size: 32,
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
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: titleColor,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Responsiveness fix: Use Flexible or constrained box instead of absolute width
                  Flexible(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: descriptionColor,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: buttonTextColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
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
    );
  }
}
