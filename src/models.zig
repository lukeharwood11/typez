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

        pub fn createValue(arena: *std.heap.ArenaAllocator, value: T) @This() {
            return .{
                .ok = .{
                    .arena = arena,
                    .value = value,
                },
            };
        }

        pub fn createError(message: []const u8, @"error": anyerror) @This() {
            return .{
                .err = .init(message, @"error"),
            };
        }
    };
}

pub fn Value(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        value: T,

        pub fn deinit(self: @This()) void {
            self.arena.deinit();
            self.arena.child_allocator.destroy(self.arena);
        }
    };
}

pub const Error = struct {
    message: []const u8,
    @"error": anyerror,

    pub fn init(message: []const u8, @"error": anyerror) Error {
        return .{
            .message = message,
            .@"error" = @"error",
        };
    }
};
