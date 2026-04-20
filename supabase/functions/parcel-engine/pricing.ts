export const pricingConfig = {
  "same-city": {
    MICRO: 49,
    SMALL: 79,
    MEDIUM: 129,
    LARGE: 199
  },
  "city-to-city": {
    MICRO: { base: 49, perKM: 2 },
    SMALL: { base: 79, perKM: 3 },
    MEDIUM: { base: 129, perKM: 5 },
    LARGE: { base: 199, perKM: 7 }
  }
};

export function roundPrice(price: number): number {
  if (price < 0) return price; // Optional safety
  const base = Math.floor(price / 100) * 100;
  const remainder = Math.round(price % 100);

  if (remainder === 49 || remainder === 99) return price;
  
  if (remainder <= 49) {
    return base + 49;
  } else {
    return base + 99;
  }
}

export function calculatePrice(
  distanceKM: number,
  parcelCategory: "MICRO" | "SMALL" | "MEDIUM" | "LARGE",
  routeType: "same-city" | "city-to-city"
) {
  let basePrice = 0;
  let distanceCost = 0;
  let finalPrice = 0;

  if (routeType === "same-city") {
    const fixedPrice = pricingConfig["same-city"][parcelCategory];
    basePrice = fixedPrice;
    distanceCost = 0;
    finalPrice = fixedPrice;
  } else if (routeType === "city-to-city") {
    const config = pricingConfig["city-to-city"][parcelCategory];
    basePrice = config.base;
    distanceCost = distanceKM * config.perKM;
    finalPrice = basePrice + distanceCost;
  } else {
    throw new Error("Invalid route type");
  }

  const rounded = roundPrice(finalPrice);

  return {
    basePrice,
    distanceCost,
    finalPrice,
    roundedPrice: rounded,
    category: parcelCategory
  };
}
