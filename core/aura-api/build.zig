const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "aura-api",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run aura-api (VPS API server)");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/sessions.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_step = b.step("test", "Run aura-api tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // smoke — build then run smoke_test.sh against a live server
    const smoke_step = b.step("smoke", "Run aura-api HTTP smoke tests (smoke_test.sh)");
    const smoke_run = b.addSystemCommand(&.{ "bash", "smoke_test.sh" });
    smoke_run.step.dependOn(b.getInstallStep());
    smoke_step.dependOn(&smoke_run.step);
}
