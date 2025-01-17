// MachO Code Signature for the linker.
// macOS 11+ and Apple Silicon binaries require MachO files to be signed - Unsigned binaries get killed immediately.
// The signature section is the very last piece of a MachO binary, representing a SHA256 hash of each page of the binary.
// (Older versions of MacOS supported SHA-1, and dual hashing, but that's deprecated).
// Ad-hoc signatures are non-portable, content-hashes. Portable, distribution signatures require signing with a cert.
//
// This implementation of ad-hoc code signing is heavily based on the Zig and Golang implementations
// The ParallelHasher and code directory encoding is taken directly from Zig, stripped down to the features we need.
// The general ad hoc signing is based on the Go implementation.
// https://github.com/ziglang/zig/blob/0.12.0/src/link/MachO/CodeSignature.zig
// https://github.com/golang/go/blame/master/src/cmd/internal/codesign/codesign.go#L205
// Credit to: @kubkon and Zig contributors.
// Credit to: @rsc and Go Contributors.
// License: MIT

// This is not a general purpose implementation. It's a minimal version for Informal's use case.

const std = @import("std");
const fs = std.fs;
const macho = std.macho;
const mem = std.mem;
const Allocator = mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;
const HASH_SIZE = 32; // Sha256.digest_length;

const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;

pub fn ParallelHasher(comptime PHasher: type) type {
    return struct {
        allocator: Allocator,
        thread_pool: *ThreadPool,

        pub fn hash(self: Self, file: fs.File, out: [][HASH_SIZE]u8, opts: struct {
            chunk_size: u64 = 0x4000,
            max_file_size: ?u64 = null,
        }) !void {
            var wg: WaitGroup = .{};

            const file_size = blk: {
                const file_size = opts.max_file_size orelse try file.getEndPos();
                break :blk std.math.cast(usize, file_size) orelse return error.Overflow;
            };
            const chunk_size = std.math.cast(usize, opts.chunk_size) orelse return error.Overflow;

            const buffer = try self.allocator.alloc(u8, chunk_size * out.len);
            defer self.allocator.free(buffer);

            const results = try self.allocator.alloc(fs.File.PReadError!usize, out.len);
            defer self.allocator.free(results);

            {
                wg.reset();
                defer wg.wait();

                for (out, results, 0..) |*out_buf, *result, i| {
                    const fstart = i * chunk_size;
                    const fsize = if (fstart + chunk_size > file_size)
                        file_size - fstart
                    else
                        chunk_size;
                    wg.start();
                    try self.thread_pool.spawn(worker, .{
                        file,
                        fstart,
                        buffer[fstart..][0..fsize],
                        &(out_buf.*),
                        &(result.*),
                        &wg,
                    });
                }
            }
            for (results) |result| _ = try result;
        }

        fn worker(
            file: fs.File,
            fstart: usize,
            buffer: []u8,
            out: *[HASH_SIZE]u8,
            err: *fs.File.PReadError!usize,
            wg: *WaitGroup,
        ) void {
            defer wg.finish();
            err.* = file.preadAll(buffer, fstart);
            PHasher.hash(buffer, out, .{});
        }

        const Self = @This();
    };
}

fn writeCodeDirectory(writer: anytype, codedir: macho.CodeDirectory) !void {
    // The format requires the structs to be encoded in big-endian,
    // while the Arm platform is little endian...
    // So each field is manually encoded.
    try writer.writeInt(u32, codedir.magic, .big);
    try writer.writeInt(u32, codedir.length, .big);
    try writer.writeInt(u32, codedir.version, .big);
    try writer.writeInt(u32, codedir.flags, .big);
    try writer.writeInt(u32, codedir.hashOffset, .big);
    try writer.writeInt(u32, codedir.identOffset, .big);
    try writer.writeInt(u32, codedir.nSpecialSlots, .big);
    try writer.writeInt(u32, codedir.nCodeSlots, .big);
    try writer.writeInt(u32, codedir.codeLimit, .big);
    try writer.writeByte(codedir.hashSize);
    try writer.writeByte(codedir.hashType);
    try writer.writeByte(codedir.platform);
    try writer.writeByte(codedir.pageSize);
    try writer.writeInt(u32, codedir.spare2, .big);
    try writer.writeInt(u32, codedir.scatterOffset, .big);
    try writer.writeInt(u32, codedir.teamOffset, .big);
    try writer.writeInt(u32, codedir.spare3, .big);
    try writer.writeInt(u64, codedir.codeLimit64, .big);
    try writer.writeInt(u64, codedir.execSegBase, .big);
    try writer.writeInt(u64, codedir.execSegLimit, .big);
    try writer.writeInt(u64, codedir.execSegFlags, .big);
}

const pageSizeBits = 12;
const pageSize = 1 << pageSizeBits;
const codeDirectorySize = 13 * 4 + 4 + 4 * 8; // 0x58
const superBlobSize = 3 * 4;
const blobSize = 2 * 4;

pub const SignArgs = struct {
    // Arguments:
    // numPages: Total number of OS pages in the binary. (16k)
    // identifier: String name of the binary (not null terminated)
    // overallBinCodeLimit: The size of the overall binary, without the signature section (before the super-magic starts).
    // execTextSegmentOffset and limit: File offset and size of the executable text segment.
    numPages: u32,
    identifier: []const u8,
    overallBinCodeLimit: u32,
    execTextSegmentOffset: u64,
    execTextSegmentLimit: u64,
};

pub fn estimateSize(args: SignArgs) u64 {
    const nCodeSlots = @as(u32, @intCast(mem.alignForward(usize, args.overallBinCodeLimit, pageSize) / pageSize));
    const hashEnd = nCodeSlots * HASH_SIZE;
    return superBlobSize + blobSize + codeDirectorySize + args.identifier.len + 1 + hashEnd;
}

pub fn sign(writer: anytype, file: fs.File, args: SignArgs) !void {
    // General format for the ad-hoc signatures:
    // 1. Super Blob header, beginning with the magic 0xfade0cc0
    // 2. Index Blob for each sub-blobs - in this case, just the CodeDirectory index blob.
    // 3. Code Directory, representing the overall file structure.
    // 4. Executable name - null terminated.
    // 5. Hashes - 32 bytes each.
    // ---------------------------------------------------------

    // Go computes this as: (codeSize + pageSize - 1) / pageSize
    const nCodeSlots = @as(u32, @intCast(mem.alignForward(usize, args.overallBinCodeLimit, pageSize) / pageSize));

    // Compute CodeDirectory length
    const codeDirOffset = superBlobSize + blobSize; // 0x0014 = 20
    const idOff: u32 = codeDirectorySize; // Identifier starts after the code directory.
    const hashOff: u32 = @truncate(idOff + args.identifier.len + 1); // Hash starts after directory + identifier + null terminator.
    const hashEnd = hashOff + nCodeSlots * HASH_SIZE; // End of hash section.
    const totalSignatureSize = codeDirOffset + hashEnd;

    // Part 1 - Super blob header ---------------------------------------------------------
    const sb = macho.SuperBlob{
        .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
        .length = totalSignatureSize, // Overall size of the binary. Zig sums this incrementally per blob. Go uses the above.
        .count = 1, // # of BlobIndex entries following. We just need 1 for the code-dir.
    };
    try writer.writeInt(u32, sb.magic, .big);
    try writer.writeInt(u32, sb.length, .big);
    try writer.writeInt(u32, sb.count, .big);

    // Part 2 - Index blobs ---------------------------------------------------------------
    // The Zig version supports multiple blob indexes for requirements, entitlements, etc.
    // We just need a single index blob for the code-signature, like the go version.
    try writer.writeInt(u32, macho.CSSLOT_CODEDIRECTORY, .big); // 0
    try writer.writeInt(u32, codeDirOffset, .big);

    // Part 3 - Code Directory ------------------------------------------------------------
    const code_dir = macho.CodeDirectory{
        .magic = macho.CSMAGIC_CODEDIRECTORY,
        .length = @truncate(hashEnd), // @sizeOf(macho.CodeDirectory) / 256
        .version = macho.CS_SUPPORTSEXECSEG, // 0x20400
        .flags = macho.CS_ADHOC | macho.CS_LINKER_SIGNED,
        .hashOffset = hashOff, // hashOff
        .identOffset = idOff, // idOff
        .nCodeSlots = nCodeSlots, // nHashes
        .codeLimit = args.overallBinCodeLimit, // code size - limit and 64 are separate. 0x40b0
        .hashSize = HASH_SIZE, // sha256 size.
        .hashType = macho.CS_HASHTYPE_SHA256,
        .pageSize = pageSizeBits, // page size in bits.
        .execSegBase = args.execTextSegmentOffset, // textOff
        .execSegLimit = args.execTextSegmentLimit, // Limit of exec sec
        .execSegFlags = macho.CS_EXECSEG_MAIN_BINARY, // only for main

        // Other flags.
        .codeLimit64 = 0,
        .spare3 = 0,
        .teamOffset = 0,
        .scatterOffset = 0,
        .spare2 = 0,
        .platform = 0,
        .nSpecialSlots = 0,
    };

    try writeCodeDirectory(writer, code_dir);

    // Part 4 - Binary name --------------------------------------------------------------
    // Write file name identifier.
    try writer.writeAll(args.identifier);
    try writer.writeByte(0); // Null terminate.

    // Part 5 - Hash signature -----------------------------------------------------------
    // Hash the file contents
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(.{ .allocator = allocator });
    defer thread_pool.deinit();

    var code_slots: std.ArrayListUnmanaged([HASH_SIZE]u8) = .{};
    try code_slots.ensureTotalCapacityPrecise(allocator, nCodeSlots);
    code_slots.items.len = nCodeSlots;

    var hasher = ParallelHasher(Sha256){ .allocator = allocator, .thread_pool = &thread_pool };
    try hasher.hash(file, code_slots.items, .{
        .chunk_size = pageSize,
        .max_file_size = args.overallBinCodeLimit,
    });

    for (code_slots.items) |slot| {
        try writer.writeAll(&slot);
    }
}
