const std = @import("std");

/// Aura Vault Cryptography Layer
/// No external dependencies, strict Zig 0.15.2 std.crypto usage.

pub const VaultCrypto = struct {
    pub const KeyPair = std.crypto.sign.Ed25519.KeyPair;
    pub const SecretKey = std.crypto.sign.Ed25519.SecretKey;
    pub const PublicKey = std.crypto.sign.Ed25519.PublicKey;
    pub const Signature = std.crypto.sign.Ed25519.Signature;

    /// Generate a fresh Ed25519 keypair for the cold wallet
    pub fn generateKeyPair() !KeyPair {
        var seed: [std.crypto.sign.Ed25519.SecretKey.seed_length]u8 = undefined;
        std.crypto.random.bytes(&seed);
        return KeyPair.create(seed) catch return error.KeyGenerationFailed;
    }

    /// Sign a message using the cold wallet's private key
    pub fn sign(key_pair: KeyPair, msg: []const u8) !Signature {
        return std.crypto.sign.Ed25519.sign(msg, key_pair, undefined) catch return error.SigningFailed;
    }

    /// Verify a signature
    pub fn verify(public_key: PublicKey, msg: []const u8, sig: Signature) !void {
        return std.crypto.sign.Ed25519.verify(sig, msg, public_key) catch return error.SignatureVerificationFailed;
    }
};

pub const VaultStorageCrypto = struct {
    pub const Key = [32]u8;
    pub const Nonce = [12]u8;
    pub const Tag = [16]u8;
    
    /// Encrypt a chunk of data intended for local cloud redundant storage
    pub fn encryptChunk(allocator: std.mem.Allocator, key: Key, nonce: Nonce, plaintext: []const u8, ad: []const u8) !struct { ciphertext: []u8, tag: Tag } {
        var ciphertext = try allocator.alloc(u8, plaintext.len);
        var tag: Tag = undefined;
        
        std.crypto.aead.chacha20.ChaCha20Poly1305.encrypt(ciphertext, &tag, plaintext, ad, nonce, key);
        return .{ .ciphertext = ciphertext, .tag = tag };
    }

    /// Decrypt a chunk of data
    pub fn decryptChunk(allocator: std.mem.Allocator, key: Key, nonce: Nonce, ciphertext: []const u8, tag: Tag, ad: []const u8) ![]u8 {
        var plaintext = try allocator.alloc(u8, ciphertext.len);
        std.crypto.aead.chacha20.ChaCha20Poly1305.decrypt(plaintext, ciphertext, tag, ad, nonce, key) catch return error.DecryptionFailed;
        return plaintext;
    }
};

test "wallet key generation and signing" {
    const kp = try VaultCrypto.generateKeyPair();
    const msg = "send 100 sats";
    const sig = try VaultCrypto.sign(kp, msg);
    try VaultCrypto.verify(kp.public_key, msg, sig);
}

test "storage chunk encryption and decryption" {
    const allocator = std.testing.allocator;
    const key = [_]u8{0x42} ** 32;
    const nonce = [_]u8{0x01} ** 12;
    const plaintext = "confidential backup data";
    const ad = "chunk_id_001";

    const encrypted = try VaultStorageCrypto.encryptChunk(allocator, key, nonce, plaintext, ad);
    defer allocator.free(encrypted.ciphertext);

    const decrypted = try VaultStorageCrypto.decryptChunk(allocator, key, nonce, encrypted.ciphertext, encrypted.tag, ad);
    defer allocator.free(decrypted);

    try std.testing.expectEqualStrings(plaintext, decrypted);
}