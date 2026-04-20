export function classifyParcel(
  length: number,
  width: number,
  height: number,
  weight: number
): { category: string; isValid: boolean; reason?: string } {
  const maxDim = Math.max(length, width, height);

  // INVALID CONDITION
  if (maxDim > 60 || weight > 30) {
    throw new Error("Parcel exceeds allowed limits");
  }

  // MICRO
  if (maxDim <= 12 && weight <= 1) {
    return { category: "MICRO", isValid: true };
  }

  // SMALL
  if (maxDim <= 24 && weight <= 5) {
    return { category: "SMALL", isValid: true };
  }

  // MEDIUM
  if (maxDim <= 36 && weight <= 15) {
    return { category: "MEDIUM", isValid: true };
  }

  // LARGE
  if (maxDim <= 60 && weight <= 30) {
    return { category: "LARGE", isValid: true };
  }

  throw new Error("Parcel exceeds allowed limits");
}
