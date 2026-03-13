const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_model = .{ .explicit = &std.Target.Cpu.Model{ .name = "generic" } },
            .os_tag = .linux,
            .abi = .gnu,
            .arch = .aarch64,
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "pegasus_shell",
        .target = target,
        .root_source_file = b.path("src/main.zig"),
    });

    lib.linkLibC();

    b.installArtifact(lib);
}
