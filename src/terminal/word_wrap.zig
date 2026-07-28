//! Word wrap boundary set.
//!
//! This type stores the set of codepoints that act as word boundaries for
//! the word wrap mode (DEC private mode 2049). When word wrap is enabled
//! (and DECAWM/wraparound is also on), soft-wrapping breaks at the last
//! word boundary on the row rather than mid-word at the right margin.
//!
//! The boundary set is small and fixed-size: it holds up to `max` codepoints
//! in a sorted array. The default set is `{ 0x00 (null), 0x09 (tab),
//! 0x0B (vertical tab), 0x20 (space) }`.
//!
//! Tab (0x09) is treated as a boundary AND as a space for wrap purposes:
//! when cells are moved during word-wrap, a tab cell becomes a space in
//! the moved region. See the WORD WRAP design doc.
//!
//! This type is stored on both `Terminal` (for the print path, which reads
//! it directly) and `PageList` (for reflow-on-resize, which has no access
//! to the Terminal). The two copies are kept in sync by the Terminal
//! whenever the mode or config escape sequence changes.

const std = @import("std");
const testing = std.testing;

/// The maximum number of boundary codepoints that can be configured.
/// This is intentionally small: word boundaries are whitespace-family
/// codepoints and a handful of custom separators. If a program needs
/// more, this can be raised.
pub const max = 16;

/// The default boundary codepoints: null, tab, vertical tab, space.
const default_codepoints: [max]u21 = .{
    0x00, 0x09, 0x0B, 0x20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

/// A fixed-capacity sorted set of boundary codepoints.
///
/// The codepoints are kept sorted ascending so that `contains` can use a
/// binary search and so that the query-reply sequence emits them in a
/// stable order.
pub const Set = struct {
    /// The number of valid entries in `codepoints`.
    count: u8 = 4,

    /// The codepoint values, sorted ascending. Entries beyond `count` are
    /// zero and unused.
    ///
    /// A default-initialized `Set` is the default boundary set, so that the
    /// type can be embedded in structs without an explicit initializer.
    codepoints: [max]u21 = default_codepoints,

    /// Reset to the default boundary set.
    pub fn resetToDefault(self: *Set) void {
        self.* = default;
    }

    /// The default boundary set. This is a `Set{}`.
    pub const default: Set = .{};

    /// Replace the set with the given codepoints, sorted and deduplicated.
    /// If more than `max` are given, only the first `max` (after sort/dedup)
    /// are kept. Returns the number of codepoints stored.
    pub fn set(self: *Set, cps: []const u21) u8 {
        var tmp: [max]u21 = std.mem.zeroes([max]u21);
        const n = @min(cps.len, max);
        @memcpy(tmp[0..n], cps[0..n]);

        // Sort ascending.
        std.mem.sort(u21, tmp[0..n], {}, std.sort.asc(u21));

        // Deduplicate in place.
        var write: usize = 0;
        for (0..n) |i| {
            if (i == 0 or tmp[i] != tmp[i - 1]) {
                tmp[write] = tmp[i];
                write += 1;
            }
        }

        self.count = @intCast(write);
        self.codepoints = tmp;
        return self.count;
    }

    /// Returns true if the given codepoint is in the boundary set.
    pub fn contains(self: *const Set, cp: u21) bool {
        const cps = self.codepoints[0..self.count];
        // Manual binary search returning a bool.
        var low: usize = 0;
        var high: usize = cps.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            if (cps[mid] == cp) return true;
            if (cps[mid] < cp) low = mid + 1 else high = mid;
        }
        return false;
    }

    /// Returns the codepoints as a slice.
    ///
    /// Note: this takes a pointer to `self` so the returned slice points to
    /// the caller's storage. Taking `self` by value would return a slice into
    /// a temporary copy that becomes dangling when this method returns.
    pub fn slice(self: *const Set) []const u21 {
        return self.codepoints[0..self.count];
    }

    /// Returns true if this set equals the default set.
    pub fn isDefault(self: *const Set) bool {
        return std.mem.eql(u21, self.slice(), default.slice());
    }
};

test "default set" {
    const s: Set = .{};
    try testing.expect(s.isDefault());
    try testing.expectEqual(@as(usize, 4), s.count);
    try testing.expect(s.contains(0x00));
    try testing.expect(s.contains(0x09));
    try testing.expect(s.contains(0x0B));
    try testing.expect(s.contains(0x20));
    try testing.expect(!s.contains(0x41));
    try testing.expectEqual(@as(usize, 4), s.slice().len);
}

test "set custom boundaries" {
    var s: Set = .{};
    _ = s.set(&.{ '_', '-', '.' });
    // Sorted ascending: '-'(0x2D), '.'(0x2E), '_'(0x5F)
    try testing.expectEqual(@as(u8, 3), s.count);
    try testing.expectEqualSlices(u21, &.{ '-', '.', '_' }, s.slice());
    try testing.expect(s.contains('_'));
    try testing.expect(s.contains('.'));
    try testing.expect(!s.contains(0x20));
    try testing.expect(!s.isDefault());
}

test "set deduplicates" {
    var s: Set = .{};
    _ = s.set(&.{ 0x20, 0x20, 0x09, 0x20 });
    try testing.expectEqual(@as(u8, 2), s.count);
    try testing.expectEqualSlices(u21, &.{ 0x09, 0x20 }, s.slice());
}

test "set truncates to max" {
    var s: Set = .{};
    var input: [max + 5]u21 = undefined;
    for (&input, 0..) |*cp, i| cp.* = @intCast(i);
    _ = s.set(&input);
    try testing.expectEqual(@as(u8, max), s.count);
}

test "resetToDefault" {
    var s: Set = .{};
    _ = s.set(&.{'_'});
    try testing.expect(!s.isDefault());
    s.resetToDefault();
    try testing.expect(s.isDefault());
    try testing.expect(s.contains(0x20));
}

test "empty set" {
    var s: Set = .{};
    _ = s.set(&.{});
    try testing.expectEqual(@as(u8, 0), s.count);
    try testing.expect(!s.contains(0x20));
    try testing.expect(!s.isDefault());
}
