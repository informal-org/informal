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
const macho = std.macho;
const mem = std.mem;
const Allocator = mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;
const HASH_SIZE = 32; // Sha256.digest_length;

// Hash file pages concurrently for code signature generation.

pub fn ParallelHasher(comptime PHasher: type) type {
    return struct {
        allocator: Allocator,
        io: std.Io,

        pub fn hash(self: Self, file: std.Io.File, out: [][HASH_SIZE]u8, opts: struct {
            chunk_size: u64 = 0x4000,
            max_file_size: ?u64 = null,
        }) !void {
            const file_size_u64 = opts.max_file_size orelse (try file.stat(self.io)).size;
            const file_size = std.math.cast(usize, file_size_u64) orelse return error.Overflow;
            const chunk_size = std.math.cast(usize, opts.chunk_size) orelse return error.Overflow;

            if (out.len == 0) {
                return;
            }

            const cpu_count = std.Thread.getCpuCount() catch 1;
            const thread_count = @min(out.len, cpu_count);

            const buffers = try self.allocator.alloc(u8, chunk_size * thread_count);
            defer self.allocator.free(buffers);

            const results = try self.allocator.alloc(std.Io.File.ReadPositionalError!usize, out.len);
            defer self.allocator.free(results);

            var next_index = std.atomic.Value(usize).init(0);
            var wg: std.Thread.WaitGroup = .{};
            for (0..thread_count) |thread_index| {
                const buffer = buffers[thread_index * chunk_size ..][0..chunk_size];
                std.Thread.WaitGroup.spawnManager(&wg, worker, .{
                    self.io,
                    file,
                    out,
                    results,
                    chunk_size,
                    file_size,
                    buffer,
                    &next_index,
                });
            }
            wg.wait();

            for (results) |result| {
                _ = try result;
            }
        }

        fn worker(
            io: std.Io,
            file: std.Io.File,
            out: [][HASH_SIZE]u8,
            results: []std.Io.File.ReadPositionalError!usize,
            chunk_size: usize,
            file_size: usize,
            buffer: []u8,
            next_index: *std.atomic.Value(usize),
        ) void {
            while (true) {
                const index = next_index.fetchAdd(1, .monotonic);
                if (index >= out.len) {
                    break;
                }

                const fstart = index * chunk_size;
                const fsize = if (fstart + chunk_size > file_size)
                    file_size - fstart
                else
                    chunk_size;

                const read_result = file.readPositionalAll(io, buffer[0..fsize], fstart);
                results[index] = read_result;
                if (read_result) |_| {
                    PHasher.hash(buffer[0..fsize], &out[index], .{});
                } else |_| {}
            }
        }

        const Self = @This();
    };
}

fn writeIntBig(writer: anytype, comptime T: type, value: T) !void {
    var buf: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, buf[0..], value, .big);
    _ = try std.Io.Writer.writeVec(@constCast(&writer.interface), &[_][]const u8{buf[0..]});
}

fn writeByte(writer: anytype, value: u8) !void {
    const buf = [_]u8{value};
    _ = try std.Io.Writer.writeVec(@constCast(&writer.interface), &[_][]const u8{&buf});
}

fn writeCodeDirectory(writer: anytype, codedir: macho.CodeDirectory) !void {
    // The format requires the structs to be encoded in big-endian,
    // while the Arm platform is little endian...
    // So each field is manually encoded.
    try writeIntBig(writer, u32, codedir.magic);
    try writeIntBig(writer, u32, codedir.length);
    try writeIntBig(writer, u32, codedir.version);
    try writeIntBig(writer, u32, codedir.flags);
    try writeIntBig(writer, u32, codedir.hashOffset);
    try writeIntBig(writer, u32, codedir.identOffset);
    try writeIntBig(writer, u32, codedir.nSpecialSlots);
    try writeIntBig(writer, u32, codedir.nCodeSlots);
    try writeIntBig(writer, u32, codedir.codeLimit);
    try writeByte(writer, codedir.hashSize);
    try writeByte(writer, codedir.hashType);
    try writeByte(writer, codedir.platform);
    try writeByte(writer, codedir.pageSize);
    try writeIntBig(writer, u32, codedir.spare2);
    try writeIntBig(writer, u32, codedir.scatterOffset);
    try writeIntBig(writer, u32, codedir.teamOffset);
    try writeIntBig(writer, u32, codedir.spare3);
    try writeIntBig(writer, u64, codedir.codeLimit64);
    try writeIntBig(writer, u64, codedir.execSegBase);
    try writeIntBig(writer, u64, codedir.execSegLimit);
    try writeIntBig(writer, u64, codedir.execSegFlags);
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

pub fn sign(writer: anytype, file: std.Io.File, io: std.Io, args: SignArgs) !void {
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
    try writeIntBig(writer, u32, sb.magic);
    try writeIntBig(writer, u32, sb.length);
    try writeIntBig(writer, u32, sb.count);

    // Part 2 - Index blobs ---------------------------------------------------------------
    // The Zig version supports multiple blob indexes for requirements, entitlements, etc.
    // We just need a single index blob for the code-signature, like the go version.
    try writeIntBig(writer, u32, macho.CSSLOT_CODEDIRECTORY);
    try writeIntBig(writer, u32, codeDirOffset);

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
    _ = try std.Io.Writer.writeVec(@constCast(&writer.interface), &[_][]const u8{args.identifier});
    const null_byte: u8 = 0;
    _ = try std.Io.Writer.writeVec(@constCast(&writer.interface), &[_][]const u8{&[_]u8{null_byte}});

    // Part 5 - Hash signature -----------------------------------------------------------
    // Hash the file contents
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var code_slots: std.ArrayListUnmanaged([HASH_SIZE]u8) = .{};
    try code_slots.ensureTotalCapacityPrecise(allocator, nCodeSlots);
    code_slots.items.len = nCodeSlots;

    var hasher = ParallelHasher(Sha256){ .allocator = allocator, .io = io };
    try hasher.hash(file, code_slots.items, .{
        .chunk_size = pageSize,
        .max_file_size = args.overallBinCodeLimit,
    });

    for (code_slots.items) |slot| {
        _ = try std.Io.Writer.writeVec(@constCast(&writer.interface), &[_][]const u8{&slot});
    }
}
