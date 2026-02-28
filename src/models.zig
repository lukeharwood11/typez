const std = @import("std");

pub const ParseError = error{
    InvalidEnumField,
    InvalidFloatField,
    InvalidIntField,
    InvalidNullField,
    InvalidBoolField,
};

pub const Config = struct {
    prefix: []const u8 = "",
    delimeter: []const u8 = "_",
    // TODO: implement dotenv loading
    // load_dotenv: bool = false,

    const default: Config = .{};
};

pub const ResultTag = enum {
    ok,
    err,
};

pub fn Result(comptime T: type) type {
    return union(ResultTag) {
        ok: Value(T),
        err: Error,

        pub fn getValue(self: @This()) !Value(T) {
            return switch (self) {
                .ok => |val| val,
                .err => |err| err.@"error",
            };
        }

        pub fn isOk(self: @This()) ?Value(T) {
            return switch (self) {
                .ok => |val| val,
                else => null,
            };
        }

        pub fn createValue(arena: *std.heap.ArenaAllocator, data: T) @This() {
            return .{
                .ok = .{
                    .arena = arena,
                    .data = data,
                },
            };
        }

        pub fn createError(arena: ?*std.heap.ArenaAllocator, message: []const u8, @"error": anyerror) @This() {
            return .{
                .err = .init(arena, message, @"error"),
            };
        }

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            self.deinit(allocator);
        }
    };
}

pub fn Value(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        data: T,

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            self.arena.deinit();
            allocator.destroy(self.arena);
        }
    };
}

pub const Error = struct {
    message: []const u8,
    @"error": anyerror,
    // can be null if there's no memory allocated
    arena: ?*std.heap.ArenaAllocator = null,

    pub fn init(arena: ?*std.heap.ArenaAllocator, message: []const u8, @"error": anyerror) Error {
        return .{
            .message = message,
            .@"error" = @"error",
            .arena = arena,
        };
    }

    pub fn deinit(self: Error, allocator: std.mem.Allocator) void {
        if (self.arena) |arena| {
            defer allocator.destroy(arena);
            defer arena.deinit();
        }
    }
};
