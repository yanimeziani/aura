const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "aura-lynx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run aura-lynx");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_step = b.step("test", "Run aura-lynx unit tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // Mobile (Android) build step
    const android_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .android,
    });
    const android_exe = b.addExecutable(.{
        .name = "aura-lynx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = android_target,
            .optimize = optimize,
        }),
    });
    const android_install = b.addInstallArtifact(android_exe, .{
        .dest_dir = .{ .override = .{ .custom = "mobile" } },
    });
    const mobile_step = b.step("mobile", "Build aura-lynx for Android (aarch64-linux-android)");
    mobile_step.dependOn(&android_install.step);
}
