/// Note: This is basically stolen from casey, I need the same rng as him for validating the output. 
/// Could move to std.Random outside of testing purposes.

const std = @import("std");
const Self = @This();

a: u64, b: u64, c: u64, d: u64,

pub fn init(seed: u64) Self {
    var result: Self = .{ 
        .a = 0xf1ea5eed, .b = seed, .c = seed, .d = seed 
    };
    for(0..20) |_| {
        _ = result.genU64();
    }
    return result;
}

fn rotateLeft(value: u64, shift: u6) u64 {
    const upper: u64 = value << shift;
    const lower: u64 = value >> @intCast(64 - @as(u7, shift));
    return upper | lower;
}
fn genU64(self: *Self) u64 {
    const e: u64 = self.a -% rotateLeft(self.b, 27);
    self.a = self.b ^ rotateLeft(self.c, 17);
    self.b = self.c +% self.d;
    self.c = self.d +% e;
    self.d = e +% self.a;
    return self.d;
}

pub fn genRange(self: *Self, min: f64, max: f64) f64 {
    const val: f64 = @floatFromInt(self.genU64());
    const gen_max: f64 = @floatFromInt(std.math.maxInt(u64));
    const t: f64 = val / gen_max;
    return std.math.lerp(min, max, t);
}
pub fn genDegree(self: *Self, center: f64, radius: f64, range: f64) f64 {
    const diff_min: f64 = center - radius;
    const min: f64 = if(diff_min < -range) -range else diff_min;

    const diff_max: f64 = center + radius;
    const max: f64 = if(diff_max > range) range else diff_max;

    return self.genRange(min, max);
}
