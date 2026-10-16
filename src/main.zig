const std = @import("std");
const build = @import("build");

const sim86 = @import("sim86/main.zig");
const haversine = @import("haversine/main.zig");

pub fn main(init: std.process.Init) !void {
    switch (build.project) {
        .haversine => try haversine.main(init),
        .sim86 => try sim86.main(init),
    }
}
