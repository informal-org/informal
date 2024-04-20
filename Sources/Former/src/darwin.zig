const arm = @import("arm.zig");
const std = @import("std");
const codesig = @import("CodeSignature.zig");


const print = std.debug.print;


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

// Recommended setting up XMachOViewer when working on this.


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


const LoadCommand = extern struct {
    cmd: Command,
    cmdsize: u32,
    // padding: u32 = 0,       // Padding for 64 bit.
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

const LinkEditCommand = extern struct {
    // Structure for 
    // LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO, LC_FUNCTION_STARTS, 
    // LC_DATA_IN_CODE, LC_DYLIB_CODE_SIGN_DRS, LC_ATOM_INFO, LC_LINKER_OPTIMIZATION_HINT, 
    // LC_DYLD_EXPORTS_TRIE, or LC_DYLD_CHAINED_FIXUPS
    cmd: Command,
    cmdsize: u32,
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

const BuildVersionCommand = extern struct {
    cmd: Command = Command.build_version,
    cmdsize: u32,
    platform: u32,
    minos: u32,
    sdk: u32,
    ntools: u32,        // number of tool entries following this.
};

const BuildToolVersion = extern struct {
    tool: u32,    // Tool ID
    version: u32, // Version number of tool
};


// Option - version of the sources used to build the binary.
const SourceVersionCommand = extern struct {
    cmd: Command = Command.source_version,
    cmdsize: u32=16,
    version: u64=0, // A.B.C.D.E packed as a24.b10.c10.d10.e10 
};


const EntryPointCommand = extern struct {
    cmd: Command = Command.main,
    cmdsize: u32=24,
    entryoff: u64, // file (__TEXT) offset of main()
    stacksize: u64, // If not zero, initialize stack size for the main thread.
};

const LinkEditDataCommand = extern struct {
    cmd: Command,
    cmdsize: u32,
    dataoff: u32,
    datasize: u32,
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

// Is this backwards?
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



pub fn emitBinary() !void {
    const file = try std.fs.cwd().createFile(
        "out.bin",
        .{ .read = true },
    );


    defer file.close();
    const writer = file.writer();
    var totalSize: u64 = 0;

    // Total of each header size. + 16 for magic header (in bytes)
    const header_size_of_cmds = 0x298;
    // totalSize += header_size_of_cmds;
    const header = MachHeader64 {
        .magic =MH_MAGIC,
        .cputype = CpuType.arm64,
        .cpusubtype=0,
        .filetype=Filetype.execute,
        .ncmds=14,
        .sizeofcmds=header_size_of_cmds,
        .flags=Flags {
            .noundefs=true,     // Everything's statically linked.
            .pie=true,           // Address space randomization
            .dyldlink=true,     // Dynamic linker
            .twolevel=true,     // Two-level namespace
        },
    };
    try writer.writeStruct(header);
    totalSize += 32;    // 8 32 bit entries at 4 bytes each = 32.
    // Beware: Emits 00000AFF if you use zig packed struct rather than c-compatible extern struct.

    // Segment 64 - 0x19
    // ------------------------ Commands ------------------------
    const segment_pagezero = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = 0x48, // Total number of bytes for this segment + its sub-sections.
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
    try writer.writeStruct(segment_pagezero);
    totalSize += segment_pagezero.cmdsize;

    const segment_text = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = 0xe8,
        .segname = padName("__TEXT"),
        .vmaddr = 0x100000000,
        .vmsize = 0x4000,
        .fileoff = 0,
        .filesize = 0x4000,
        .maxprot = VmProt_ReadExec,
        .initprot = VmProt_ReadExec,
        .nsects=2,  // text, unwind info.
        .flags=SegmentCommandFlags{}
    };
    try writer.writeStruct(segment_text);
    totalSize += segment_text.cmdsize;

    // The entire thing has to be page-size aligned.
    // So text-size is 16KiB - the header size?
    const text_size = 0x3f90;    // 3ff0
    const text_addr = 0x100000000 + text_size;
    const section_text = Section64 {
        .sectname = padName("__text"),
        .segname = padName("__TEXT"),
        .addr = text_addr,
        .size = 0xc,    // 13
        .offset=text_size,
        .section_align=0x4, // 2^4 = 16 byte align.
        .reloff=0,
        .nreloc=0,
        .flags = SectionFlags{
            .attributes = SectionAttributes {
                .pure_instructions=true,
                .some_instructions=true
            }
        },
    };
    // 80000400
    try writer.writeStruct(section_text);
    totalSize += section_text.size;
    // Total size already included in above.?

    const section_unwind_info = Section64 {
        .sectname = padName("__unwind_info"),
        .segname = padName("__TEXT"),
        .addr = 0x100000000 + 0x3f90 + @as(u64, section_text.size),
        .size = 0x58,   // 88
        .offset=@truncate(text_size + section_text.size),
        .section_align=0x2, // 2^2 = 8 byte align.
        .reloff=0,
        .nreloc=0,
        .flags = SectionFlags{
            .attributes = SectionAttributes {}
        },
    };
    try writer.writeStruct(section_unwind_info);
    totalSize += section_unwind_info.size;


    const segment_linkedit = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = 0x48,   // Size of this command header.
        .segname = padName("__LINKEDIT"),
        .vmaddr = 0x100000000 + 0x4000,          // + previous command's size.
        .vmsize = 0x4000,
        .fileoff = 0x4000,      // + previous command's fileoff.
        .filesize = 0x1c8,    // 456 - Where does this come from?
        .maxprot = VmProt_ReadOnly,
        .initprot = VmProt_ReadOnly,
        .nsects=0,
        .flags=SegmentCommandFlags{}
    };
    try writer.writeStruct(segment_linkedit);
    totalSize += segment_linkedit.cmdsize;

    // ------------------------ Commands ------------------------
    const cmd_dyld_chained_fixups = LinkEditCommand {
        .cmd = Command.dyld_chained_fixups,
        .cmdsize = 0x10,
        .dataoff = 0x4000,  // 
        .datasize = 0x38,   // 56
    };
    try writer.writeStruct(cmd_dyld_chained_fixups);
    totalSize += cmd_dyld_chained_fixups.cmdsize;
    

    const cmd_dyld_exports_trie = LinkEditCommand {
        .cmd = Command.dyld_exports_trie,
        .cmdsize = 0x10,
        .dataoff = 0x4038,  // + previous size
        .datasize = 0x30,
    };
    try writer.writeStruct(cmd_dyld_exports_trie);
    totalSize += cmd_dyld_exports_trie.cmdsize;

    const cmd_symtab = SymtabCommand {
        .cmd = Command.lc_symtab,
        .cmdsize = 0x18,
        .symoff=0x4070, // 70 = 38 + 30 -> align. 
        .nsyms=0x02,    // mh_execute_header and _main
        .stroff=0x4090, // 4020 + 70. 
        .strsize=0x20
    };
    try writer.writeStruct(cmd_symtab);
    totalSize += cmd_symtab.cmdsize;

    
    const cmd_dysymtab = DySymTabCommand {
        .cmdsize = 0x50,
        .ilocalsym=0,
        .nlocalsym=0,
        .iextdefsym=0,
        .nextdefsym=2,
        .iundefsym=2,
        .nundefsym=0,
    };
    try writer.writeStruct(cmd_dysymtab);
    totalSize += cmd_dysymtab.cmdsize;

    const cmd_load_dylinker = DylinkerCommand {
        .cmd = Command.load_dylinker,
        .cmdsize = 0x20, // includes path name size
        .name_offset = 0x0c,
    };
    try writer.writeStruct(cmd_load_dylinker);
    try writer.print("/usr/lib/dyld", .{});
    try writer.writeByteNTimes(0, 7);   // Alignment.
    totalSize += cmd_load_dylinker.cmdsize;
    

    const build_version = BuildVersionCommand {
        .cmdsize = 0x20,
        .platform = 1,
        .minos = 0xe0000,           // TODO: Make this dynamic - 14.0.0
        .sdk = 0,
        .ntools = 1,
    };
    try writer.writeStruct(build_version);
    // Tool version - we can output our own here.
    // LD = 3.
    const tool_version = BuildToolVersion {
        .tool = 3,              
        .version = 0x03fe0100,
    };
    try writer.writeStruct(tool_version);
    totalSize += build_version.cmdsize;

    const src_version = SourceVersionCommand{};
    try writer.writeStruct(src_version);
    totalSize += src_version.cmdsize;


    // Use LC Main instead of unix threadstate.
    const entry_point = EntryPointCommand {
        .entryoff = text_size,
        .stacksize = 0,
    };
    try writer.writeStruct(entry_point);
    totalSize += entry_point.cmdsize;


    const function_starts = LinkEditCommand {
        .cmd = Command.function_starts,
        .cmdsize = 0x10,
        .dataoff = 0x4068,
        .datasize = 0x08,
    };
    try writer.writeStruct(function_starts);
    totalSize += function_starts.cmdsize;


    const dice = LinkEditDataCommand {
        .cmd = Command.data_in_code,
        .cmdsize = 0x10,
        .dataoff = 0x4070,
        .datasize = 0x00,
    };
    try writer.writeStruct(dice);
    totalSize += dice.cmdsize;

    const signature = LinkEditDataCommand {
        .cmd = Command.code_signature,
        .cmdsize = 0x10,
        .dataoff = 0x40b0,
        .datasize = 0x118
    };
    try writer.writeStruct(signature);
    totalSize += signature.cmdsize;
    

    // const unix_threadstate = ThreadStateCommand {
    //     .cmdsize = 0x120,
    //     .flavor = 0x06, // ?
    //     .count = 0x44
    // };
    // try writer.writeStruct(unix_threadstate);
    // totalSize += unix_threadstate.cmdsize;

    // const arm_thread_state_data = ArmThreadState {
    //     .pc = text_addr
    // };
    // try writer.writeStruct(arm_thread_state_data);
    // totalSize - included in above
    
    // Padding for 16kb page alignment. 
    // Total binary size = 0x4040 = 16448 = 16KB + 64 magic byte header.
    // Total remaining bytes at this point:
    // 2^14 - sum of all the header sizes(688). = x3D50
    // Then fill the bottom with contents.
    // Generate 15696 bits of padding. 1962 bytes.
    // const padding_size = 0x3D50;
    // const padding : [padding_size]u8 = undefined; 
    // @memset(&padding, 0);
    // try writer.write(padding);
    // Probably a better way to do this...
    // for(0..0x3D50) |_| {
    //     try writer.writeByte(0);
    // }

    const instrSize: u32 = 0x50; // instructions and symbol table.

    const finalExecSize: u32 = 0x4040;   // 2^16 + 64KB.

    // The count is still off by 4 bytes... not sure where that's coming from...
    const paddingSize: u64 = finalExecSize - totalSize - instrSize + 4;

    // totalSize = 736
    // header size of cmds = 704
    print("paddingSize {d} {d} {d}", .{totalSize, paddingSize, header_size_of_cmds});
    
    // Counting everything - total size = 1408
    // Without header = 704 - bit too much padding.
    // Just header = 
    try writer.writeByteNTimes(0, paddingSize);  // 15624
    
    
    // -------------------- Assembly --------------------
    // Assembly
    // MOVZ x0, #42     ;; Load constant
    try writer.writeStruct(arm.MOVW_IMM {
        .opc= arm.MOVW_IMM.OpCode.MOVZ,
        .imm16= 42,
        .rd=arm.Reg.x0,
    });

    // MOVZ x16, #1     ;; Load syscall #1 - exit - to ABI syscall register.
    try writer.writeStruct(arm.MOVW_IMM {
        .opc= arm.MOVW_IMM.OpCode.MOVZ,
        .imm16= 1,
        .rd=arm.Reg.x16,
    });

    // Syscall - exit 42 (so we can read the code out from bash).
    try writer.writeStruct(arm.SVC { .imm16 = arm.SVC.SYSCALL });


    // -------------------- Unwind info --------------------
    const unwind_info = [_]u8{0x01, 0x00, 0x00, 0x00, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x90, 0x3F, 0x00, 0x00, 0x40, };
    const unwind2 = [_]u8{0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x9C, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0C, 0x00, 0x01, 0x00, 0x10, 0x00, 0x01};

    // Loop and write each byte.
    for (unwind_info) |byte| {
        try writer.writeByte(byte);
    }
    for (unwind2) |byte| {
        try writer.writeByte(byte);
    }

    try writer.writeByteNTimes(0, 25);
    
    // try writer.write(unwind_info2);

    // Chained fixups
    const chained_fixups = DyldChainedFixup {
        .fixups_version = 0,
        .starts_offset = 0x20,        // 0x4068
        .imports_offset = 0x30,       // 0x4070
        .symbols_offset = 0x30,       // 0x4090
        .imports_count = 0,             // 2
        .imports_format = 0x01,         // 1 = chained import
        .symbols_format = 0,
    };
    try writer.writeStruct(chained_fixups);
    try writer.writeByteNTimes(0, 4);   // till it reached starts_offset.

    // dyld chained starts
    const chained_starts = DyldChainedStarts {
        .seg_count = 3,
        .seg_info_offset = 0,
    };
    try writer.writeStruct(chained_starts);
    // 2x4 for starts. 2 x4 for imports
    try writer.writeByteNTimes(0, 16);

    // dyld - trie.
    const dytrying = [_]u8{0x00 , 0x01 , 0x5F ,0x00, 0x12 , 0x00 , 0x00 ,0x00, 0x00 , 0x02 , 0x00 ,0x00, 0x00 , 0x03 , 0x00 ,0x90, 0x7F , 0x00 , 0x00 ,0x02, 0x5F , 0x6D , 0x68 ,0x5F, 0x65 , 0x78 , 0x65 ,0x63, 0x75 , 0x74 , 0x65 ,0x5F, 0x68 , 0x65 , 0x61 ,0x64, 0x65 , 0x72 , 0x00 ,0x09, 0x6D , 0x61 , 0x69 ,0x6E, 0x00, 0x0D, 0x00, 0x00};
    for (dytrying) |byte| {
        try writer.writeByte(byte);
    }

    // function starts
    const funstarts = [_]u8{0x90, 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
    for (funstarts) |byte| {
        try writer.writeByte(byte);
    }


    // -------------------- Symbol Table --------------------

    // TODO: Is this always a fixed size or variable to some alignment?
   // try writer.writeByteNTimes(0, 4);

    // Symbol table


// 0000 0000 2000 0000 3000 0000 3000 0000 
// 0000 0000 0100 0000 0000 0000 0000 0000
// 0300 0000 0000 0000 0000 0000 0000 0000
// 0000 0000 0000 0000 0001 5f00 1200 0000
// 0002 0000 0003 0090 7f00 0002 5f6d 685f
// 6578 6563 7574 655f 6865 6164 6572 0009
// 6d61 696e 000d 0000 907f 0000 0000 0000


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
        .stringIndex = 22, // 2 + 19 + 1 (null byte) for prev symbol. 
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

    // page size = 1
    // var sig = codesig.CodeSignature.init(1);
    // sig.code_directory.ident = "minimal"; // fs.path.basename(full_out_path);

    // try codesig.writeAdhocSignature(&sig, .{
    //     .file = file,
    //     .exec_seg_base = section_text.offset,        // Text segment offset
    //     .exec_seg_limit = section_text.size,       // 
    //     .file_size = 0x118,        // linkedit data size.
    //     .dylib = false,
    // }, writer);

    try codesig.sign(writer);


    // try writeAdhocSignature
    // // Fixed size or alignment?
    // try writer.writeByteNTimes(0, 4);   
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
