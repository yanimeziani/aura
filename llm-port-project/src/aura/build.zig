// Aura workspace: default lib and LSP build root.
// All Zig packages are dependencies; running `zig build` from repo root builds
// the full graph so zls (and other LSP/tooling) can resolve Aura modules.
// Zig 0.15.2 only — see docs/ZIG_VERSION.md and .zig-version.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const aura_vault_dep = b.dependency("aura_vault", .{ .target = target, .optimize = optimize });
    const aura_edge_dep = b.dependency("aura_edge", .{ .target = target, .optimize = optimize });
    const aura_api_dep = b.dependency("aura_api", .{ .target = target, .optimize = optimize });
    const aura_flow_dep = b.dependency("aura_flow", .{ .target = target, .optimize = optimize });
    const aura_lynx_dep = b.dependency("aura_lynx", .{ .target = target, .optimize = optimize });
    const aura_mcp_dep = b.dependency("aura_mcp", .{ .target = target, .optimize = optimize });
    const aura_tailscale_dep = b.dependency("aura_tailscale", .{ .target = target, .optimize = optimize });
    const tui_dep = b.dependency("tui", .{ .target = target, .optimize = optimize });
    const ziggy_compiler_dep = b.dependency("ziggy_compiler", .{ .target = target, .optimize = optimize });

    b.getInstallStep().dependOn(aura_vault_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(aura_edge_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(aura_api_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(aura_flow_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(aura_lynx_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(aura_mcp_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(aura_tailscale_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(tui_dep.builder.getInstallStep());
    b.getInstallStep().dependOn(ziggy_compiler_dep.builder.getInstallStep());
}
