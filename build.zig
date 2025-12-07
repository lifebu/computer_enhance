const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // module
    const mod = b.addModule("computer_enhance", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // exe
    const exe = b.addExecutable(.{
        .name = "computer_enhance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "computer_enhance", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    // llvm backend required for vscode debug symbols.
    const enable_llvm = b.option(bool, "enable-llvm", "Enable llvm backed to allow debug symbols in vscode") orelse false;
    exe.use_llvm = enable_llvm;

    // run
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
