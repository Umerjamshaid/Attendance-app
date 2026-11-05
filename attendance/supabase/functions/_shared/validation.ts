export class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}

/** Returns trimmed nonempty text satisfying its length and optional format limits. */
export function text(value: unknown, max: number, pattern?: RegExp): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max || (pattern && !pattern.test(value))) throw new ApiError(400, 'invalid_input');
  return value.trim();
}
/** Validates a versioned UUID and normalizes its hexadecimal casing. */
export function uuid(value: unknown): string {
  return text(value, 36, /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i).toLowerCase();
}
/** Accepts only finite numeric values inside the inclusive geographic/accuracy bounds. */
export function coordinate(value: unknown, minimum: number, maximum: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < minimum || value > maximum) throw new ApiError(400, 'invalid_input');
  return value;
}
/** Decodes a bounded base64 JPEG/PNG payload and checks its file signature. */
export function image(value: unknown): { bytes: Uint8Array; contentType: string } {
  const encoded = text(value, 2_796_204);
  let binary: string;
  try { binary = atob(encoded); } catch { throw new ApiError(400, 'invalid_image'); }
  if (binary.length < 12 || binary.length > 2_097_152) throw new ApiError(400, 'invalid_image');
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  const png = [137,80,78,71,13,10,26,10].every((byte, i) => bytes[i] === byte);
  const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 && bytes.at(-2) === 255 && bytes.at(-1) === 217;
  if (!png && !jpeg) throw new ApiError(400, 'invalid_image');
  return { bytes, contentType: png ? 'image/png' : 'image/jpeg' };
}
