// MachO Code Signature:
// References how Zig and Golang implements this:
// https://github.com/ziglang/zig/blob/0.12.0/src/link/MachO/CodeSignature.zig
// https://github.com/golang/go/blame/master/src/cmd/internal/codesign/codesign.go#L205


pub const CodeSignature = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;
// const Hasher = @import("hasher.zig").ParallelHasher;
// const MachO = @import("../MachO.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;
const hash_size = Sha256.digest_length;
const ThreadPool = std.Thread.Pool;
const WaitGroup = std.Thread.WaitGroup;


pub fn ParallelHasher(comptime PHasher: type) type {
    // const hash_size = PHasher.digest_length;

    return struct {
        allocator: Allocator,
        thread_pool: *ThreadPool,

        pub fn hash(self: Self, file: fs.File, out: [][hash_size]u8, opts: struct {
            chunk_size: u64 = 0x4000,
            max_file_size: ?u64 = null,
        }) !void {
            // const tracy = trace(@src());
            // defer tracy.end();

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
            out: *[hash_size]u8,
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


const Hasher = ParallelHasher;




const Blob = union(enum) {
    code_directory: *CodeDirectory,
    requirements: *Requirements,
    entitlements: *Entitlements,
    signature: *Signature,

    fn slotType(self: Blob) u32 {
        return switch (self) {
            .code_directory => |x| x.slotType(),
            .requirements => |x| x.slotType(),
            .entitlements => |x| x.slotType(),
            .signature => |x| x.slotType(),
        };
    }

    fn size(self: Blob) u32 {
        return switch (self) {
            .code_directory => |x| x.size(),
            .requirements => |x| x.size(),
            .entitlements => |x| x.size(),
            .signature => |x| x.size(),
        };
    }

    fn write(self: Blob, writer: anytype) !void {
        return switch (self) {
            .code_directory => |x| x.write(writer),
            .requirements => |x| x.write(writer),
            .entitlements => |x| x.write(writer),
            .signature => |x| x.write(writer),
        };
    }
};

const CodeDirectory = struct {
    inner: macho.CodeDirectory,
    ident: []const u8,
    special_slots: [n_special_slots][hash_size]u8,
    code_slots: std.ArrayListUnmanaged([hash_size]u8) = .{},

    const n_special_slots: usize = 7;

    fn init(page_size: u16) CodeDirectory {
        var cdir: CodeDirectory = .{
            .inner = .{
                .magic = macho.CSMAGIC_CODEDIRECTORY,
                .length = @sizeOf(macho.CodeDirectory),
                .version = macho.CS_SUPPORTSEXECSEG,
                .flags = macho.CS_ADHOC | macho.CS_LINKER_SIGNED,
                .hashOffset = 0,
                .identOffset = @sizeOf(macho.CodeDirectory),
                .nSpecialSlots = 0,
                .nCodeSlots = 0,
                .codeLimit = 0,
                .hashSize = hash_size,
                .hashType = macho.CS_HASHTYPE_SHA256,
                .platform = 0,
                .pageSize = @as(u8, @truncate(std.math.log2(page_size))),
                .spare2 = 0,
                .scatterOffset = 0,
                .teamOffset = 0,
                .spare3 = 0,
                .codeLimit64 = 0,
                .execSegBase = 0,
                .execSegLimit = 0,
                .execSegFlags = 0,
            },
            .ident = undefined,
            .special_slots = undefined,
        };
        comptime var i = 0;
        inline while (i < n_special_slots) : (i += 1) {
            cdir.special_slots[i] = [_]u8{0} ** hash_size;
        }
        return cdir;
    }

    fn deinit(self: *CodeDirectory, allocator: Allocator) void {
        self.code_slots.deinit(allocator);
    }

    fn addSpecialHash(self: *CodeDirectory, index: u32, hash: [hash_size]u8) void {
        assert(index > 0);
        self.inner.nSpecialSlots = @max(self.inner.nSpecialSlots, index);
        @memcpy(&self.special_slots[index - 1], &hash);
    }

    fn slotType(self: CodeDirectory) u32 {
        _ = self;
        return macho.CSSLOT_CODEDIRECTORY;
    }

    fn size(self: CodeDirectory) u32 {
        const code_slots = self.inner.nCodeSlots * hash_size;
        const special_slots = self.inner.nSpecialSlots * hash_size;
        return @sizeOf(macho.CodeDirectory) + @as(u32, @intCast(self.ident.len + 1 + special_slots + code_slots));
    }

    fn write(self: CodeDirectory, writer: anytype) !void {
        try writer.writeInt(u32, self.inner.magic, .big);
        try writer.writeInt(u32, self.inner.length, .big);
        try writer.writeInt(u32, self.inner.version, .big);
        try writer.writeInt(u32, self.inner.flags, .big);
        try writer.writeInt(u32, self.inner.hashOffset, .big);
        try writer.writeInt(u32, self.inner.identOffset, .big);
        try writer.writeInt(u32, self.inner.nSpecialSlots, .big);
        try writer.writeInt(u32, self.inner.nCodeSlots, .big);
        try writer.writeInt(u32, self.inner.codeLimit, .big);
        try writer.writeByte(self.inner.hashSize);
        try writer.writeByte(self.inner.hashType);
        try writer.writeByte(self.inner.platform);
        try writer.writeByte(self.inner.pageSize);
        try writer.writeInt(u32, self.inner.spare2, .big);
        try writer.writeInt(u32, self.inner.scatterOffset, .big);
        try writer.writeInt(u32, self.inner.teamOffset, .big);
        try writer.writeInt(u32, self.inner.spare3, .big);
        try writer.writeInt(u64, self.inner.codeLimit64, .big);
        try writer.writeInt(u64, self.inner.execSegBase, .big);
        try writer.writeInt(u64, self.inner.execSegLimit, .big);
        try writer.writeInt(u64, self.inner.execSegFlags, .big);

        // try writer.writeAll(self.ident);
        // try writer.writeByte(0);

        // var i: isize = @as(isize, @intCast(self.inner.nSpecialSlots));
        // while (i > 0) : (i -= 1) {
        //     try writer.writeAll(&self.special_slots[@as(usize, @intCast(i - 1))]);
        // }

        // for (self.code_slots.items) |slot| {
        //     try writer.writeAll(&slot);
        // }
    }
};

const Requirements = struct {
    fn deinit(self: *Requirements, allocator: Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn slotType(self: Requirements) u32 {
        _ = self;
        return macho.CSSLOT_REQUIREMENTS;
    }

    fn size(self: Requirements) u32 {
        _ = self;
        return 3 * @sizeOf(u32);
    }

    fn write(self: Requirements, writer: anytype) !void {
        try writer.writeInt(u32, macho.CSMAGIC_REQUIREMENTS, .big);
        try writer.writeInt(u32, self.size(), .big);
        try writer.writeInt(u32, 0, .big);
    }
};

const Entitlements = struct {
    inner: []const u8,

    fn deinit(self: *Entitlements, allocator: Allocator) void {
        allocator.free(self.inner);
    }

    fn slotType(self: Entitlements) u32 {
        _ = self;
        return macho.CSSLOT_ENTITLEMENTS;
    }

    fn size(self: Entitlements) u32 {
        return @as(u32, @intCast(self.inner.len)) + 2 * @sizeOf(u32);
    }

    fn write(self: Entitlements, writer: anytype) !void {
        try writer.writeInt(u32, macho.CSMAGIC_EMBEDDED_ENTITLEMENTS, .big);
        try writer.writeInt(u32, self.size(), .big);
        try writer.writeAll(self.inner);
    }
};

const Signature = struct {
    fn deinit(self: *Signature, allocator: Allocator) void {
        _ = self;
        _ = allocator;
    }

    fn slotType(self: Signature) u32 {
        _ = self;
        return macho.CSSLOT_SIGNATURESLOT;
    }

    fn size(self: Signature) u32 {
        _ = self;
        return 2 * @sizeOf(u32);
    }

    fn write(self: Signature, writer: anytype) !void {
        try writer.writeInt(u32, macho.CSMAGIC_BLOBWRAPPER, .big);
        try writer.writeInt(u32, self.size(), .big);
    }
};

page_size: u16,
code_directory: CodeDirectory,
requirements: ?Requirements = null,
entitlements: ?Entitlements = null,
signature: ?Signature = null,

pub fn init(page_size: u16) CodeSignature {
    return .{
        .page_size = page_size,
        .code_directory = CodeDirectory.init(page_size),
    };
}

pub fn deinit(self: *CodeSignature, allocator: Allocator) void {
    self.code_directory.deinit(allocator);
    if (self.requirements) |*req| {
        req.deinit(allocator);
    }
    if (self.entitlements) |*ents| {
        ents.deinit(allocator);
    }
    if (self.signature) |*sig| {
        sig.deinit(allocator);
    }
}

pub fn addEntitlements(self: *CodeSignature, allocator: Allocator, path: []const u8) !void {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();
    const inner = try file.readToEndAlloc(allocator, std.math.maxInt(u32));
    self.entitlements = .{ .inner = inner };
}

pub const WriteOpts = struct {
    file: fs.File,
    exec_seg_base: u64,
    exec_seg_limit: u64,
    file_size: u32,
    dylib: bool,
};

pub fn writeAdhocSignature(
    self: *CodeSignature,
    // macho_file: *MachO,
    opts: WriteOpts,
    writer: anytype,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator(); 
    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(.{ .allocator = allocator });
    defer thread_pool.deinit();


    var header: macho.SuperBlob = .{
        .magic = macho.CSMAGIC_EMBEDDED_SIGNATURE,
        .length = @sizeOf(macho.SuperBlob),
        .count = 0,
    };

    var blobs = std.ArrayList(Blob).init(allocator);
    defer blobs.deinit();

    self.code_directory.inner.execSegBase = opts.exec_seg_base;
    self.code_directory.inner.execSegLimit = opts.exec_seg_limit;
    self.code_directory.inner.execSegFlags = if (!opts.dylib) macho.CS_EXECSEG_MAIN_BINARY else 0;
    self.code_directory.inner.codeLimit = opts.file_size;

    const total_pages = @as(u32, @intCast(mem.alignForward(usize, opts.file_size, self.page_size) / self.page_size));

    try self.code_directory.code_slots.ensureTotalCapacityPrecise(allocator, total_pages);
    self.code_directory.code_slots.items.len = total_pages;
    self.code_directory.inner.nCodeSlots = total_pages;

    // Calculate hash for each page (in file) and write it to the buffer
    var hasher = Hasher(Sha256){ .allocator = allocator, .thread_pool = &thread_pool };
    try hasher.hash(opts.file, self.code_directory.code_slots.items, .{
        .chunk_size = self.page_size,
        .max_file_size = opts.file_size,
    });

    try blobs.append(.{ .code_directory = &self.code_directory });
    header.length += @sizeOf(macho.BlobIndex);
    header.count += 1;

    var hash: [hash_size]u8 = undefined;

    if (self.requirements) |*req| {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try req.write(buf.writer());
        Sha256.hash(buf.items, &hash, .{});
        self.code_directory.addSpecialHash(req.slotType(), hash);

        try blobs.append(.{ .requirements = req });
        header.count += 1;
        header.length += @sizeOf(macho.BlobIndex) + req.size();
    }

    if (self.entitlements) |*ents| {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try ents.write(buf.writer());
        Sha256.hash(buf.items, &hash, .{});
        self.code_directory.addSpecialHash(ents.slotType(), hash);

        try blobs.append(.{ .entitlements = ents });
        header.count += 1;
        header.length += @sizeOf(macho.BlobIndex) + ents.size();
    }

    if (self.signature) |*sig| {
        try blobs.append(.{ .signature = sig });
        header.count += 1;
        header.length += @sizeOf(macho.BlobIndex) + sig.size();
    }

    self.code_directory.inner.hashOffset =
        @sizeOf(macho.CodeDirectory) + @as(u32, @intCast(self.code_directory.ident.len + 1 + self.code_directory.inner.nSpecialSlots * hash_size));
    self.code_directory.inner.length = self.code_directory.size();
    header.length += self.code_directory.size();

    try writer.writeInt(u32, header.magic, .big);
    try writer.writeInt(u32, header.length, .big);
    try writer.writeInt(u32, header.count, .big);

    var offset: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) * @as(u32, @intCast(blobs.items.len));
    for (blobs.items) |blob| {
        try writer.writeInt(u32, blob.slotType(), .big);
        try writer.writeInt(u32, offset, .big);
        offset += blob.size();
    }

    for (blobs.items) |blob| {
        try blob.write(writer);
    }
}

pub fn size(self: CodeSignature) u32 {
    var ssize: u32 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) + self.code_directory.size();
    if (self.requirements) |req| {
        ssize += @sizeOf(macho.BlobIndex) + req.size();
    }
    if (self.entitlements) |ent| {
        ssize += @sizeOf(macho.BlobIndex) + ent.size();
    }
    if (self.signature) |sig| {
        ssize += @sizeOf(macho.BlobIndex) + sig.size();
    }
    return ssize;
}

pub fn estimateSize(self: CodeSignature, file_size: u64) u32 {
    var ssize: u64 = @sizeOf(macho.SuperBlob) + @sizeOf(macho.BlobIndex) + self.code_directory.size();
    // Approx code slots
    const total_pages = mem.alignForward(u64, file_size, self.page_size) / self.page_size;
    ssize += total_pages * hash_size;
    var n_special_slots: u32 = 0;
    if (self.requirements) |req| {
        ssize += @sizeOf(macho.BlobIndex) + req.size();
        n_special_slots = @max(n_special_slots, req.slotType());
    }
    if (self.entitlements) |ent| {
        ssize += @sizeOf(macho.BlobIndex) + ent.size() + hash_size;
        n_special_slots = @max(n_special_slots, ent.slotType());
    }
    if (self.signature) |sig| {
        ssize += @sizeOf(macho.BlobIndex) + sig.size();
    }
    ssize += n_special_slots * hash_size;
    return @as(u32, @intCast(mem.alignForward(u64, ssize, @sizeOf(u64))));
}

pub fn clear(self: *CodeSignature, allocator: Allocator) void {
    self.code_directory.deinit(allocator);
    self.code_directory = CodeDirectory.init(self.page_size);
}



// My version - based on the Golang implementation
const MAGIC_CODEDIRECTORY = 0xfade0c02;
const MAGIC_EMBEDDED = 0xfade0cc0;


const CS_HASHTYPE_SHA256 = 2;

// SuperBlob = macho.SuperBlob

const MyBlob = struct {
    // TODO: Order of these?
    typ: u32,
    offset: u32,
};


pub fn sign(writer: anytype) !void {
    // code sig off
    // text - file offset
    // text - file size
    // exe | pie = true

    // const codeSize = 0x40B0;       // code signature offset
    // const pageSizeBits = 12;
    // const pageSize = 1 << pageSizeBits;   // 4KB? We use 16kb pages elsewhere though
    // const nHashes = (codeSize + pageSize - 1) / pageSize;
    // const id = "minimal";
    // const idOff: u64 = idOff + id.len + 1;
    // const sz = 

    const sb = macho.SuperBlob{ 
        .magic = MAGIC_EMBEDDED,
        .length = 0x114, // 0x114        // @sizeOf(macho.SuperBlob)
        .count = 1,  // # of BlobIndex entries following. Zig emits 0, golang and gcc emits 1.
    };
    try writer.writeInt(u32, sb.magic, .big);
    try writer.writeInt(u32, sb.length, .big);
    try writer.writeInt(u32, sb.count, .big);

    // Index blob
    try writer.writeInt(u32, macho.CSSLOT_CODEDIRECTORY, .big); // 0
    try writer.writeInt(u32, 0x0014, .big);       // offset. superblog.size + blogSize

    // try writer.writeStruct(sb);

    // const superBlobSize = 3 * 4;
    // const blobSize = 2 * 4;
    // const bidx = BlobIndex {
    //     .type = MAGIC_CODEDIRECTORY,
    //     .offset = sb.
    // }

    var code_dir = CodeDirectory.init(1);
    code_dir.inner = macho.CodeDirectory {
        .magic = macho.CSMAGIC_CODEDIRECTORY,
        .length = 256, // @sizeOf(macho.CodeDirectory)
        .version = macho.CS_SUPPORTSEXECSEG,    // 0x20400
        .flags = macho.CS_ADHOC | macho.CS_LINKER_SIGNED,
        .hashOffset = 96,   // hashOff
        .identOffset = 88,  // idOff
        .nCodeSlots = 5,    // nHashes
        .codeLimit = 16560, // code size - limit and 64 are separate. 0x40b0
        .hashSize = 32,     // sha256 size.
        .hashType = macho.CS_HASHTYPE_SHA256,
        .pageSize = 12,     // page size in bits.
        .execSegBase = 0,   // textOff
        .execSegLimit = 12,     // Limit of exec sec
        .execSegFlags = macho.CS_EXECSEG_MAIN_BINARY,      // only for main

        // Other flags.
        .codeLimit64 = 0,
        .spare3 = 0,
        .teamOffset = 0,
        .scatterOffset = 0,
        .spare2 = 0,
        .platform = 0,
        .nSpecialSlots = 0
    };

    try code_dir.write(writer);
    try writer.writeAll("minimal");
    try writer.writeByte(0);    // Null terminate.
    // 40b0 - codeLimit

    const hashes = [_]u8{ 0x41, 0xF9, 0x97 , 0xAC, 0xD6, 0x16, 0x69 , 0x05, 0x4C, 0x2D, 0x9D , 0xCB, 
    0x0E, 0x34, 0x74 , 0xA0, 0x5D, 0x84, 0x4B , 0x28, 0xB0, 0x44, 0xEA , 0x37, 0x87, 0x4F, 0xCE , 0xA5, 
    0x9F, 0xC2, 0x70 , 0xD6, 0xAD, 0x7F, 0xAC , 0xB2, 0x58, 0x6F, 0xC6 , 0xE9, 0x66, 0xC0, 0x04 , 0xD7, 
    0xD1, 0xD1, 0x6B , 0x02, 0x4F, 0x58, 0x05 , 0xFF, 0x7C, 0xB4, 0x7C , 0x7A, 0x85, 0xDA, 0xBD , 0x8B, 
    0x48, 0x89, 0x2C , 0xA7, 0xAD, 0x7F, 0xAC , 0xB2, 0x58, 0x6F, 0xC6 , 0xE9, 0x66, 0xC0, 0x04 , 0xD7, 
    0xD1, 0xD1, 0x6B , 0x02, 0x4F, 0x58, 0x05 , 0xFF, 0x7C, 0xB4, 0x7C , 0x7A, 0x85, 0xDA, 0xBD , 0x8B, 
    0x48, 0x89, 0x2C , 0xA7, 0xA9, 0x8C, 0xE6 , 0x34, 0x9A, 0x41, 0xC3 , 0x2E, 0xA0, 0x10, 0x72 , 0xAF, 
    0xF0, 0xA1, 0xF5 , 0x8D, 0x79, 0xED, 0x17 , 0xBF, 0xEB, 0xFE, 0xD5 , 0x55, 0xF5, 0xE3, 0x32 , 0xB3, 
    0x86, 0xF4, 0x83 , 0x23, 0xAB, 0xD8, 0xAB , 0x74, 0xF6, 0xF2, 0x2C , 0x75, 0xF5, 0x97, 0xAA , 0x84, 
    0x51, 0xB2, 0xEA , 0x39, 0xD6, 0x87, 0x49 , 0xF4, 0xA2, 0x60, 0xC8 , 0x8B, 0x29, 0x27, 0xDC , 0x0B, 
    0x74, 0x34, 0x8C , 0x46, 0x00, 0x00, 0x00, 0x00};
    for (hashes) |byte| {
        try writer.writeByte(byte);
    }

    // const code_dir = macho.CodeDirectory 
    // try writer.writeStruct(code_dir);
}

