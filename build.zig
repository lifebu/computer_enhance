const std = @import("std");
const builtin = @import("builtin");

const Project = enum { sim86, haversine };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // llvm backend required for vscode debug symbols and performance is bad with self-hosted backend.
    const enable_llvm = b.option(bool, "enable_llvm", "Enable llvm backed to allow debug symbols in vscode") orelse false;
    const project = b.option(Project, "project", "Which project to build") orelse .haversine;

    // haversine
    const exe = b.addExecutable(.{
        .name = "computer_enhance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = enable_llvm,
    });
    b.installArtifact(exe);

    const exe_options = b.addOptions();
    exe_options.addOption(Project, "project", project);
    exe.root_module.addOptions("build", exe_options);

    // run
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // tests
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
