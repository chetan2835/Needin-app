export interface Route {
  from: string;
  to: string;
}

export interface TravelerRoute extends Route {
  via: string[];
}

export interface Traveler {
  id: string;
  name: string;
  maxWeight: number;
  allowedCategories: string[];
  route: TravelerRoute;
  rating: number; // 0 to 5
  eta: Date; // Faster ETA means smaller date
  priceQuote?: number; // Optional, dynamically calculated if not provided
}

export function searchTravelers(
  parcelCategory: string,
  parcelWeight: number,
  senderRoute: Route,
  travelerList: Traveler[]
): Traveler[] {
  // 1. FILTERING
  const matches = travelerList.filter((traveler) => {
    // Condition 1: weight
    if (parcelWeight > traveler.maxWeight) return false;

    // Condition 2: category
    if (!traveler.allowedCategories.includes(parcelCategory)) return false;

    // Condition 3: route mapping
    // We check if it satisfies direct (from -> to) OR if the 'to' or 'from' corresponds with 'via'.
    // A simplified match: the travel must start at 'senderRoute.from' (or pass via) and end at 'senderRoute.to' (or pass via).
    const isDirectMatch =
      traveler.route.from.toLowerCase() === senderRoute.from.toLowerCase() &&
      traveler.route.to.toLowerCase() === senderRoute.to.toLowerCase();

    // Partial match if via logic is present
    const includesFrom =
      traveler.route.from.toLowerCase() === senderRoute.from.toLowerCase() ||
      traveler.route.via.map(v => v.toLowerCase()).includes(senderRoute.from.toLowerCase());

    const includesTo =
      traveler.route.to.toLowerCase() === senderRoute.to.toLowerCase() ||
      traveler.route.via.map(v => v.toLowerCase()).includes(senderRoute.to.toLowerCase());

    // We make sure they go in the right order but for simplicity here we just check presence
    if (!(isDirectMatch || (includesFrom && includesTo))) return false;

    return true;
  });

  // 2. SORTING
  // Priority: Lowest Price > Highest Rating > Fastest ETA
  return matches.sort((a, b) => {
    const aPrice = a.priceQuote || 0;
    const bPrice = b.priceQuote || 0;

    // Logic 1: Lowest Price
    if (aPrice !== bPrice) {
      return aPrice - bPrice; 
    }

    // Logic 2: Highest Rating
    if (a.rating !== b.rating) {
      return b.rating - a.rating; 
    }

    // Logic 3: Fastest ETA (lowest Date value)
    const aTime = a.eta.getTime ? a.eta.getTime() : new Date(a.eta).getTime();
    const bTime = b.eta.getTime ? b.eta.getTime() : new Date(b.eta).getTime();
    return aTime - bTime;
  });
}
