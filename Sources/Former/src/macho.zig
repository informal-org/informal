// Mach-O executable file format for Apple systems.
// 
// General layout:
// Mach Header - Architecture, # of commands and size of commands.
// Commands - Other compilers seem to emit all 15 commands, even empty...
// Segments for each command. Specifies # of sections.
// Sections for each segment.
// A lot of zeroes for page alignment.
// Actual code section
// Symbol tables
// Code Signature (required for macOS 11+ and AppleSilicon)
// 
// This implementation only supports 64 bit ARM.
// Our binaries are mostly static and standalone. However, we have to enable some of the dynamic linking features for compatibility.
// Otherwise Mac's System Integrity Protection will terminate the executable.
// 
// I recommend setting up XMachOViewer when working on this. It'll make your life a whole lot easier.
// ObjDump and HexFiend are also indispensible.
// 
// Reference:
// /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach-o/loader.h
// Thanks to: https://gpanders.com/blog/exploring-mach-o-part-2/ 
// 
// Coding convention: 
// Use hex for any numeric values which will appear in the output file.
// It'll help when comparing against a hex dump for debugging.


const arm = @import("arm.zig");
const std = @import("std");
const mem = std.mem;
const codesig = @import("CodeSignature.zig");
const print = std.debug.print;
const Allocator = std.mem.Allocator;


// 32bit = 0xfeedface :)
const MH_MAGIC = 0xfeedfacf;
const CPU_ARCH_ABI64 = 0x01000000;

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


const MachHeader64 = packed struct {
	magic: u32 = MH_MAGIC,		        // mach magic number identifier */
	cputype: CpuType = CpuType.arm64,	    // cpu specifier */
	cpusubtype: u32 = 0,	    // machine specifier */
    filetype: Filetype = Filetype.execute,	    // type of file */
	ncmds: u32,		        // number of load commands */
	sizeofcmds: u32,	    // the size of all the load commands */
	flags: HeaderFlags = .{
        .noundefs=true,     // Everything's statically linked.
        .pie=true,          // Address space randomization
        .dyldlink=true,     // Dynamic linker
        .twolevel=true,     // Two-level namespace        
    },		    // flags */
    reserved: u32 = 0       // padding.

    // Beware: Emits 00000AFF if you use zig packed struct rather than c-compatible extern struct.
};
const SIZE_MACH_HEADER = 32;


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
const HeaderFlags = packed struct {
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


const LoadCommand = extern struct {
    cmd: Command,
    cmdsize: u32,
};



// Extern - to support features like segname.
// 72 bytes.
const SegmentCommand64 = extern struct {
    cmd: Command = Command.segment_64,   // LC_SEGMENT_64
    cmdsize: u32,  // includes sizeof section_64 structs. Total number of bytes for this segment + its sub-sections
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
const SIZE_SEGMENT_COMMAND = 0x48;

const LinkEditCommand = extern struct {
    // Structure for 
    // LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO, LC_FUNCTION_STARTS, 
    // LC_DATA_IN_CODE, LC_DYLIB_CODE_SIGN_DRS, LC_ATOM_INFO, LC_LINKER_OPTIMIZATION_HINT, 
    // LC_DYLD_EXPORTS_TRIE, or LC_DYLD_CHAINED_FIXUPS
    cmd: Command,
    cmdsize: u32 = 0x10,
    // 4 fields are defined in the struct, but other compilers seem to emit just 3?
    dataoff: u32,
    datasize: u32,
};


// Offsets and dizes of the link-edit "stab" style symbol table.
const SymtabCommand = extern struct {
    cmd: Command = Command.lc_symtab, 
    cmdsize: u32, // Sizeof(struct symtab_command)
    symoff: u32, // symbol table offset
    nsyms: u32, // number of symbol table entries
    stroff: u32, // string table offset
    strsize: u32, // string table size in bytes.
};

// Symbol table entries are in nlist_64 and stab.


const NList64 = extern struct {
    stringIndex: u32, // index into the string table
    nType: NType, // type flag
    sectionNumber: u8 = 0, // section number or NO_SECT (0)
    description: u16, // see <mach-o/stab.h>
    value: u64, // value of this symbol (or stab offset)
};

const NType = packed struct(u8) {
    isExternal: bool = false,
    symbolType: SymType, // mask for the type bits
    isPrivateExternal: bool = false,
    stab: u3 = 0, // If any bit set, then a symbolic debugging entry.

    // Defined as 4 bit constant in nlist.h, but really just a mask - LSB is isExternal
    pub const SymType = enum(u3) {
        undef = 0,    // undefined - n_sects == NO_SECT
        abs = 0b1,      // absolute defined. n_sect == no_sect. 0x1
        sect = 0b111,     // defined in section number n_sect. 0xc
        prebound = 0b110, // prebound undefined (defined in a dylib). 0xe
        indirect = 0b101, // indirect
    };
};

const NDEF_REFERENCED_DYNAMICALLY = 0x0010;




// Second set of symbolic information for dynamic link loader.
// Original set of symbols from symtab symbols and strings table must also be present here.
// Organized into three groups:
// Local symbols - static and debugging symbols - grouped by module.
// Defined external symbols - grouped by module (sorted by name if not lib)
// undefined external symbols (sorted by name if MH_BINDATALOAD  is not set)
// 
// Contains the offsets and sizes of the following new symbol tables
// table of contents
// module table
// reference symbol table
// indirect symbol table.
// First 3 only present if this is a dynamically linked shared lib.
const DySymTabCommand = extern struct {
    cmd: Command = Command.dysymtab,
    cmdsize: u32,

    ilocalsym: u32, // index to local symbols
    nlocalsym: u32, // number of local symbols
     // index and number of externally defined symbols
    iextdefsym: u32 = 0,
    nextdefsym: u32,
    // undefined symbols
    iundefsym: u32,
    nundefsym: u32 = 0,
    // Table of contents to help find which module a symbol is defined in.
    // Only exists in shared libs.
    tocoff: u32 = 0,
    ntoc: u32 = 0,
    // support dynamic binding of modules / whole object files. 
    // Reflects module file symbol was created from.
    modtaboff: u32=0,
    nmodtab: u32=0,
    // Each module indicates external refs each mod makes (defined and undefined)
    extrefsymoff: u32=0,
    nextrefsyms: u32=0,
    // Symbol pointers and routing stubs.
    // Ordered to match entries.
    indirectsymoff: u32=0,
    nindirectsyms: u32=0,
    // Relocatable modules
    extreloff: u32=0,
    nextrel: u32=0,
    // Local relocation entries.
    locreloff: u32=0,
    nlocrel: u32=0
};


const DylinkerCommand = extern struct {
    cmd: Command = Command.load_dylinker,
    cmdsize: u32,    // includes path name size.
    name_offset: u32 = 0x0c,      // offset to path
};

const PLATFORM_MACOS = 1;
const BuildVersionCommand = extern struct {
    cmd: Command = Command.build_version,
    cmdsize: u32 = 0x18, // 4 * 6 32 bit fields = 24 bytes for build version command. 
    // Using too old of a version has caused problems for the Go linker. 
    // 0xe0000 = 14.0.0
    platform: u32 = PLATFORM_MACOS,
    minos: u32 = (11<<16 | 0<<8 | 0<<0), // 11.0.0 - 
    sdk: u32 = 0,       // SDK version
    // number of tool entries following this (i.e. linker version)
    // Command size should be increased +8  for each build tool after.
    ntools: u32 = 0,
};

const BuildToolVersion = extern struct {
    tool: u32,    // Tool ID
    version: u32, // Version number of tool
};


// Option - version of the sources used to build the binary.
const SourceVersionCommand = extern struct {
    cmd: Command = Command.source_version,
    cmdsize: u32=0x10,
    version: u64=0, // A.B.C.D.E packed as a24.b10.c10.d10.e10 
};


const EntryPointCommand = extern struct {
    cmd: Command = Command.main,
    cmdsize: u32=0x18,
    entryoff: u64, // file (__TEXT) offset of main()
    stacksize: u64, // If not zero, initialize stack size for the main thread.
};

const LinkEditDataCommand = extern struct {
    cmd: Command,
    cmdsize: u32 = 0x10,
    dataoff: u32,  // File offset of the data in the linkedit section
    datasize: u32,  // File size of the data in the linkedit section.
};


const DataInCodeEntry = extern struct {
    offset: u32,    // from mach_header to start of data range.
    length: u16,    // number of bytes in data range
    kind: DiceKind,

    const DiceKind = enum(u16) {
        data = 0x0001,
        jump_table8 = 0x0002,
        jump_table16 = 0x0003,
        jump_table32 = 0x0004,
        abs_jump_table32 = 0x0005,
    };
};


// struct dyld_chained_fixups_header
// {
//     uint32_t    fixups_version;    // 0
//     uint32_t    starts_offset;     // offset of dyld_chained_starts_in_image in chain_data
//     uint32_t    imports_offset;    // offset of imports table in chain_data
//     uint32_t    symbols_offset;    // offset of symbol strings in chain_data
//     uint32_t    imports_count;     // number of imported symbol names
//     uint32_t    imports_format;    // DYLD_CHAINED_IMPORT*
//     uint32_t    symbols_format;    // 0 => uncompressed, 1 => zlib compressed
// };

const DyldChainedFixup = extern struct {
    fixups_version: u32, // 0
    starts_offset: u32,  // offset of dyld_chained_starts_in_image in chain_data
    imports_offset: u32, // offset of imports table in chain_data
    symbols_offset: u32, // offset of symbol strings in chain_data
    imports_count: u32,  // number of imported symbol names
    imports_format: u32, // DYLD_CHAINED_IMPORT*
    symbols_format: u32, // 0 => uncompressed, 1 => zlib compressed
};

const DyldChainedStarts = extern struct {
    seg_count: u32,
    seg_info_offset: u32,       // [1]
};


const DyldChainedImport = extern struct {

};


// Machine-specific data structure.
const ThreadStateCommand = extern struct {
    cmd: Command = Command.lc_unixthread,
    cmdsize: u32,

    flavor: u32,    // flavor of thread state
    count: u32,     // count of u32s in thread state.
//    state: ArmThreadState,
};

const ArmThreadState = extern struct {
    x0: u64=0,
    x1: u64=0,
    x2: u64=0,
    x3: u64=0,
    x4: u64=0,
    x5: u64=0,
    x6: u64=0,
    x7: u64=0,
    x8: u64=0,
    x9: u64=0,
    x10: u64=0,
    x11: u64=0,
    x12: u64=0,
    x13: u64=0,
    x14: u64=0,
    x15: u64=0,
    x16: u64=0,
    x17: u64=0,
    x18: u64=0,
    x19: u64=0,
    x20: u64=0,
    x21: u64=0,
    x22: u64=0,
    x23: u64=0,
    x24: u64=0,
    x25: u64=0,
    x26: u64=0,
    x27: u64=0,
    x28: u64=0,
    fp: u64=0,
    lr: u64=0,
    sp: u64=0,
    pc: u64, // Should be initialized to the address of __text.
    cpsr: u64=0,        // 32?
    pad: u64=0
};


const VmProt = packed struct(u32) {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    _: u29 = 0, // pad to 32 bits  
};

const VmProt_ReadExec = VmProt {
    .read=true,
    .execute=true
};

const VmProt_ReadOnly = VmProt {
    .read=true,
};

const SegmentCommandFlags = packed struct(u32) {
    highvm: bool=false, //  the file contents for this segment is for the high part of the VM space, the low part is zero filled (for stacks in core files)
    fvmlib: bool=false, // this segment is the VM that is allocated by a fixed VM library, for overlap checking in the link editor
    norelocation: bool=false, // this segment has nothing that was relocated in it and nothing relocated to it, that is it maybe safely replaced without relocation
    protected_version_1: bool=false, // This segment is protected. If the segment starts at file offset 0, the first page of the segment is not protected. All other pages of the segment are protected. The first page of the segment contains the mach_header and load commands of the object file that starts at file offset 0.
    read_only: bool=false, // This segment is made read-only after fixups.
    _: u27=0, // pad to 32 bits
};

// 80 bytes
const Section64 = extern struct {
    sectname: [16]u8,
    segname: [16]u8,
    addr: u64,
    size: u64,
    offset: u32,
    // "align" in c, but it's a reserved word in zig.
    // Aligns to 2^section_align
    section_align: u32,
    reloff: u32,
    nreloc: u32,
    flags: SectionFlags,
    reserved1: u32=0,
    reserved2: u32=0,
    reserved3: u32=0,
};

const SECTION_ATTRIBUTES_USR = 0xff000000;
const SECTION_ATTRIBUTES_SYS = 0x00ffff00;

const SectionAttributes = packed struct(u24) {
    loc_reloc: bool=false,
    ext_reloc: bool=false,
    some_instructions: bool=false,
    system: u14=0,
    debug: bool=false,
    self_modifying_code: bool=false,
    live_support: bool=false,
    no_dead_strip: bool=false,
    strip_static_syms: bool=false,
    no_toc: bool=false,
    pure_instructions: bool=false,

    // pure_instructions: bool=false, // 0x80000000
    // no_toc: bool=false,            // 0x40000000
    // strip_static_syms: bool=false, // 0x20000000
    // no_dead_strip: bool=false,     // 0x10000000
    // live_support: bool=false,      // 0x08000000
    
    // self_modifying_code: bool=false,//0x04000000
    // debug: bool=false,             // 0x02000000. All must be debug if one is. DWARF debug info.
    // system: u14=0,  // ?
    // some_instructions: bool=false,
    // ext_reloc: bool=false,
    // loc_reloc: bool=false
};


const SectionType = enum(u8) {
    regular = 0x0, // regular section
    zerofill = 0x1, // zero fill on demand section
    cstring_literals = 0x2, // section with only literal C strings
    four_byte_literals = 0x3,  // section with only 4 byte literals
    eight_byte_literals = 0x4,  // section with only 8 byte literals
    literal_pointers = 0x5, // section with only pointers to literals
};

const SectionFlags = packed struct(u32) {
    section_type: SectionType = SectionType.regular,
    attributes: SectionAttributes,
};


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


pub const MachOLinker = struct {
    const Self = @This();

    linkOffset: u32,    // Next unpopulated offset into the link section.
    vmAddr: u64,        // VM address offset as each thing is populated.
    sectionAddr: u64,
    sectionOffset: u32,
    fileOff: u64,
    numCommands: u32,
    numSections: u32,
    headerSize: u32,

    totalLinkEditSize: u32,

    cmdText: SegmentCommand64 = undefined,
    sectionText: Section64 = undefined,
    cmdLinkEdit: SegmentCommand64 = undefined,

    // Header is buffered until the entire header is available so we can calculate the size.
    headerBuffer: std.ArrayList(u8),
    // Some segments have multiple sections. 
    sectionBuffer: std.ArrayList(u8),
    allocator: Allocator,


    pub fn init(allocator: Allocator) Self {
        return Self{
            .linkOffset = 0,
            .vmAddr = 0,
            .sectionAddr = 0,
            .sectionOffset = 0,
            .fileOff = 0,
            .numCommands = 0,
            .numSections = 0,
            .headerSize = 0,
            .totalLinkEditSize = 0,
            .allocator = allocator,
            .headerBuffer = std.ArrayList(u8).init(allocator),
            .sectionBuffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.headerBuffer.deinit();
    }

    const DEFAULT_SEGMENT_VM_SIZE = 0x4000;       // In-memory size of this segment.
    const SEGMENT_FILE_MAP_SIZE = 0x4000;         // How much to map from file for this segment.
    const VM_BASE_ADDR = 0x100000000;

    const SEG_PAGE_ZERO = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = SIZE_SEG_PAGE_ZERO, // Total number of bytes for this segment + its sub-sections.
        .segname = padName("__PAGEZERO"),
        .vmaddr = 0,
        .vmsize = VM_BASE_ADDR,
        .fileoff = 0,
        .filesize = 0,
        .maxprot = VmProt {}, // Any access to page zero should trap.
        .initprot = VmProt {},
        .nsects=0,
        .flags=SegmentCommandFlags{}
    };
    const SIZE_SEG_PAGE_ZERO = 0x48;    // 72

    fn emitCommand(self: *Self, writer: anytype, cmd: SegmentCommand64) !void {
        _ = writer;
        // try writer.writeStruct(cmd);
        try self.bufferHeaderCmd(std.mem.asBytes(&cmd));
        self.vmAddr = cmd.vmaddr + cmd.vmsize;
        self.fileOff = cmd.fileoff + cmd.filesize;
        print("Total size {d} - vmAddr {x} - Command: {any}\n", .{self.headerBuffer.items.len, self.vmAddr, cmd.cmd});
    }

    fn emitSection(self: *Self, writer: anytype, section: Section64) !void {
        _ = writer;
        // try writer.writeStruct(section);
        try self.sectionBuffer.appendSlice(std.mem.asBytes(&section));
        // self.totalSize += section.size;
        self.numSections += 1;
        self.sectionAddr = section.addr + section.size;
        self.sectionOffset = @truncate(section.offset + section.size);
        print("Total size {d} - Addr {x} - Section: {s}\n", .{self.headerBuffer.items.len, self.sectionAddr, section.sectname});
    }

    fn flushSegment(self: *Self, writer: anytype) !void {
        const cmdSize = @sizeOf(SegmentCommand64);  // 48
        self.cmdText = SegmentCommand64 {
            .cmd = Command.segment_64,
            .cmdsize = @truncate(cmdSize + self.sectionBuffer.items.len), // = 0xE8
            .segname = padName("__TEXT"),
            .vmaddr = self.vmAddr,      // 0x100000000
            .vmsize = DEFAULT_SEGMENT_VM_SIZE,
            .fileoff = self.fileOff,
            .filesize = SEGMENT_FILE_MAP_SIZE,  // 0x4000
            .maxprot = VmProt_ReadExec,
            .initprot = VmProt_ReadExec,
            .nsects=self.numSections,  // 2 - text, unwind info.
            .flags=SegmentCommandFlags{}
        };
        try self.emitCommand(writer, self.cmdText);
        try self.bufferHeaderBytes(self.sectionBuffer.items);
        self.sectionBuffer.clearAndFree();
    }

    fn emitLinkEditCommand(self: *Self, writer: anytype, cmd: Command, size: u32) !void {
        _ = writer;
        const link_edit = LinkEditCommand {
            .cmd = cmd,
            .cmdsize = 0x10,    // 16
            .dataoff = self.linkOffset,
            .datasize = size,
        };
        try self.bufferHeaderCmd(std.mem.asBytes(&link_edit));
        self.linkOffset = link_edit.dataoff + link_edit.datasize;
        self.totalLinkEditSize += link_edit.datasize;
        print("Total size {d} - Link Command: {any}\n", .{self.headerBuffer.items.len, cmd});
    }

    fn flushLinkEditSegment(self: *Self, writer: anytype, fileOff: u32, vmAddr: u64) !void {
        // The LinkEdit segment encompasses everything after the text section, until end of file.
        const linkEditSize = self.linkOffset - fileOff;     // Current link edit size vs section start.
        
        self.cmdLinkEdit = SegmentCommand64 {
            .cmd = Command.segment_64,
            .cmdsize = 0x48,   // 72 - Size of this command header.
            .segname = padName("__LINKEDIT"),
            .vmaddr = vmAddr,    // 0 + 0x4000
            .vmsize = DEFAULT_SEGMENT_VM_SIZE,
            .fileoff = fileOff,    // 0 + 0x4000
            .filesize = linkEditSize,      // 456 - 0x1c8. -80 to remove unwind. 0x178 without unwind?
            .maxprot = VmProt_ReadOnly,
            .initprot = VmProt_ReadOnly,
            .nsects=0,
            .flags=SegmentCommandFlags{}
        };
        try self.emitCommand(writer, self.cmdLinkEdit);
    }

    fn bufferHeaderBytes(self: *Self, bytes: []const u8) !void {
        try self.headerBuffer.appendSlice(bytes);
    }

    fn bufferHeaderAlignment(self: *Self, length: u64) !void {
        for (0..length) |_| {
            try self.headerBuffer.append(0);
        }
    }

    fn bufferHeaderCmd(self: *Self, bytes: []const u8) !void {
        try self.headerBuffer.appendSlice(bytes);
        self.numCommands += 1;
    }

    fn flushHeader(self: *Self, writer: anytype) !void {
        // Flush the header after all header sections have been buffered up.
        // Total header size and number of commands are known at this point.
        print("Total header size: {x}  Commands {d} \n", .{self.headerBuffer.items.len, self.numCommands});

        // Header size. +8 for self magic header size.
        const header = MachHeader64 {
            .ncmds=self.numCommands,
            .sizeofcmds=@truncate(self.headerBuffer.items.len + 8),    // +8 for magic header struct size.
        };
        // Mach Header - Size 32
        try writer.writeStruct(header);

        try writer.writeAll(self.headerBuffer.items);
        // Where the header section ends and zero padding begins.
        self.headerSize = @truncate(self.headerBuffer.items.len + SIZE_MACH_HEADER);
        self.headerBuffer.clearAndFree();
    }

    pub fn emitBinary(self: *Self) !void {
        const file = try std.fs.cwd().createFile(
            "out.bin",
            .{ .read = true },
        );

        defer file.close();
        const writer = file.writer();

        // const assembly_code_size = 0xC;     // 12   - TODO: Parametrize this.
        const num_instructions = 3;
        const assembly_code_size = 4 * num_instructions;
        
        // ------------------------ Commands ------------------------
        // Page zero - Size 0x48
        try self.emitCommand(writer, SEG_PAGE_ZERO);

        // --------------------- Segment TEXT ------------------------
        // Buffer up sub-section for TEXT segment.

        // Something's off with the alignment, -16 ensures text_offset + code size < 0x4000.
        // If we have unwind info, do 0x4000 - unwind_size - assembly_code_size - 16
        const text_offset = mem.alignBackward(u64, 0x4000 - assembly_code_size - 16, 16);
        
        print("Text offset: {x} \n", .{text_offset});
        const text_addr = VM_BASE_ADDR + text_offset;
        self.sectionText = Section64 {
            .sectname = padName("__text"),
            .segname = padName("__TEXT"),
            .addr = text_addr,
            .size = assembly_code_size,
            .offset=@truncate(text_offset),
            .section_align=4, // 2^4 = 16 byte align.
            .reloff=0,
            .nreloc=0,
            .flags = SectionFlags{
                .attributes = SectionAttributes {
                    .pure_instructions=true,
                    .some_instructions=true
                }
            },
        };
        // Section text's size is included in the segment size.
        try self.emitSection(writer, self.sectionText);
        
        try self.flushSegment(writer);


        // --------------------- Segment LINKEDIT ------------------------
        // Starts immediately after cmdText.
        const linkEditSectionStart: u32 = @truncate(self.fileOff);
        const linkEditVmAddr = self.vmAddr;
        self.linkOffset = linkEditSectionStart;

        const num_local_symbols = 0;
        const num_ext_def_symbols = 2;
        const cmd_dysymtab = DySymTabCommand {
            .cmdsize = 0x50,  // 80
            .ilocalsym=0,
            .nlocalsym=num_local_symbols,
            .iextdefsym=num_local_symbols,
            .nextdefsym=num_ext_def_symbols,
            .iundefsym=num_local_symbols + num_ext_def_symbols,
            .nundefsym=0,
        };
        try self.bufferHeaderCmd(std.mem.asBytes(&cmd_dysymtab));


        const dylinkPath = "/usr/lib/dyld";
        const dylinkContentSize = @sizeOf(DylinkerCommand) + dylinkPath.len;
        const dylinkSize = mem.alignForward(u32, dylinkContentSize, 8);
        const cmd_load_dylinker = DylinkerCommand {
            .cmd = Command.load_dylinker,
            .cmdsize = dylinkSize,
            .name_offset = 0xC,  // 12
        };
        try self.bufferHeaderCmd(std.mem.asBytes(&cmd_load_dylinker));
        try self.bufferHeaderBytes(dylinkPath);
        try self.bufferHeaderAlignment(dylinkSize - dylinkContentSize);
        
        
        // LC Main is preferred instead of unix threadstate on arm mac
        const entry_point = EntryPointCommand {
            .entryoff = self.sectionText.offset,
            .stacksize = 0,
        };
        try self.bufferHeaderCmd(std.mem.asBytes(&entry_point));

        const numSymbols = 2;
        // 2 bytes for string header. 0x20 0
        // __mh_execute_header: 19 + 1
        // _main: 5 + 1
        // Alignment.
        const strSize = mem.alignForward(u32, 20 + 6 + 2, 16);
        const cmd_symtab = SymtabCommand {
            .cmd = Command.lc_symtab,
            .cmdsize = 0x18,  // 24
            .symoff=self.linkOffset,
            .nsyms=numSymbols,    // mh_execute_header and _main
            .stroff=self.linkOffset + (numSymbols * @sizeOf(NList64)), // 16528 - 0x4020 + 0x70. 
            .strsize=strSize
        };
        try self.bufferHeaderCmd(std.mem.asBytes(&cmd_symtab));
        self.linkOffset = cmd_symtab.stroff + cmd_symtab.strsize;


        const signArgs = codesig.SignArgs {
            .numPages = 1,
            .identifier = "minimal",
            .overallBinCodeLimit = 0x40B0,   // 16560
            .execTextSegmentOffset = 0,
            .execTextSegmentLimit = 12
        };
        // Other compilers seem to align this size. i.e. 276 -> 280. But unaligned also works.
        try self.emitLinkEditCommand(writer, Command.code_signature, @truncate(codesig.estimateSize(signArgs)));
        try self.flushLinkEditSegment(writer, linkEditSectionStart, linkEditVmAddr);


        // ------------------------------------------------
        // End of header section.
        // ------------------------------------------------
        try self.flushHeader(writer);
        
        // ------------------------ Zero padding ------------------------
        // Pad zeros from end of header to beginning of text section.
        const paddingSize: u64 = text_offset - self.headerSize;

        print("paddingSize {d} {d} {d} \n", .{self.headerSize, self.headerBuffer.items.len, paddingSize});
        try writer.writeByteNTimes(0, paddingSize);


        // -------------------- Assembly --------------------
        // Assembly
        // MOVZ x0, #42     ;; Load constant
        try writer.writeStruct(arm.MOVW_IMM {
            .opc= arm.MOVW_IMM.OpCode.MOVZ,
            .imm16= 42,
            .rd=arm.Reg.x0,
        });

        // try writer.writeStruct(arm.MOVW_IMM {
        //     .opc= arm.MOVW_IMM.OpCode.MOVZ,
        //     .imm16= 40,
        //     .rd=arm.Reg.x5,
        // });

        // MOVZ x16, #1     ;; Load syscall #1 - exit - to ABI syscall register.
        try writer.writeStruct(arm.MOVW_IMM {
            .opc= arm.MOVW_IMM.OpCode.MOVZ,
            .imm16= 1,
            .rd=arm.Reg.x16,
        });

        // Syscall - exit 42 (so we can read the code out from bash).
        try writer.writeStruct(arm.SVC { .imm16 = arm.SVC.SYSCALL });

        // Zero pad for 16 byte alignment.
        const textPadding = 0x4000 - text_offset - assembly_code_size;
        try writer.writeByteNTimes(0, textPadding);
        
        // -------------------- Symbol Table --------------------

        // __mh_execute_header
        try writer.writeStruct(NList64 { 
            .stringIndex = 2, // . IDK why it's offset by 2...
            .nType = NType {
                .isExternal = true,
                .symbolType = NType.SymType.sect,
            },
            .sectionNumber = 1,
            .description = NDEF_REFERENCED_DYNAMICALLY,
            .value=0x100000000,     // Base VM addr,
        });

        // _main symbol
        try writer.writeStruct(NList64 { 
            .stringIndex = 22, // 2 + 19 ("__mh_execute_header") + 1 (null byte) for prev symbol. 
            .nType = NType {
                .isExternal = true,
                .symbolType = NType.SymType.sect,
            },
            .sectionNumber = 1,
            .description = 0,
            .value=text_addr,     // Start of main.
        });

        // String table
        try writer.writeByte(0x20);
        try writer.writeByte(0x00);
        try writer.print("__mh_execute_header", .{});
        try writer.writeByte(0);
        try writer.print("_main", .{});
        try writer.writeByte(0);
        try writer.writeByteNTimes(0, 4);


        try codesig.sign(writer, file, signArgs);

        // Indicates end of file.
        try writer.writeByteNTimes(0, 4);

    }
};



pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var linker = MachOLinker.init(gpa.allocator());
    defer linker.deinit();
    try linker.emitBinary();
}
