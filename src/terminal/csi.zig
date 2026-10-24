const lib = @import("lib.zig");

/// Modes for the ED CSI command.
pub const EraseDisplay = enum(u8) {
    below = 0,
    above = 1,
    complete = 2,
    scrollback = 3,

    /// This is an extension added by Kitty to move the viewport into the
    /// scrollback and then erase the display.
    scroll_complete = 22,
};

/// Modes for the EL CSI command.
pub const EraseLine = enum(u8) {
    right = 0,
    left = 1,
    complete = 2,
    right_unless_pending_wrap = 4,

    /// Erase the entire soft-wrapped logical line (all physical rows it
    /// spans) and home the cursor to column 0 of its first row.
    /// Ghostty-private extension used by webtty's client to repaint a
    /// possibly-wrapped input line (\`CSI 5 K\`).
    erase_line_logical = 5,

    // Non-exhaustive so that @intToEnum never fails since the inputs are
    // user-generated.
    _,
};

/// Modes for the TBC (tab clear) command.
pub const TabClear = enum(u8) {
    current = 0,
    all = 3,

    // Non-exhaustive so that @intToEnum never fails since the inputs are
    // user-generated.
    _,
};

/// Style formats for terminal size reports.
pub const SizeReportStyle = lib.Enum(
    lib.target,
    &.{
        // XTWINOPS
        "csi_14_t",
        "csi_16_t",
        "csi_18_t",
        "csi_19_t",
        "csi_21_t",
    },
);

/// XTWINOPS CSI 22/23
pub const TitlePushPop = struct {
    op: Op,
    index: u16,

    pub const Op = enum { push, pop };
};
