//! Cot Runtime Library (Zig Implementation)
//!
//! Provides runtime support functions for native-compiled Cot programs.
//! All functions are exported with C ABI for calling from ARM64 native code.
//!
//! This is a modern Zig approach rather than the traditional C runtime.

const std = @import("std");
const Allocator = std.mem.Allocator;

// =============================================================================
// Allocator Setup
// =============================================================================

/// Global allocator for runtime objects.
/// Using GeneralPurposeAllocator for safety during development.
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// =============================================================================
// Value Representation
// =============================================================================

pub const CotValue = i64;

const CotType = enum(u8) {
    null_type = 0,
    int_type = 1,
    bool_type = 2,
    string_type = 3,
    list_type = 4,
    map_type = 5,
    record_type = 6,
    closure_type = 7,
    variant_type = 8,
};

// =============================================================================
// I/O Helper - Zig 0.15 style
// =============================================================================

fn printToStdout(text: []const u8) void {
    var buf: [4096]u8 = undefined;
    const stdout_file: std.fs.File = .stdout();
    var stdout_writer = stdout_file.writer(&buf);
    const stdout = &stdout_writer.interface;
    stdout.writeAll(text) catch {};
    stdout.flush() catch {};
}

fn printFmtToStdout(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const stdout_file: std.fs.File = .stdout();
    var stdout_writer = stdout_file.writer(&buf);
    const stdout = &stdout_writer.interface;
    stdout.print(fmt, args) catch {};
    stdout.flush() catch {};
}

// =============================================================================
// String Type
// =============================================================================

const CotString = struct {
    type_tag: CotType = .string_type,
    refcount: i32 = 1,
    data: []const u8,

    fn create(data: []const u8) ?*CotString {
        const str = allocator.create(CotString) catch return null;
        const owned = allocator.dupe(u8, data) catch {
            allocator.destroy(str);
            return null;
        };
        str.* = .{
            .data = owned,
        };
        return str;
    }

    fn destroy(self: *CotString) void {
        allocator.free(self.data);
        allocator.destroy(self);
    }
};

export fn cot_string_new(data: [*]const u8, length: i64) CotValue {
    const len: usize = @intCast(@max(0, length));
    const slice = data[0..len];
    const str = CotString.create(slice) orelse return 0;
    return @bitCast(@intFromPtr(str));
}

export fn cot_str_len(str_val: CotValue) i64 {
    if (str_val == 0) return 0;
    const str: *CotString = @ptrFromInt(@as(usize, @bitCast(str_val)));
    return @intCast(str.data.len);
}

export fn cot_str_concat(a_val: CotValue, b_val: CotValue) CotValue {
    const a_data = if (a_val == 0) "" else blk: {
        const a: *CotString = @ptrFromInt(@as(usize, @bitCast(a_val)));
        break :blk a.data;
    };
    const b_data = if (b_val == 0) "" else blk: {
        const b: *CotString = @ptrFromInt(@as(usize, @bitCast(b_val)));
        break :blk b.data;
    };

    const total_len = a_data.len + b_data.len;
    const combined = allocator.alloc(u8, total_len) catch return 0;
    @memcpy(combined[0..a_data.len], a_data);
    @memcpy(combined[a_data.len..], b_data);

    const result = allocator.create(CotString) catch {
        allocator.free(combined);
        return 0;
    };
    result.* = .{
        .data = combined,
    };
    return @bitCast(@intFromPtr(result));
}

export fn cot_str_ptr(str_val: CotValue) [*]const u8 {
    if (str_val == 0) return "";
    const str: *CotString = @ptrFromInt(@as(usize, @bitCast(str_val)));
    return str.data.ptr;
}

// =============================================================================
// List Type
// =============================================================================

const CotList = struct {
    type_tag: CotType = .list_type,
    refcount: i32 = 1,
    items: std.ArrayListUnmanaged(CotValue) = .empty,

    fn create() ?*CotList {
        const list = allocator.create(CotList) catch return null;
        list.* = .{};
        return list;
    }

    fn destroy(self: *CotList) void {
        self.items.deinit(allocator);
        allocator.destroy(self);
    }
};

export fn cot_list_new() CotValue {
    const list = CotList.create() orelse return 0;
    return @bitCast(@intFromPtr(list));
}

export fn cot_list_push(list_val: CotValue, value: CotValue) void {
    if (list_val == 0) return;
    const list: *CotList = @ptrFromInt(@as(usize, @bitCast(list_val)));
    list.items.append(allocator, value) catch {};
}

export fn cot_list_pop(list_val: CotValue) CotValue {
    if (list_val == 0) return 0;
    const list: *CotList = @ptrFromInt(@as(usize, @bitCast(list_val)));
    if (list.items.items.len == 0) return 0;
    return list.items.pop() orelse 0;
}

export fn cot_list_get(list_val: CotValue, index: i64) CotValue {
    if (list_val == 0) return 0;
    const list: *CotList = @ptrFromInt(@as(usize, @bitCast(list_val)));
    const idx: usize = @intCast(@max(0, index));
    if (idx >= list.items.items.len) return 0;
    return list.items.items[idx];
}

export fn cot_list_set(list_val: CotValue, index: i64, value: CotValue) void {
    if (list_val == 0) return;
    const list: *CotList = @ptrFromInt(@as(usize, @bitCast(list_val)));
    const idx: usize = @intCast(@max(0, index));
    if (idx >= list.items.items.len) return;
    list.items.items[idx] = value;
}

export fn cot_list_len(list_val: CotValue) i64 {
    if (list_val == 0) return 0;
    const list: *CotList = @ptrFromInt(@as(usize, @bitCast(list_val)));
    return @intCast(list.items.items.len);
}

export fn cot_list_clear(list_val: CotValue) void {
    if (list_val == 0) return;
    const list: *CotList = @ptrFromInt(@as(usize, @bitCast(list_val)));
    list.items.clearRetainingCapacity();
}

// =============================================================================
// Map Type (using Zig's HashMap)
// =============================================================================

const CotMap = struct {
    type_tag: CotType = .map_type,
    refcount: i32 = 1,
    entries: std.AutoHashMapUnmanaged(CotValue, CotValue) = .empty,

    fn create() ?*CotMap {
        const map = allocator.create(CotMap) catch return null;
        map.* = .{};
        return map;
    }

    fn destroy(self: *CotMap) void {
        self.entries.deinit(allocator);
        allocator.destroy(self);
    }
};

export fn cot_map_new() CotValue {
    const map = CotMap.create() orelse return 0;
    return @bitCast(@intFromPtr(map));
}

export fn cot_map_set(map_val: CotValue, key: CotValue, value: CotValue) void {
    if (map_val == 0) return;
    const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(map_val)));
    map.entries.put(allocator, key, value) catch {};
}

export fn cot_map_get(map_val: CotValue, key: CotValue) CotValue {
    if (map_val == 0) return 0;
    const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(map_val)));
    return map.entries.get(key) orelse 0;
}

export fn cot_map_has(map_val: CotValue, key: CotValue) i64 {
    if (map_val == 0) return 0;
    const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(map_val)));
    return if (map.entries.contains(key)) 1 else 0;
}

export fn cot_map_delete(map_val: CotValue, key: CotValue) void {
    if (map_val == 0) return;
    const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(map_val)));
    _ = map.entries.remove(key);
}

export fn cot_map_len(map_val: CotValue) i64 {
    if (map_val == 0) return 0;
    const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(map_val)));
    return @intCast(map.entries.count());
}

export fn cot_map_clear(map_val: CotValue) void {
    if (map_val == 0) return;
    const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(map_val)));
    map.entries.clearRetainingCapacity();
}

// =============================================================================
// Variant Type
// =============================================================================

const CotVariant = struct {
    type_tag: CotType = .variant_type,
    refcount: i32 = 1,
    tag: i64,           // Variant tag (which case)
    payload: []CotValue, // Payload fields

    fn create(tag: i64, payload_count: usize) ?*CotVariant {
        const variant = allocator.create(CotVariant) catch return null;
        const payload = allocator.alloc(CotValue, payload_count) catch {
            allocator.destroy(variant);
            return null;
        };
        @memset(payload, 0); // Initialize all fields to null
        variant.* = .{
            .tag = tag,
            .payload = payload,
        };
        return variant;
    }

    fn destroy(self: *CotVariant) void {
        allocator.free(self.payload);
        allocator.destroy(self);
    }
};

export fn cot_variant_new(tag: i64, payload_count: i64) CotValue {
    const count: usize = @intCast(@max(0, payload_count));
    const variant = CotVariant.create(tag, count) orelse return 0;
    return @bitCast(@intFromPtr(variant));
}

export fn cot_variant_get_tag(variant_val: CotValue) i64 {
    if (variant_val == 0) return 0;
    const variant: *CotVariant = @ptrFromInt(@as(usize, @bitCast(variant_val)));
    return variant.tag;
}

export fn cot_variant_get_payload(variant_val: CotValue, field_idx: i64) CotValue {
    if (variant_val == 0) return 0;
    const variant: *CotVariant = @ptrFromInt(@as(usize, @bitCast(variant_val)));
    const idx: usize = @intCast(@max(0, field_idx));
    if (idx >= variant.payload.len) return 0;
    return variant.payload[idx];
}

export fn cot_variant_set_payload(variant_val: CotValue, field_idx: i64, value: CotValue) void {
    if (variant_val == 0) return;
    const variant: *CotVariant = @ptrFromInt(@as(usize, @bitCast(variant_val)));
    const idx: usize = @intCast(@max(0, field_idx));
    if (idx >= variant.payload.len) return;
    variant.payload[idx] = value;
}

// =============================================================================
// Closure Type
// =============================================================================

const CotClosure = struct {
    type_tag: CotType = .closure_type,
    refcount: i32 = 1,
    fn_idx: i64,      // Routine/function index
    env: CotValue,    // Environment (usually a map, or 0 for no captures)

    fn create(fn_idx: i64, env: CotValue) ?*CotClosure {
        const closure = allocator.create(CotClosure) catch return null;
        closure.* = .{
            .fn_idx = fn_idx,
            .env = env,
        };
        return closure;
    }

    fn destroy(self: *CotClosure) void {
        allocator.destroy(self);
    }
};

export fn cot_closure_new(fn_idx: i64, env: CotValue) CotValue {
    const closure = CotClosure.create(fn_idx, env) orelse return 0;
    return @bitCast(@intFromPtr(closure));
}

export fn cot_closure_get_fn(closure_val: CotValue) i64 {
    if (closure_val == 0) return 0;
    const closure: *CotClosure = @ptrFromInt(@as(usize, @bitCast(closure_val)));
    return closure.fn_idx;
}

export fn cot_closure_get_env(closure_val: CotValue) CotValue {
    if (closure_val == 0) return 0;
    const closure: *CotClosure = @ptrFromInt(@as(usize, @bitCast(closure_val)));
    return closure.env;
}

// =============================================================================
// Record Type
// =============================================================================

const CotRecord = struct {
    type_tag: CotType = .record_type,
    refcount: i32 = 1,
    type_id: i64,
    fields: []CotValue,

    fn create(type_id: i64, field_count: usize) ?*CotRecord {
        const record = allocator.create(CotRecord) catch return null;
        const fields = allocator.alloc(CotValue, field_count) catch {
            allocator.destroy(record);
            return null;
        };
        @memset(fields, 0); // Initialize all fields to null
        record.* = .{
            .type_id = type_id,
            .fields = fields,
        };
        return record;
    }

    fn destroy(self: *CotRecord) void {
        allocator.free(self.fields);
        allocator.destroy(self);
    }
};

export fn cot_record_new(type_id: i64, field_count: i64) CotValue {
    const count: usize = @intCast(@max(0, field_count));
    const record = CotRecord.create(type_id, count) orelse return 0;
    return @bitCast(@intFromPtr(record));
}

export fn cot_record_get_field(record_val: CotValue, field_idx: i64) CotValue {
    if (record_val == 0) return 0;
    const record: *CotRecord = @ptrFromInt(@as(usize, @bitCast(record_val)));
    const idx: usize = @intCast(@max(0, field_idx));
    if (idx >= record.fields.len) return 0;
    return record.fields[idx];
}

export fn cot_record_set_field(record_val: CotValue, field_idx: i64, value: CotValue) void {
    if (record_val == 0) return;
    const record: *CotRecord = @ptrFromInt(@as(usize, @bitCast(record_val)));
    const idx: usize = @intCast(@max(0, field_idx));
    if (idx >= record.fields.len) return;
    record.fields[idx] = value;
}

// =============================================================================
// I/O Operations
// =============================================================================

export fn cot_print_int(value: i64) void {
    printFmtToStdout("{d}", .{value});
}

export fn cot_println_int(value: i64) void {
    printFmtToStdout("{d}\n", .{value});
}

export fn cot_print_str(str_val: CotValue) void {
    if (str_val == 0) {
        printToStdout("null");
    } else {
        const str: *CotString = @ptrFromInt(@as(usize, @bitCast(str_val)));
        printToStdout(str.data);
    }
}

export fn cot_println_str(str_val: CotValue) void {
    cot_print_str(str_val);
    printToStdout("\n");
}

export fn cot_print_bool(value: i64) void {
    printToStdout(if (value != 0) "true" else "false");
}

export fn cot_println_bool(value: i64) void {
    cot_print_bool(value);
    printToStdout("\n");
}

/// Generic print - attempts to determine type from value
export fn cot_print(value: CotValue) void {
    if (value == 0) {
        printToStdout("null");
        return;
    }

    // Try to interpret as pointer to typed object
    if (value > 0x1000) {
        const ptr: *const CotType = @ptrFromInt(@as(usize, @bitCast(value)));
        const type_tag = ptr.*;
        switch (type_tag) {
            .string_type => {
                const str: *CotString = @ptrFromInt(@as(usize, @bitCast(value)));
                printToStdout(str.data);
                return;
            },
            .list_type => {
                const list: *CotList = @ptrFromInt(@as(usize, @bitCast(value)));
                printFmtToStdout("[List len={d}]", .{list.items.items.len});
                return;
            },
            .map_type => {
                const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(value)));
                printFmtToStdout("{{Map len={d}}}", .{map.entries.count()});
                return;
            },
            .record_type => {
                printToStdout("<Record>");
                return;
            },
            .closure_type => {
                const closure: *CotClosure = @ptrFromInt(@as(usize, @bitCast(value)));
                printFmtToStdout("<Closure fn={d}>", .{closure.fn_idx});
                return;
            },
            .variant_type => {
                const variant: *CotVariant = @ptrFromInt(@as(usize, @bitCast(value)));
                printFmtToStdout("<Variant tag={d} payload_len={d}>", .{ variant.tag, variant.payload.len });
                return;
            },
            else => {},
        }
    }

    // Default: treat as integer
    printFmtToStdout("{d}", .{value});
}

export fn cot_println(value: CotValue) void {
    cot_print(value);
    printToStdout("\n");
}

// =============================================================================
// Memory Management (Reference Counting)
// =============================================================================

export fn cot_retain(value: CotValue) void {
    if (value == 0) return;
    if (value <= 0x1000) return; // Small integer, not a pointer

    const ptr: *const CotType = @ptrFromInt(@as(usize, @bitCast(value)));
    switch (ptr.*) {
        .string_type => {
            const str: *CotString = @ptrFromInt(@as(usize, @bitCast(value)));
            str.refcount += 1;
        },
        .list_type => {
            const list: *CotList = @ptrFromInt(@as(usize, @bitCast(value)));
            list.refcount += 1;
        },
        .map_type => {
            const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(value)));
            map.refcount += 1;
        },
        .record_type => {
            const record: *CotRecord = @ptrFromInt(@as(usize, @bitCast(value)));
            record.refcount += 1;
        },
        .closure_type => {
            const closure: *CotClosure = @ptrFromInt(@as(usize, @bitCast(value)));
            closure.refcount += 1;
        },
        .variant_type => {
            const variant: *CotVariant = @ptrFromInt(@as(usize, @bitCast(value)));
            variant.refcount += 1;
        },
        else => {},
    }
}

export fn cot_release(value: CotValue, value_type: CotType) void {
    if (value == 0) return;

    switch (value_type) {
        .string_type => {
            const str: *CotString = @ptrFromInt(@as(usize, @bitCast(value)));
            str.refcount -= 1;
            if (str.refcount <= 0) {
                str.destroy();
            }
        },
        .list_type => {
            const list: *CotList = @ptrFromInt(@as(usize, @bitCast(value)));
            list.refcount -= 1;
            if (list.refcount <= 0) {
                list.destroy();
            }
        },
        .map_type => {
            const map: *CotMap = @ptrFromInt(@as(usize, @bitCast(value)));
            map.refcount -= 1;
            if (map.refcount <= 0) {
                map.destroy();
            }
        },
        .record_type => {
            const record: *CotRecord = @ptrFromInt(@as(usize, @bitCast(value)));
            record.refcount -= 1;
            if (record.refcount <= 0) {
                record.destroy();
            }
        },
        .closure_type => {
            const closure: *CotClosure = @ptrFromInt(@as(usize, @bitCast(value)));
            closure.refcount -= 1;
            if (closure.refcount <= 0) {
                closure.destroy();
            }
        },
        .variant_type => {
            const variant: *CotVariant = @ptrFromInt(@as(usize, @bitCast(value)));
            variant.refcount -= 1;
            if (variant.refcount <= 0) {
                variant.destroy();
            }
        },
        else => {},
    }
}

// =============================================================================
// Error Handling
// =============================================================================

// Error handler state - simplified version for native code
// Full implementation would use setjmp/longjmp for non-local control flow
const ErrorHandler = struct {
    handler_addr: u64,  // Address to jump to on error
    saved_sp: u64,      // Saved stack pointer
    error_value: CotValue,
};

var error_handlers: [16]ErrorHandler = undefined;
var error_handler_count: usize = 0;
var current_error: CotValue = 0;

/// Set an error handler (called at try block entry)
/// handler_addr: address to jump to if error occurs
/// saved_sp: current stack pointer to restore on error
/// Returns 0 on success
export fn cot_set_error_handler(handler_addr: u64, saved_sp: u64) i64 {
    if (error_handler_count >= error_handlers.len) {
        return -1; // Too many nested handlers
    }
    error_handlers[error_handler_count] = .{
        .handler_addr = handler_addr,
        .saved_sp = saved_sp,
        .error_value = 0,
    };
    error_handler_count += 1;
    return 0;
}

/// Clear the current error handler (called at try block exit)
export fn cot_clear_error_handler() void {
    if (error_handler_count > 0) {
        error_handler_count -= 1;
    }
}

/// Throw an exception with the given value
/// If a handler is set, stores error and returns handler address
/// If no handler, returns 0 (caller should abort)
export fn cot_throw(error_value: CotValue) u64 {
    current_error = error_value;
    if (error_handler_count > 0) {
        error_handler_count -= 1;
        return error_handlers[error_handler_count].handler_addr;
    }
    // No handler - print error and return 0
    printToStdout("Unhandled exception: ");
    cot_println(error_value);
    return 0;
}

/// Get the current error value (called in catch block)
export fn cot_get_error() CotValue {
    return current_error;
}

// =============================================================================
// Entry Point (for standalone executables)
// =============================================================================

/// User's compiled main function (provided by native code)
extern fn cot_main() i64;

/// Standard entry point that calls the Cot program's main
pub fn main() void {
    const result = cot_main();
    std.process.exit(@intCast(@as(u8, @truncate(@as(u64, @bitCast(result))))));
}

// =============================================================================
// Tests
// =============================================================================

test "list operations" {
    const list = cot_list_new();
    try std.testing.expect(list != 0);

    cot_list_push(list, 42);
    cot_list_push(list, 100);

    try std.testing.expectEqual(@as(i64, 2), cot_list_len(list));
    try std.testing.expectEqual(@as(i64, 42), cot_list_get(list, 0));
    try std.testing.expectEqual(@as(i64, 100), cot_list_get(list, 1));

    const popped = cot_list_pop(list);
    try std.testing.expectEqual(@as(i64, 100), popped);
    try std.testing.expectEqual(@as(i64, 1), cot_list_len(list));

    cot_release(list, .list_type);
}

test "map operations" {
    const map = cot_map_new();
    try std.testing.expect(map != 0);

    cot_map_set(map, 1, 100);
    cot_map_set(map, 2, 200);

    try std.testing.expectEqual(@as(i64, 2), cot_map_len(map));
    try std.testing.expectEqual(@as(i64, 100), cot_map_get(map, 1));
    try std.testing.expectEqual(@as(i64, 200), cot_map_get(map, 2));
    try std.testing.expectEqual(@as(i64, 1), cot_map_has(map, 1));
    try std.testing.expectEqual(@as(i64, 0), cot_map_has(map, 99));

    cot_map_delete(map, 1);
    try std.testing.expectEqual(@as(i64, 1), cot_map_len(map));

    cot_release(map, .map_type);
}

test "string operations" {
    const hello = cot_string_new("hello", 5);
    try std.testing.expect(hello != 0);
    try std.testing.expectEqual(@as(i64, 5), cot_str_len(hello));

    const world = cot_string_new(" world", 6);
    const combined = cot_str_concat(hello, world);
    try std.testing.expectEqual(@as(i64, 11), cot_str_len(combined));

    cot_release(hello, .string_type);
    cot_release(world, .string_type);
    cot_release(combined, .string_type);
}

test "record operations" {
    const record = cot_record_new(1, 3); // type_id=1, 3 fields
    try std.testing.expect(record != 0);

    cot_record_set_field(record, 0, 10);
    cot_record_set_field(record, 1, 20);
    cot_record_set_field(record, 2, 30);

    try std.testing.expectEqual(@as(i64, 10), cot_record_get_field(record, 0));
    try std.testing.expectEqual(@as(i64, 20), cot_record_get_field(record, 1));
    try std.testing.expectEqual(@as(i64, 30), cot_record_get_field(record, 2));

    cot_release(record, .record_type);
}
