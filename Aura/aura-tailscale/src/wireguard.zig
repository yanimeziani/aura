//! WireGuard protocol — Noise_IK handshake skeleton. Zig 0.15.2 + std only.
//! Implements: constants, BLAKE2s primitives, Noise_IK initiation message.
//! Reference: WireGuard whitepaper §5 (Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s).

const std = @import("std");
const crypto = std.crypto;

// ── Protocol constants ────────────────────────────────────────────────────────

pub const CONSTRUCTION = "Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s";
pub const IDENTIFIER   = "WireGuard v1 zx2c4 Jason@zx2c4.com";
pub const LABEL_MAC1   = "mac1----";
pub const LABEL_COOKIE = "cookie--";
pub const KEY_SIZE       = 32;
pub const MAC_SIZE       = 16;
pub const TAG_SIZE       = 16;
pub const TIMESTAMP_SIZE = 12; // TAI64N

// ── Key types ─────────────────────────────────────────────────────────────────

pub const PrivateKey = [KEY_SIZE]u8;
pub const PublicKey  = [KEY_SIZE]u8;
pub const SymKey     = [KEY_SIZE]u8;
pub const HashVal    = [KEY_SIZE]u8;

pub const KeyPair = struct {
    private: PrivateKey,
    public:  PublicKey,

    /// Generate a fresh X25519 keypair using the system CSPRNG.
    pub fn generate() KeyPair {
        var kp: KeyPair = undefined;
        crypto.random.bytes(&kp.private);
        // Clamp per RFC 7748 §5
        kp.private[0]  &= 248;
        kp.private[31] &= 127;
        kp.private[31] |= 64;
        kp.public = crypto.dh.X25519.recoverPublicKey(kp.private) catch unreachable;
        return kp;
    }
};

// ── BLAKE2s primitives ────────────────────────────────────────────────────────

/// BLAKE2s-256 hash. Caller owns returned memory.
pub fn hash(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var buf: [KEY_SIZE]u8 = undefined;
    crypto.hash.blake2.Blake2s256.hash(input, &buf, .{});
    return allocator.dupe(u8, &buf);
}

/// BLAKE2s-256 hash into a stack buffer (no alloc).
pub fn hashInto(out: *HashVal, input: []const u8) void {
    crypto.hash.blake2.Blake2s256.hash(input, out, .{});
}

/// BLAKE2s-256 streaming hash of (a || b) → out.
pub fn hashConcat(out: *HashVal, a: []const u8, b: []const u8) void {
    var h = crypto.hash.blake2.Blake2s256.init(.{});
    h.update(a);
    h.update(b);
    h.final(out);
}

/// HMAC-BLAKE2s-256.
pub fn hmac(out: *HashVal, key: []const u8, data: []const u8) void {
    crypto.auth.hmac.Hmac(crypto.hash.blake2.Blake2s256).create(out, data, key);
}

/// HKDF-BLAKE2s-256: one key → two 32-byte outputs (T1, T2). Used by MixKey.
pub fn hkdf2(t1: *SymKey, t2: *SymKey, key: []const u8, input: []const u8) void {
    var prk: HashVal = undefined;
    hmac(&prk, key, input);
    hmac(t1, &prk, &[_]u8{0x01});
    var t2_input: [KEY_SIZE + 1]u8 = undefined;
    @memcpy(t2_input[0..KEY_SIZE], t1);
    t2_input[KEY_SIZE] = 0x02;
    hmac(t2, &prk, &t2_input);
}

// ── Noise_IK handshake state ──────────────────────────────────────────────────

/// Mutable Noise handshake state (initiator side).
pub const HandshakeState = struct {
    chaining_key: SymKey,
    hash_state:   HashVal,
    ephemeral:    KeyPair,

    /// Initialise state for Noise_IK initiation.
    pub fn init(their_static_pub: *const PublicKey) HandshakeState {
        // ck = HASH(CONSTRUCTION)
        var ck: SymKey = undefined;
        hashInto(&ck, CONSTRUCTION);

        // h = HASH(HASH(CONSTRUCTION) || IDENTIFIER)
        var h: HashVal = undefined;
        hashConcat(&h, &ck, IDENTIFIER);

        // h = HASH(h || their_static_pub)
        hashConcat(&h, &h, their_static_pub);

        return .{
            .chaining_key = ck,
            .hash_state   = h,
            .ephemeral    = KeyPair.generate(),
        };
    }

    /// MixHash: h = HASH(h || data).
    pub fn mixHash(self: *HandshakeState, data: []const u8) void {
        hashConcat(&self.hash_state, &self.hash_state, data);
    }

    /// MixKey: absorb DH result into chaining_key.
    pub fn mixKey(self: *HandshakeState, dh_result: []const u8) void {
        var new_ck: SymKey = undefined;
        var new_k: SymKey  = undefined;
        hkdf2(&new_ck, &new_k, &self.chaining_key, dh_result);
        self.chaining_key = new_ck;
        @memset(&new_k, 0); // zero unused send key
    }
};

// ── Initiation message ────────────────────────────────────────────────────────

/// WireGuard handshake initiation (whitepaper §5.4.2).
pub const InitiationMsg = struct {
    message_type:           u8    = 1,
    reserved:               [3]u8 = .{ 0, 0, 0 },
    sender_index:           u32,
    unencrypted_ephemeral:  PublicKey,
    encrypted_static:       [KEY_SIZE + TAG_SIZE]u8,
    encrypted_timestamp:    [TIMESTAMP_SIZE + TAG_SIZE]u8,
    mac1:                   [MAC_SIZE]u8,
    mac2:                   [MAC_SIZE]u8,
};

/// Build a Noise_IK initiation message.
pub fn initiationCreate(
    our_static:       *const KeyPair,
    their_static_pub: *const PublicKey,
    sender_index:     u32,
) !InitiationMsg {
    var state = HandshakeState.init(their_static_pub);

    // e → MixHash(e.public)
    state.mixHash(&state.ephemeral.public);

    // es → MixKey(DH(e.private, S_r))
    const es = try crypto.dh.X25519.scalarmult(state.ephemeral.private, their_static_pub.*);
    state.mixKey(&es);

    // Derive encryption key for static pubkey
    var enc_key: SymKey = undefined;
    var discard: SymKey = undefined;
    hkdf2(&discard, &enc_key, &state.chaining_key, &[_]u8{});

    var encrypted_static: [KEY_SIZE + TAG_SIZE]u8 = undefined;
    const aad1 = state.hash_state;
    crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(
        encrypted_static[0..KEY_SIZE],
        encrypted_static[KEY_SIZE..],
        &our_static.public,
        &aad1,
        [_]u8{0} ** 12,
        enc_key,
    );
    state.mixHash(&encrypted_static);

    // ss → MixKey(DH(S_i.private, S_r))
    const ss = try crypto.dh.X25519.scalarmult(our_static.private, their_static_pub.*);
    state.mixKey(&ss);

    // Derive encryption key for timestamp
    var enc_ts_key: SymKey = undefined;
    hkdf2(&discard, &enc_ts_key, &state.chaining_key, &[_]u8{});

    // TAI64N timestamp stub (random bytes; real impl uses wall clock)
    var timestamp: [TIMESTAMP_SIZE]u8 = undefined;
    crypto.random.bytes(&timestamp);

    var encrypted_timestamp: [TIMESTAMP_SIZE + TAG_SIZE]u8 = undefined;
    const aad2 = state.hash_state;
    crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(
        encrypted_timestamp[0..TIMESTAMP_SIZE],
        encrypted_timestamp[TIMESTAMP_SIZE..],
        &timestamp,
        &aad2,
        [_]u8{0} ** 12,
        enc_ts_key,
    );
    state.mixHash(&encrypted_timestamp);

    // MAC1: HMAC( HASH("mac1----" || S_r.public), msg_so_far )
    var mac1_key_input: [LABEL_MAC1.len + KEY_SIZE]u8 = undefined;
    @memcpy(mac1_key_input[0..LABEL_MAC1.len], LABEL_MAC1);
    @memcpy(mac1_key_input[LABEL_MAC1.len..], their_static_pub);
    var mac1_key: HashVal = undefined;
    hashInto(&mac1_key, &mac1_key_input);

    const MsgPrefix = extern struct {
        msg_type:  u8,
        reserved:  [3]u8,
        sender:    u32,
        ephemeral: [KEY_SIZE]u8,
        enc_static: [KEY_SIZE + TAG_SIZE]u8,
        enc_ts:    [TIMESTAMP_SIZE + TAG_SIZE]u8,
    };
    var prefix: MsgPrefix = undefined;
    prefix.msg_type = 1;
    prefix.reserved = .{ 0, 0, 0 };
    std.mem.writeInt(u32, std.mem.asBytes(&prefix.sender), sender_index, .little);
    @memcpy(&prefix.ephemeral, &state.ephemeral.public);
    @memcpy(&prefix.enc_static, &encrypted_static);
    @memcpy(&prefix.enc_ts, &encrypted_timestamp);

    var mac1_full: HashVal = undefined;
    hmac(&mac1_full, &mac1_key, std.mem.asBytes(&prefix));
    var mac1: [MAC_SIZE]u8 = undefined;
    @memcpy(&mac1, mac1_full[0..MAC_SIZE]);

    return InitiationMsg{
        .sender_index          = sender_index,
        .unencrypted_ephemeral = state.ephemeral.public,
        .encrypted_static      = encrypted_static,
        .encrypted_timestamp   = encrypted_timestamp,
        .mac1                  = mac1,
        .mac2                  = [_]u8{0} ** MAC_SIZE,
    };
}

// ── Response message ──────────────────────────────────────────────────────────

/// WireGuard handshake response (whitepaper §5.4.3).
pub const ResponseMsg = struct {
    message_type:          u8    = 2,
    reserved:              [3]u8 = .{ 0, 0, 0 },
    sender_index:          u32,
    receiver_index:        u32,
    unencrypted_ephemeral: PublicKey,
    encrypted_nothing:     [TAG_SIZE]u8,  // AEAD of empty plaintext
    mac1:                  [MAC_SIZE]u8,
    mac2:                  [MAC_SIZE]u8,
};

/// Session keys derived after handshake completes.
pub const SessionKeys = struct {
    send: SymKey,   // initiator→responder
    recv: SymKey,   // responder→initiator
};

/// Responder processes an InitiationMsg and produces a ResponseMsg + SessionKeys.
pub fn responseCreate(
    our_static:          *const KeyPair,
    initiator_static_pub: *const PublicKey,
    msg:                 *const InitiationMsg,
    sender_index:        u32,
) !struct { response: ResponseMsg, keys: SessionKeys } {
    // Init HandshakeState with responder's own public key (Noise_IK responder role)
    var state = HandshakeState.init(&our_static.public);

    // Absorb initiator's ephemeral public key
    state.mixHash(&msg.unencrypted_ephemeral);

    // es: DH(our_static.private, initiator_ephemeral) → MixKey
    const es = try crypto.dh.X25519.scalarmult(our_static.private, msg.unencrypted_ephemeral);
    state.mixKey(&es);

    // Decrypt msg.encrypted_static → recovered_static
    var dec_key: SymKey = undefined;
    var discard: SymKey = undefined;
    hkdf2(&discard, &dec_key, &state.chaining_key, &[_]u8{});

    var recovered_static: PublicKey = undefined;
    const aad_dec_static = state.hash_state;
    const ciphertext_static = msg.encrypted_static[0..KEY_SIZE];
    const tag_static: *const [TAG_SIZE]u8 = msg.encrypted_static[KEY_SIZE..][0..TAG_SIZE];
    try crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(
        &recovered_static,
        ciphertext_static,
        tag_static.*,
        &aad_dec_static,
        [_]u8{0} ** 12,
        dec_key,
    );
    state.mixHash(&msg.encrypted_static);

    // ss: DH(our_static.private, recovered_static) → MixKey
    const ss = try crypto.dh.X25519.scalarmult(our_static.private, recovered_static);
    state.mixKey(&ss);

    // Decrypt msg.encrypted_timestamp
    var dec_ts_key: SymKey = undefined;
    hkdf2(&discard, &dec_ts_key, &state.chaining_key, &[_]u8{});

    var recovered_timestamp: [TIMESTAMP_SIZE]u8 = undefined;
    const aad_dec_ts = state.hash_state;
    const ciphertext_ts = msg.encrypted_timestamp[0..TIMESTAMP_SIZE];
    const tag_ts: *const [TAG_SIZE]u8 = msg.encrypted_timestamp[TIMESTAMP_SIZE..][0..TAG_SIZE];
    try crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(
        &recovered_timestamp,
        ciphertext_ts,
        tag_ts.*,
        &aad_dec_ts,
        [_]u8{0} ** 12,
        dec_ts_key,
    );
    state.mixHash(&msg.encrypted_timestamp);

    // Verify recovered_static matches known initiator static pubkey
    if (!std.mem.eql(u8, &recovered_static, initiator_static_pub)) {
        return error.AuthenticationFailure;
    }

    // Generate responder ephemeral keypair
    const resp_ephemeral = KeyPair.generate();
    state.mixHash(&resp_ephemeral.public);

    // ee: DH(resp_ephemeral.private, initiator_ephemeral) → MixKey
    const ee = try crypto.dh.X25519.scalarmult(resp_ephemeral.private, msg.unencrypted_ephemeral);
    state.mixKey(&ee);

    // se: DH(resp_ephemeral.private, recovered_static) → MixKey
    const se = try crypto.dh.X25519.scalarmult(resp_ephemeral.private, recovered_static);
    state.mixKey(&se);

    // Encrypt empty payload → tag only
    var enc_key: SymKey = undefined;
    hkdf2(&discard, &enc_key, &state.chaining_key, &[_]u8{});

    var encrypted_nothing: [TAG_SIZE]u8 = undefined;
    const aad_enc = state.hash_state;
    crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(
        &[0]u8{},
        &encrypted_nothing,
        &[0]u8{},
        &aad_enc,
        [_]u8{0} ** 12,
        enc_key,
    );

    // Derive session keys from final chaining_key
    var keys: SessionKeys = undefined;
    hkdf2(&keys.send, &keys.recv, &state.chaining_key, &[_]u8{});

    // Build MAC1 for response: HMAC(HASH("mac1----" || initiator_static_pub), msg_prefix)
    var mac1_key_input: [LABEL_MAC1.len + KEY_SIZE]u8 = undefined;
    @memcpy(mac1_key_input[0..LABEL_MAC1.len], LABEL_MAC1);
    @memcpy(mac1_key_input[LABEL_MAC1.len..], initiator_static_pub);
    var mac1_key: HashVal = undefined;
    hashInto(&mac1_key, &mac1_key_input);

    const RespPrefix = extern struct {
        msg_type:          u8,
        reserved:          [3]u8,
        sender:            u32,
        receiver:          u32,
        ephemeral:         [KEY_SIZE]u8,
        enc_nothing:       [TAG_SIZE]u8,
    };
    var prefix: RespPrefix = undefined;
    prefix.msg_type = 2;
    prefix.reserved = .{ 0, 0, 0 };
    std.mem.writeInt(u32, std.mem.asBytes(&prefix.sender), sender_index, .little);
    std.mem.writeInt(u32, std.mem.asBytes(&prefix.receiver), msg.sender_index, .little);
    @memcpy(&prefix.ephemeral, &resp_ephemeral.public);
    @memcpy(&prefix.enc_nothing, &encrypted_nothing);

    var mac1_full: HashVal = undefined;
    hmac(&mac1_full, &mac1_key, std.mem.asBytes(&prefix));
    var mac1: [MAC_SIZE]u8 = undefined;
    @memcpy(&mac1, mac1_full[0..MAC_SIZE]);

    return .{
        .response = ResponseMsg{
            .sender_index          = sender_index,
            .receiver_index        = msg.sender_index,
            .unencrypted_ephemeral = resp_ephemeral.public,
            .encrypted_nothing     = encrypted_nothing,
            .mac1                  = mac1,
            .mac2                  = [_]u8{0} ** MAC_SIZE,
        },
        .keys = keys,
    };
}


// ── Transport data messages ──────────────────────────────────────────────────

/// WireGuard transport data packet (§5.4.6).
pub const TransportMsg = struct {
    message_type:   u8    = 4,
    reserved:       [3]u8 = .{ 0, 0, 0 },
    receiver_index: u32,
    counter:        u64,
};

/// Encrypt data packet using session keys and nonce (counter).
pub fn encryptData(
    out:     []u8,
    key:     *const SymKey,
    counter: u64,
    payload: []const u8,
) void {
    var nonce = [_]u8{0} ** 12;
    std.mem.writeInt(u64, nonce[4..12], counter, .little);
    crypto.aead.chacha_poly.ChaCha20Poly1305.encrypt(
        out[0..payload.len],
        out[payload.len..][0..TAG_SIZE],
        payload,
        &[0]u8{},
        nonce,
        key.*,
    );
}

/// Decrypt data packet using session keys and nonce (counter).
pub fn decryptData(
    out:        []u8,
    key:        *const SymKey,
    counter:    u64,
    ciphertext: []const u8,
) !void {
    if (ciphertext.len < TAG_SIZE) return error.InvalidPacket;
    var nonce = [_]u8{0} ** 12;
    std.mem.writeInt(u64, nonce[4..12], counter, .little);
    const data_len = ciphertext.len - TAG_SIZE;
    try crypto.aead.chacha_poly.ChaCha20Poly1305.decrypt(
        out[0..data_len],
        ciphertext[0..data_len],
        ciphertext[data_len..][0..TAG_SIZE].*,
        &[0]u8{},
        nonce,
        key.*,
    );
}

// ── MAC Helpers ──────────────────────────────────────────────────────────────

/// Calculate MAC1 for a packet header.
pub fn calculateMac1(out: *[MAC_SIZE]u8, msg_prefix: []const u8, their_pub: *const PublicKey) void {
    var key_input: [LABEL_MAC1.len + KEY_SIZE]u8 = undefined;
    @memcpy(key_input[0..LABEL_MAC1.len], LABEL_MAC1);
    @memcpy(key_input[LABEL_MAC1.len..], their_pub);
    var key: HashVal = undefined;
    hashInto(&key, &key_input);
    var mac_full: HashVal = undefined;
    hmac(&mac_full, &key, msg_prefix);
    @memcpy(out, mac_full[0..MAC_SIZE]);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

test "hash returns 32 bytes" {
    const a = std.testing.allocator;
    const h = try hash(a, "test");
    defer a.free(h);
    try std.testing.expect(h.len == 32);
}

test "KeyPair.generate produces non-zero pubkey" {
    const kp = KeyPair.generate();
    const zero = [_]u8{0} ** KEY_SIZE;
    try std.testing.expect(!std.mem.eql(u8, &kp.public, &zero));
}

test "hkdf2 produces two distinct keys" {
    var t1: SymKey = undefined;
    var t2: SymKey = undefined;
    hkdf2(&t1, &t2, "key", "input");
    try std.testing.expect(!std.mem.eql(u8, &t1, &t2));
}

test "initiationCreate builds valid message" {
    const initiator = KeyPair.generate();
    const responder = KeyPair.generate();
    const msg = try initiationCreate(&initiator, &responder.public, 0xdeadbeef);
    try std.testing.expectEqual(@as(u8, 1), msg.message_type);
    try std.testing.expectEqual(@as(u32, 0xdeadbeef), msg.sender_index);
    const zero48 = [_]u8{0} ** (KEY_SIZE + TAG_SIZE);
    try std.testing.expect(!std.mem.eql(u8, &msg.encrypted_static, &zero48));
}

test "responseCreate processes initiation and returns session keys" {
    const initiator = KeyPair.generate();
    const responder = KeyPair.generate();
    const init_msg = try initiationCreate(&initiator, &responder.public, 0x1111);
    const result = try responseCreate(&responder, &initiator.public, &init_msg, 0x2222);
    try std.testing.expectEqual(@as(u8, 2), result.response.message_type);
    // session keys must be non-zero
    const zero32 = [_]u8{0} ** KEY_SIZE;
    try std.testing.expect(!std.mem.eql(u8, &result.keys.send, &zero32));
    try std.testing.expect(!std.mem.eql(u8, &result.keys.recv, &zero32));
    try std.testing.expect(!std.mem.eql(u8, &result.keys.send, &result.keys.recv));
}

test "encrypt/decrypt data packet" {
    const key = [_]u8{0x42} ** 32;
    const payload = "Hello, Aura stack!";
    var ciphertext: [payload.len + TAG_SIZE]u8 = undefined;
    encryptData(&ciphertext, &key, 0x1337, payload);

    var decrypted: [payload.len]u8 = undefined;
    try decryptData(&decrypted, &key, 0x1337, &ciphertext);

    try std.testing.expectEqualStrings(payload, &decrypted);
}
