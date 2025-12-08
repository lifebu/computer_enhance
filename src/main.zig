const std = @import("std");
const computer_enhance = @import("computer_enhance");
const Decoder = @import("sim86/Decoder.zig");
const Instruction = @import("sim86/Instruction.zig");

const sim86 = @import("sim86/main.zig");
const haversine = @import("haversine/main.zig");

const project_sim86 = "sim86";
const project_haversine = "sim86";
const project = project_sim86;

pub fn main() !void {
    if (project == project_sim86) {
        try sim86.main();
    } else if (project == project_haversine) {
        try haversine.main();
    } else {
        std.debug.print("NO PROJECT LOADED???\n", .{});
    }
}