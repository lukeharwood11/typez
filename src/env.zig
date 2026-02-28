const std = @import("std");
const models = @import("models.zig");
const comptime_utils = @import("utils/comptime.zig");
const parser = @import("parsers/base.zig");
const logger = @import("logging.zig").scoped_logger;

const Config = models.Config;
const Result = models.Result;
const Value = models.Value;
const ParseError = models.ParseError;
const Error = models.Error;

pub fn getVarFromMap(T: type, allocator: std.mem.Allocator, env_map: *std.process.EnvMap, key: []const u8, default: ?T) !T {
    const optional = env_map.get(key);
    if (optional) |env_var| {
        return parser.parse(T, allocator, env_var);
    } else {
        if (default) |d| {
            return d;
        } else if (@typeInfo(T) == .optional) {
            return null;
        } else {
            logger.err("No environment variable for '{s}'", .{key});
            return ParseError.InvalidNullField;
        }
    }
}

fn formatCombine(
    comptime config: Config,
    comptime namespace: []const u8,
    comptime new: []const u8,
) []const u8 {
    const delimeter: []const u8 = if (namespace.len == 0 and config.prefix.len == 0) "" else config.delimeter;
    const string = (if (namespace.len == 0) config.prefix else namespace) ++ delimeter ++ new;
    return comptime_utils.comptimeStringToUpper(string);
}

pub fn loadStructFromEnvMap(
    comptime T: type,
    allocator: std.mem.Allocator,
    env_map: *std.process.EnvMap,
    comptime config: Config,
    comptime namespace: []const u8,
) !T {
    var t: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        const default = field.defaultValue();
        switch (@typeInfo(field.type)) {
            .@"struct" => {
                @field(t, field.name) = try loadStructFromEnvMap(
                    field.type,
                    allocator,
                    env_map,
                    config,
                    formatCombine(config, namespace, field.name),
                );
            },
            else => {
                const key = formatCombine(config, namespace, field.name);
                logger.debug("Checking key: {s}", .{key});
                @field(t, field.name) = try getVarFromMap(field.type, allocator, env_map, key, default);
            },
        }
    }
    return t;
}

pub fn loadEnv(comptime T: type, allocator: std.mem.Allocator, comptime config: Config) Result(T) {
    var env_map = std.process.getEnvMap(allocator) catch |err| {
        return switch (err) {
            std.process.GetEnvMapError.OutOfMemory => .createError(null, "Out of memory", err),
            std.process.GetEnvMapError.Unexpected => .createError(null, "Unexpected error reading environment variables", err),
        };
    };

    defer env_map.deinit();
    const arena = allocator.create(std.heap.ArenaAllocator) catch |err| {
        return .createError(null, "Out of memory", err);
    };
    arena.* = std.heap.ArenaAllocator.init(allocator);
    const s = loadStructFromEnvMap(T, arena.allocator(), &env_map, config, "") catch |err| {
        return .createError(arena, "Failed to parse struct", err);
    };
    return .createValue(arena, s);
}
