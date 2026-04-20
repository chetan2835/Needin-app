// ══════════════════════════════════════════════════════════════
//  NEEDIN EXPRESS — Premium Pricing Display Card v3.0
//  Beautiful, animated, fully responsive pricing card
//  Shows real backend prices, breakdown, ETR, and size comparison
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/pricing_slabs.dart';
import '../models/pricing_result.dart';
import '../services/pricing_engine.dart';

class PricingDisplayCard extends StatefulWidget {
  final PricingResult? pricing;
  final bool isLoading;
  final Map<ParcelSize, PricingResult>? allSizePrices;
  final ParcelSize selectedSize;
  final ValueChanged<ParcelSize>? onSizeChanged;

  const PricingDisplayCard({
    super.key,
    required this.pricing,
    this.isLoading = false,
    this.allSizePrices,
    this.selectedSize = ParcelSize.medium,
    this.onSizeChanged,
  });

  @override
  State<PricingDisplayCard> createState() => _PricingDisplayCardState();
}

class _PricingDisplayCardState extends State<PricingDisplayCard>
    with SingleTickerProviderStateMixin {
  bool _showBreakdown = false;
  late AnimationController _priceAnimController;
  late Animation<double> _priceAnimation;
  int _displayedPrice = 0;

  @override
  void initState() {
    super.initState();
    _priceAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _priceAnimation = CurvedAnimation(
      parent: _priceAnimController,
      curve: Curves.easeOutCubic,
    );

    if (widget.pricing != null && widget.pricing!.price > 0) {
      _displayedPrice = widget.pricing!.price;
      _priceAnimController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PricingDisplayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pricing != null &&
        widget.pricing!.price != oldWidget.pricing?.price) {
      _animatePrice(oldWidget.pricing?.price ?? 0, widget.pricing!.price);
    }
  }

  void _animatePrice(int from, int to) {
    _priceAnimController.reset();
    _priceAnimController.addListener(() {
      setState(() {
        _displayedPrice = (from + (to - from) * _priceAnimation.value).round();
      });
    });
    _priceAnimController.forward();
  }

  @override
  void dispose() {
    _priceAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _buildLoadingState();

    final pricing = widget.pricing;
    if (pricing == null || !pricing.isSuccess) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF27F0D).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── PRICE HEADER ───────────────────────────────────
          _buildPriceHeader(pricing),

          // ── SIZE SELECTOR (Optional) ───────────────────────
          if (widget.allSizePrices != null && widget.onSizeChanged != null)
            _buildSizeSelector(),

          // ── ROUTE INFO CHIPS ───────────────────────────────
          _buildRouteInfoChips(pricing),

          // ── ETR INFO ───────────────────────────────────────
          if (pricing.etrText.isNotEmpty && pricing.pricingType != PricingType.flight)
            _buildETRInfo(pricing),

          // ── BREAKDOWN TOGGLE ───────────────────────────────
          _buildBreakdownSection(pricing),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PRICE HEADER
  // ══════════════════════════════════════════════════════════════

  Widget _buildPriceHeader(PricingResult pricing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFFBF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price badge type
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _pricingTypeColor(pricing.pricingType).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pricing.pricingTypeLabel,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _pricingTypeColor(pricing.pricingType),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Estimated Fare',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Big price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$_displayedPrice',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pricing.parcelSizeLabel.isNotEmpty
                    ? '${pricing.parcelSizeLabel[0].toUpperCase()}${pricing.parcelSizeLabel.substring(1)} Parcel'
                    : '',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SIZE SELECTOR
  // ══════════════════════════════════════════════════════════════

  Widget _buildSizeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ParcelSize.values.map((size) {
          final isSelected = size == widget.selectedSize;
          final price = widget.allSizePrices?[size]?.price;
          final sizeLabel = size == ParcelSize.small ? 'S'
              : size == ParcelSize.medium ? 'M' : 'L';
          final fullLabel = size == ParcelSize.small ? 'Small'
              : size == ParcelSize.medium ? 'Medium' : 'Large';

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSizeChanged?.call(size);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF27F0D).withValues(alpha: 0.1)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFF27F0D)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF27F0D)
                            : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sizeLabel,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fullLabel,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFFF27F0D)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '₹$price',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ROUTE INFO CHIPS
  // ══════════════════════════════════════════════════════════════

  Widget _buildRouteInfoChips(PricingResult pricing) {
    final chips = <_ChipData>[];

    if (pricing.distanceKm > 0) {
      chips.add(_ChipData(
        icon: Icons.straighten,
        label: '${pricing.distanceKm.toStringAsFixed(1)} km',
      ));
    }
    if (pricing.duration.isNotEmpty && pricing.duration != 'N/A (Flight)') {
      chips.add(_ChipData(
        icon: Icons.schedule,
        label: pricing.duration,
      ));
    }
    if (pricing.travelModeLabel.isNotEmpty) {
      chips.add(_ChipData(
        icon: _modeIcon(pricing.travelModeLabel),
        label: pricing.travelModeLabel[0].toUpperCase() +
            pricing.travelModeLabel.substring(1),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips.map((chip) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip.icon, size: 14, color: const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  chip.label,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ETR INFO
  // ══════════════════════════════════════════════════════════════

  Widget _buildETRInfo(PricingResult pricing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF16A34A)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: Color(0xFF166534),
                    height: 1.3,
                  ),
                  children: [
                    const TextSpan(text: 'ETR: '),
                    TextSpan(
                      text: pricing.etrText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' (incl. 10% grace)'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BREAKDOWN SECTION
  // ══════════════════════════════════════════════════════════════

  Widget _buildBreakdownSection(PricingResult pricing) {
    return Column(
      children: [
        // Toggle button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showBreakdown = !_showBreakdown);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: const Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showBreakdown ? 'Hide Breakdown' : 'View Breakdown',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF27F0D),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _showBreakdown ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Color(0xFFF27F0D),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expandable breakdown
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildBreakdownDetails(pricing.breakdown),
          crossFadeState: _showBreakdown
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildBreakdownDetails(PricingBreakdown breakdown) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          _buildBreakdownRow('Base Price', '₹${breakdown.basePrice}'),
          if (breakdown.slabRange.isNotEmpty)
            _buildBreakdownRow('Slab Range', breakdown.slabRange),
          _buildBreakdownRow('Time Multiplier', '×${breakdown.timeMultiplier}'),
          if (breakdown.timePerformanceLabel.isNotEmpty)
            _buildBreakdownRow('Performance', breakdown.timePerformanceLabel),
          if (breakdown.routeType.isNotEmpty)
            _buildBreakdownRow('Route Type', breakdown.routeType),
          const Divider(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFFF27F0D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    breakdown.finalReason,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LOADING STATE
  // ══════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFF27F0D),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Calculating fare...',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  UTILITIES
  // ══════════════════════════════════════════════════════════════

  Color _pricingTypeColor(PricingType type) {
    switch (type) {
      case PricingType.sameCity: return const Color(0xFF16A34A);
      case PricingType.slab: return const Color(0xFF2563EB);
      case PricingType.flight: return const Color(0xFF7C3AED);
    }
  }

  IconData _modeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'flight': return Icons.flight;
      case 'train': return Icons.train;
      case 'bus': return Icons.directions_bus;
      case 'bike': return Icons.two_wheeler;
      default: return Icons.directions_car;
    }
  }
}

class _ChipData {
  final IconData icon;
  final String label;
  _ChipData({required this.icon, required this.label});
}
