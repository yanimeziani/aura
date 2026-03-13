const std = @import("std");
const crypto = @import("crypto.zig");

/// Encrypted Local Cloud Storage (Chunking & Redundancy)
/// Integrates with the Aura Mesh (aura-tailscale) for Layer 0 distributed storage.

pub const ChunkStore = struct {
    allocator: std.mem.Allocator,
    storage_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, dir: []const u8) ChunkStore {
        return .{
            .allocator = allocator,
            .storage_dir = dir,
        };
    }

    /// Stores a chunk of data redundantly, encrypting it before writing to disk
    /// In a full implementation, this also gossips the chunk over the Aura Mesh
    pub fn storeEncryptedChunk(self: *ChunkStore, key: crypto.VaultStorageCrypto.Key, chunk_id: []const u8, data: []const u8) !void {
        var nonce = [_]u8{0} ** 12; // In production, generate securely or derive from chunk hash
        std.crypto.random.bytes(&nonce);

        const encrypted = try crypto.VaultStorageCrypto.encryptChunk(self.allocator, key, nonce, data, chunk_id);
        defer self.allocator.free(encrypted.ciphertext);

        // Write to local layer 0 disk
        // A production implementation would distribute via aura-tailscale mesh nodes here
        var dir = try std.fs.cwd().makeOpenPath(self.storage_dir, .{});
        defer dir.close();

        // Write chunk header (nonce + tag) followed by ciphertext
        const filename = try std.fmt.allocPrint(self.allocator, "{s}.aura", .{chunk_id});
        defer self.allocator.free(filename);

        var file = try dir.createFile(filename, .{});
        defer file.close();

        try file.writeAll(&nonce);
        try file.writeAll(&encrypted.tag);
        try file.writeAll(encrypted.ciphertext);
    }
};

test "chunk store basic integration" {
    const allocator = std.testing.allocator;
    var store = ChunkStore.init(allocator, "var/aura_test_vault");
    
    // Ensure test directory is clean
    std.fs.cwd().deleteTree("var/aura_test_vault") catch {};

    const key = [_]u8{0x99} ** 32;
    const chunk_id = "test_chunk_001";
    const data = "This is a strictly rigorous zero-trust layer 0 chunk.";

    try store.storeEncryptedChunk(key, chunk_id, data);
    
    // Cleanup
    try std.fs.cwd().deleteTree("var/aura_test_vault");
}