const std = @import("std");

// earth_radius expected to be 6372.8
pub fn referenceHaversine(x0: f64, y0: f64, x1: f64, y1: f64, earth_radius: f64) f64 {
    const lat_delta: f64 = std.math.degreesToRadians(y1 - y0);
    const lon_delta: f64 = std.math.degreesToRadians(x1 - x0);
    const lat1_rad: f64 = std.math.degreesToRadians(y0);
    const lat2_rad: f64 = std.math.degreesToRadians(y1);

    const a: f64 = std.math.pow(f64, std.math.sin(lat_delta / 2.0), 2.0);
    const b: f64 = std.math.pow(f64, std.math.sin(lon_delta / 2.0), 2.0);
    const c: f64 = a + (std.math.cos(lat1_rad) * std.math.cos(lat2_rad) * b);
    const d: f64 = 2.0 * std.math.asin(std.math.sqrt(c));

    const result: f64 = earth_radius * d;
    return result;
}
