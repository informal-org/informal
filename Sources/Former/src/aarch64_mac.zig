
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


// Option - version of the sources used to build the binary.
const SourceVersionCommand = extern struct {
    cmd: Command = Command.source_version,
    cmdsize: u32=16,
    version: u64=0, // A.B.C.D.E packed as a24.b10.c10.d10.e10 
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
    const file = try std.fs.cwd().createFile(
        "out.bin",
        .{ .read = true },
    );

    defer file.close();
    const writer = file.writer();

    // Total of each header size. + 16 for magic header (in bytes)
    const header_size_of_cmds = 0x2c0;
    const header = MachHeader64 {
        .magic =MH_MAGIC,
        .cputype = CpuType.arm64,
        .cpusubtype=0,
        .filetype=Filetype.execute,
        .ncmds=7,
        .sizeofcmds=header_size_of_cmds,
        .flags=Flags {
            .noundefs=true,     // Everything's statically linked.
            .pie=true           // Address space randomization
        },
    };
    try writer.writeStruct(header);
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

    const segment_text = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = 0x98, // 152.
        .segname = padName("__TEXT"),
        .vmaddr = 0x100000000,
        .vmsize = 0x4000,
        .fileoff = 0,
        .filesize = 0x4000,
        .maxprot = VmProt_ReadExec,
        .initprot = VmProt_ReadExec,
        .nsects=1,
        .flags=SegmentCommandFlags{}
    };
    try writer.writeStruct(segment_text);

    // The entire thing has to be page-size aligned.
    // So text-size is 16KiB - the header size?
    const text_size = 16368;    // 3ff0
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

    // const section_unwind_info = Section64 {
    //     .sectname = padName("__unwind_info"),
    //     .segname = padName("__TEXT"),
    //     .addr = 0x100000000 + 16368 + @as(u64, section_text.size),
    //     .size = 0x58,   // 88
    //     .offset=@truncate(text_size + section_text.size),
    //     .section_align=0x2, // 2^2 = 8 byte align.
    //     .reloff=0,
    //     .nreloc=0,
    //     .flags = SectionFlags{
    //         .attributes = SectionAttributes {}
    //     },
    // };
    // try writer.writeStruct(section_unwind_info);


    const segment_linkedit = SegmentCommand64 {
        .cmd = Command.segment_64,
        .cmdsize = 0x48,   // Size of this command header.
        .segname = padName("__LINKEDIT"),
        .vmaddr = 0x100000000 + 0x4000,          // + previous command's size.
        .vmsize = 0x4000,
        .fileoff = 0x4000,      // + previous command's fileoff.
        .filesize = 0x40,    // 456 - Where does this come from?
        .maxprot = VmProt_ReadOnly,
        .initprot = VmProt_ReadOnly,
        .nsects=0,
        .flags=SegmentCommandFlags{}
    };
    try writer.writeStruct(segment_linkedit);

    // ------------------------ Commands ------------------------
    // const cmd_dyld_chained_fixups = LinkEditCommand {
    //     .cmd = Command.dyld_chained_fixups,
    //     .cmdsize = 0x10,
    //     .dataoff = 0x4000,  // 
    //     .datasize = 0x38,   // 56
    // };
    // try writer.writeStruct(cmd_dyld_chained_fixups);
    

    // const cmd_dyld_exports_trie = LinkEditCommand {
    //     .cmd = Command.dyld_exports_trie,
    //     .cmdsize = 0x10,
    //     .dataoff = 0x4038,  // + previous size
    //     .datasize = 0x30,
    // };
    // try writer.writeStruct(cmd_dyld_exports_trie);

    const cmd_symtab = SymtabCommand {
        .cmd = Command.lc_symtab,
        .cmdsize = 0x18,
        .symoff=0x4000,
        .nsyms=0x02,    // mh_execute_header and _main
        .stroff=0x4020,
        .strsize=0x20
    };
    try writer.writeStruct(cmd_symtab);

    
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

    const src_version = SourceVersionCommand{};
    try writer.writeStruct(src_version);

    const unix_threadstate = ThreadStateCommand {
        .cmdsize = 0x120,
        .flavor = 0x06, // ?
        .count = 0x44
    };
    try writer.writeStruct(unix_threadstate);

    const arm_thread_state_data = ArmThreadState {
        .pc = text_addr
    };
    try writer.writeStruct(arm_thread_state_data);
    
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
    for(0..0x3D50) |_| {
        try writer.writeByte(0);
    }


    // Assembly


    // Symbol table


    // String table

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
