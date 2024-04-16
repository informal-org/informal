
// const sys = @cImport({
//     @cInclude("aarch64-mac/syscall.h");
// });


// 64 bit support only.
// Reference:
// /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach-o/loader.h
// Thanks to: https://gpanders.com/blog/exploring-mach-o-part-2/
const mach_header = struct {
	magic: u32,		        // mach magic number identifier */
	cputype: CpuType,	        // cpu specifier */
	cpusubtype: u32,	    // machine specifier */
    filetype: Filetype,	        // type of file */
	ncmds: u32,		        // number of load commands */
	sizeofcmds: u32,	    // the size of all the load commands */
	flags: Flags,		        // flags */
}

// 32bit = 0xfeedface :)
const MH_MAGIC = "0xfeedfacf";


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
    fileset = 0c,   // a file composed of other Mach-Os to be run in the same userspace sharing a single linkedit.
    gpu_program = 0xd,  // a GPU program
    gpu_dylib = 0xe,    // GPU support function
};

// Reference:
// https://web.archive.org/web/20090901205800/http://developer.apple.com/mac/library/documentation/DeveloperTools/Conceptual/MachORuntime/Reference/reference.html#//apple_ref/c/tag/section_64
const Flags = packed struct {
    noundefs: bool, // The object file contained no undefined references when it was built
    incrlink: bool, // The object file is the output of an incremental link against a base file and cannot be linked again.
    dyldlink: bool, // The file is input for the dynamic linker and cannot be statically linked again
    bindatload: bool, // The dynamic linker should bind the undefined references when the file is loaded.
    prebound: bool, // The file’s undefined references are prebound
    split_segs: bool, // The file has its read-only and read-write segments split.
    lazy_init: bool,
    twolevel: bool, // The image is using two-level namespace bindings
    force_flat: bool, // The executable is forcing all images to use flat namespace bindings
    nomultidefs: bool, // This umbrella guarantees there are no multiple definitions of symbols in its subimages. As a result, the two-level namespace hints can always be used.
    nofixprebinding: bool,  // The dynamic linker doesn’t notify the prebinding agent about this executable
    prebindable: bool,  // This file is not prebound but can have its prebinding redone. Used only when MH_PREBEOUND is not set.
    allmodsbound: bool, // Indicates that this binary binds to all two-level namespace modules of its dependent libraries. Used only when MH_PREBINDABLE and MH_TWOLEVEL are set
    subsections_via_symbols: bool, // The sections of the object file can be divided into individual blocks. These blocks are dead-stripped if they are not used by other code. 
    canonical: bool, // This file has been canonicalized by unprebinding—clearing prebinding information from the file. See the redo_prebinding man page for details.
    weak_defines: bool,
    binds_to_weak: bool,
    allow_stack_execution: bool,
    root_safe: bool,
    setuid_safe: bool,
    no_reexported_dylibs: bool,
    pie: bool,  // OS will load the main executable at a random address. Only used on execute filetypes.
    dead_strippable_dylib: bool,
    has_tlv_descriptors: bool,
    no_heap_execution: bool,
    app_extension_safe: bool,
    nlist_outofsync_with_dyldinfo: bool,
    sim_support: bool,
    dylib_in_cache: bool,
    _: u3, // pad to 32 bits
};

// Minimal:
// NOUNDEFS
// DYLDLINK
// TWOLEVEL
// PIE
