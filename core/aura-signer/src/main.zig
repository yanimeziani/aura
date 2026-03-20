const std = @import("std");

pub fn main() !void {
    // 1. Initialize Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 2. Parse Command Line Arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: aura-signer <path-to-artwork>\n", .{});
        std.debug.print("Error: Digital canvas not provided.\n", .{});
        std.process.exit(1);
    }

    const file_path = args[1];

    // 3. Read the Artwork
    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        std.debug.print("Failed to open file: {}\n", .{err});
        std.process.exit(1);
    };
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    // 4. Compute Provenance Fingerprint (SHA-256)
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(buffer, &hash, .{});

    // 5. Output the Sovereign Asset Data
    std.debug.print("=== AURA SOVEREIGN SIGNER ===\n", .{});
    std.debug.print("Target: {s}\n", .{file_path});
    std.debug.print("Size: {} bytes\n", .{file_size});
    
    std.debug.print("Provenance Fingerprint (SHA-256): ", .{});
    for (hash) |b| {
        std.debug.print("{x:0>2}", .{b});
    }
    std.debug.print("\n", .{});
    
    std.debug.print("[*] Ready for hardware-gated ML-KEM signature.\n", .{});
}
