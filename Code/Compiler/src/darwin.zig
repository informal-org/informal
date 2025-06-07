// https://github.com/rewired-gh/macos-system-call-table/blob/main/arm64-system-calls.md

pub const Syscall = enum(u16) {
    exit = 1,
    write = 4,
};
