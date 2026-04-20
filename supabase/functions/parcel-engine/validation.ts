// Validation Layer

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export function validateDimensionsAndWeight(
  length: number,
  width: number,
  height: number,
  weight: number
) {
  if (
    typeof length !== "number" ||
    typeof width !== "number" ||
    typeof height !== "number" ||
    typeof weight !== "number"
  ) {
    throw new ValidationError("Missing or invalid fields. Dimensions and weight must be numbers.");
  }

  if (length <= 0 || width <= 0 || height <= 0 || weight <= 0) {
    throw new ValidationError("Dimensions and weight must be greater than zero.");
  }
}

export function validatePricingPayload(
  fromCity: string,
  toCity: string,
  distanceKM: number,
  parcelCategory: string,
  routeType: string
) {
  if (!fromCity || !toCity || typeof fromCity !== "string" || typeof toCity !== "string") {
    throw new ValidationError("Invalid or missing cities.");
  }
  if (typeof distanceKM !== "number" || distanceKM < 0) {
    throw new ValidationError("Invalid distance.");
  }
  const validCategories = ["MICRO", "SMALL", "MEDIUM", "LARGE"];
  if (!validCategories.includes(parcelCategory)) {
    throw new ValidationError("Invalid parcel category.");
  }
  if (routeType !== "same-city" && routeType !== "city-to-city") {
    throw new ValidationError("Invalid routeType. Expected same-city or city-to-city.");
  }
}

export function sanitizeInput(input: any) {
  // basic sanitization
  if (!input || typeof input !== "object") return input;
  const sanitized = { ...input };
  for (const key in sanitized) {
    if (typeof sanitized[key] === "string") {
      sanitized[key] = sanitized[key].trim().replace(/[<>]/g, ""); // prevent basic injection
    }
  }
  return sanitized;
}
