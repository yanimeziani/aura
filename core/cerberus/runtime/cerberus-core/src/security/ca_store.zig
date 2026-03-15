const std = @import("std");

pub const SYSTEM_CA_PATHS = [_][]const u8{
    "/etc/ssl/certs/ca-certificates.crt",
    "/etc/pki/tls/certs/ca-bundle.crt",
    "/etc/ssl/ca-bundle.pem",
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
    "/etc/ssl/cert.pem",
};

pub fn findSystemCaPath() ?[]const u8 {
    for (SYSTEM_CA_PATHS) |path| {
        std.fs.accessAbsolute(path, .{}) catch continue;
        return path;
    }
    return null;
}

pub fn initBundle(allocator: std.mem.Allocator) !std.crypto.Certificate.Bundle {
    var bundle = std.crypto.Certificate.Bundle{};
    // Standard discovery
    bundle.rescan(allocator) catch {
        if (findSystemCaPath()) |path| {
            try bundle.addCertsFromFilePathAbsolute(allocator, path);
        }
    };
    return bundle;
}
