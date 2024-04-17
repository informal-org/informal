
// const sys = @cImport({
//     @cInclude("aarch64-mac/syscall.h");
// });


// General layout:
// Mach Header - Architecture, # of commands and size of commands.
// Commands - Other compilers seem to emit all 15 commands, even empty...
// Segments for each command. Specifies # of sections.
// Sections for each segment.
// A lot of zeroes for page alignment.
// Actual code and data.


// 64 bit support only.
// Reference:
// /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach-o/loader.h
// Thanks to: https://gpanders.com/blog/exploring-mach-o-part-2/
const MachHeader64 = packed struct {
	magic: u32,		        // mach magic number identifier */
	cputype: CpuType,	        // cpu specifier */
	cpusubtype: u32,	    // machine specifier */
    filetype: Filetype,	        // type of file */
	ncmds: u32,		        // number of load commands */
	sizeofcmds: u32,	    // the size of all the load commands */
	flags: Flags,		        // flags */
    reserved: u32 = 0         // padding.
};

// 32bit = 0xfeedface :)
const MH_MAGIC = 0xfeedfacf;


const CPU_ARCH_ABI64 = 0x01000000;

const CpuType = enum(u32) {
    // any = @bitCast(u32, machine.CPU_TYPE_ANY),
    // vax = machine.CPU_TYPE_VAX,
    // mc680x0 = machine.CPU_TYPE_MC680x0,
    // x86 = 7,
    x86_64 = 7 | CPU_ARCH_ABI64,
    // arm = machine.CPU_TYPE_ARM,
    arm64 = 12 | CPU_ARCH_ABI64,
    // arm64_32 = machine.CPU_TYPE_ARM | machine.CPU_ARCH_ABI64_32,
    // mc88000 = machine.CPU_TYPE_MC88000,
    // sparc = machine.CPU_TYPE_SPARC,
    // i860 = machine.CPU_TYPE_I860,
    // powerpc = machine.CPU_TYPE_POWERPC,
    // powerpc64 = machine.CPU_TYPE_POWERPC | machine.CPU_ARCH_ABI64,
};


const Filetype = enum(u32) {
    object = 0x1,   // Relocatable object
    execute = 0x2,  // demand paged executable file
    fvmlib = 0x3,   // fixed VM shared library file
    core = 0x4,     // core file
    preload = 0x5,  // preloaded executable file
    dylib = 0x6,    // dynamically bound shared library
    dylinker = 0x7,  // dynamic link editor
    bundle = 0x8,   // dynamically bound bundle file
    dylib_stub = 0x9,   // shared library stub for static linking only, no section contents
    dsym = 0xa, // companion file with only debug sections
    kext_bundle = 0xb,  // x86_64 kexts
    fileset = 0xc,   // a file composed of other Mach-Os to be run in the same userspace sharing a single linkedit.
    gpu_program = 0xd,  // a GPU program
    gpu_dylib = 0xe,    // GPU support function
};

// Reference:
// https://web.archive.org/web/20090901205800/http://developer.apple.com/mac/library/documentation/DeveloperTools/Conceptual/MachORuntime/Reference/reference.html#//apple_ref/c/tag/section_64
// Minimal: NOUNDEFS, DYLDLINK, TWOLEVEL, PIE
const Flags = packed struct {
    noundefs: bool = false, // The object file contained no undefined references when it was built
    incrlink: bool = false, // The object file is the output of an incremental link against a base file and cannot be linked again.
    dyldlink: bool = false, // The file is input for the dynamic linker and cannot be statically linked again
    bindatload: bool = false, // The dynamic linker should bind the undefined references when the file is loaded.
    prebound: bool = false, // The file’s undefined references are prebound
    split_segs: bool = false, // The file has its read-only and read-write segments split.
    lazy_init: bool = false,
    twolevel: bool = false, // The image is using two-level namespace bindings
    force_flat: bool = false, // The executable is forcing all images to use flat namespace bindings
    nomultidefs: bool = false, // This umbrella guarantees there are no multiple definitions of symbols in its subimages. As a result, the two-level namespace hints can always be used.
    nofixprebinding: bool = false,  // The dynamic linker doesn’t notify the prebinding agent about this executable
    prebindable: bool = false,  // This file is not prebound but can have its prebinding redone. Used only when MH_PREBEOUND is not set.
    allmodsbound: bool = false, // Indicates that this binary binds to all two-level namespace modules of its dependent libraries. Used only when MH_PREBINDABLE and MH_TWOLEVEL are set
    subsections_via_symbols: bool = false, // The sections of the object file can be divided into individual blocks. These blocks are dead-stripped if they are not used by other code. 
    canonical: bool = false, // This file has been canonicalized by unprebinding—clearing prebinding information from the file. See the redo_prebinding man page for details.
    weak_defines: bool = false,
    binds_to_weak: bool = false,
    allow_stack_execution: bool = false,
    root_safe: bool = false,
    setuid_safe: bool = false,
    no_reexported_dylibs: bool = false,
    pie: bool = false,  // OS will load the main executable at a random address. Only used on execute filetypes.
    dead_strippable_dylib: bool = false,
    has_tlv_descriptors: bool = false,
    no_heap_execution: bool = false,
    app_extension_safe: bool = false,
    nlist_outofsync_with_dyldinfo: bool = false,
    sim_support: bool = false,
    dylib_in_cache: bool = false,
    _: u3 = 0, // pad to 32 bits
};


const LoadCommand = packed struct {
    cmd: Command,
    cmdsize: u32,
};

const LC_REQ_DYLD = 0x80000000;

const Command = enum(u32) {
    lc_segment = 0x1,   // Segment of this file to be mapped
    lc_symtab = 0x2,    // Link-edit stab symbol table info
    lc_symseg = 0x3,    // Link-edit gdb symbol table info (obsolete)
    lc_thread = 0x4,    // thread
    lc_unixthread = 0x5,    // unix thread (includes a stack)
    lc_loadfvmlib = 0x6,    // load a specified fixed VM shared library
    lc_idfvmlib = 0x7,  // fixed VM shared library identification
    lc_ident = 0x8, // object identification info (obsolete)
    fvmfile = 0x9,
    prepage = 0xa,
    dysymtab = 0xb,
    load_dylib = 0xc,
    id_dylib = 0xd,
    load_dylinker = 0xe,
    id_dylinker = 0xf,
    prebound_dylib = 0x10,
    routines = 0x11,
    sub_framework = 0x12,
    sub_umbrella = 0x13,
    sub_client = 0x14,
    sub_library = 0x15,
    twolevel_hints = 0x16,
    prebind_cksum = 0x17,
    load_weak_dylib = (0x18 | LC_REQ_DYLD),
    segment_64 = 0x19,
    routines_64 = 0x1a,
    uuid = 0x1b,
    rpath = (0x1c | LC_REQ_DYLD),
    code_signature = 0x1d,
    segment_split_info = 0x1e,
    reexport_dylib = (0x1f | LC_REQ_DYLD),
    lazy_load_dylib = 0x20,
    encryption_info = 0x21,
    dyld_info = 0x22,
    dyld_info_only = (0x22 | LC_REQ_DYLD),
    load_upward_dylib = (0x23 | LC_REQ_DYLD),
    version_min_macosx = 0x24,
    version_min_iphoneos = 0x25,
    function_starts = 0x26,
    dyld_environment = 0x27,
    main = (0x28 | LC_REQ_DYLD),
    data_in_code = 0x29,
    source_version = 0x2A,
    dylib_code_sign_drs = 0x2B,
    encryption_info_64 = 0x2C,
    linker_option = 0x2D,
    linker_optimization_hint = 0x2E,
    version_min_tvos = 0x2F,
    version_min_watchos = 0x30,
    note = 0x31,
    build_version = 0x32,
    dyld_exports_trie = (0x33 | LC_REQ_DYLD),
    dyld_chained_fixups = (0x34 | LC_REQ_DYLD),
    fileset_entry = (0x35 | LC_REQ_DYLD),
};

// Extern - to support features like segname.
const SegmentCommand64 = extern struct {
    cmd: Command,   // LC_SEGMENT_64
    cmdsize: u32,  // includes sizeof section_64 structs
    segname: [16]u8,   // segment name
    vmaddr: u64, // memory address of this segment (irrelevant in file. Valid in memory)
    vmsize: u64, // memory size of this segment
    fileoff: u64, // file offset of this segment 
    filesize: u64, // amount to map from the file
    maxprot: VmProt, // maximum VM protection
    initprot: VmProt, // initial VM protection
    nsects: u32, // number of sections in segment
    flags: SegmentCommandFlags, // flags
};

const VmProt = packed struct(u32) {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    _: u29 = 0, // pad to 32 bits  
};

const SegmentCommandFlags = packed struct(u32) {
    highvm: bool=false, //  the file contents for this segment is for the high part of the VM space, the low part is zero filled (for stacks in core files)
    fvmlib: bool=false, // this segment is the VM that is allocated by a fixed VM library, for overlap checking in the link editor
    norelocation: bool=false, // this segment has nothing that was relocated in it and nothing relocated to it, that is it maybe safely replaced without relocation
    protected_version_1: bool=false, // This segment is protected. If the segment starts at file offset 0, the first page of the segment is not protected. All other pages of the segment are protected. The first page of the segment contains the mach_header and load commands of the object file that starts at file offset 0.
    read_only: bool=false, // This segment is made read-only after fixups.
    _: u27=0, // pad to 32 bits
};

const Section64 = packed struct {
    sectname: [16]u8,
    segname: [16]u8,
    addr: u64,
    size: u64,
    offset: u32,
    section_align: u32, // "align" in c, but it's a reserved word in zig.
    reloff: u32,
    nreloc: u32,
    flags: u32,
    reserved1: u32,
    reserved2: u32,
    reserved3: u32,
};


const std = @import("std");

fn padName(name: []const u8) [16]u8 {
    // Zero pad the name to a fixed length.
    // Probably an easier way to do this...
    var ret: [16]u8 = undefined;
    for (ret, 0..) |_, i| {
        ret[i] = 0;
    }
    for (name, 0..) |c, i| {
        ret[i] = c;
    }
    return ret;
}



pub fn emitBinary() !void {

    const header = MachHeader64 {
        .magic =MH_MAGIC,
        .cputype = CpuType.arm64,
        .cpusubtype=0,
        .filetype=Filetype.execute,
        .ncmds=15,
        .sizeofcmds=688,        // 
        .flags=Flags {
            .noundefs=true,
            .dyldlink=true,
            .twolevel=true,
            .pie=true
        },
    };
    //85000000 00000AFF

    // Segment 64 - 0x19
    const command = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = 72,
        .segname = padName("__PAGEZERO"),
        .vmaddr = 0,
        .vmsize = 0x100000000,
        .fileoff = 0,
        .filesize = 0,
        .maxprot = VmProt {},
        .initprot = VmProt {},
        .nsects=0,
        .flags=SegmentCommandFlags{}
    };

    const file = try std.fs.cwd().createFile(
        "out.bin",
        .{ .read = true },
    );

    defer file.close();

    const writer = file.writer();
    // defer writer.flush();

    // try writer.writeAll(&header, @sizeOf(header));
    try writer.writeStruct(header);
    try writer.writeStruct(command);
}


pub fn main() !void {
    // const args = try std.process.argsAlloc(std.heap.page_allocator);
    // defer std.process.argsFree(std.heap.page_allocator, args);

    // if (args.len != 2) {
    //     std.debug.print("Usage: Former <filename>\n", .{});
    //     return error.Unreachable;
    // }
    // // std.debug.print("Reading file: {s}\n", .{args});
    // const filename = args[1];
    // try reader.compile_file(filename);
    try emitBinary();
}
