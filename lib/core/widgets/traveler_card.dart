import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TravelerCard extends StatelessWidget {
  final String name;
  final String rating;
  final String imgUrl;
  final String origin;
  final String destination;
  final String capacity;

  const TravelerCard({
    super.key,
    required this.name,
    required this.rating,
    required this.imgUrl,
    required this.origin,
    required this.destination,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE2E8F0),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    width: 40,
                    height: 40,
                    placeholder: (context, url) => Container(color: const Color(0xFFF1F5F9)),
                    errorWidget: (context, url, error) => const Icon(Icons.person, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: "Plus Jakarta Sans",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFEAB308), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontFamily: "Plus Jakarta Sans",
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Icon(Icons.flight_takeoff, color: Color(0xFFF27F0D), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  origin,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flight_land, color: Color(0xFFF27F0D), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destination,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Available Space:",
                  style: TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  capacity,
                  style: const TextStyle(
                    fontFamily: "Plus Jakarta Sans",
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
