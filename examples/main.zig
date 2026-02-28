const std = @import("std");
const typez = @import("typez");

const OpenAISettings = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://api.openai.com/api/v1",
};

const Settings = struct {
    openai: OpenAISettings,
    is_enabled: bool,
};

pub fn main() !void {
    const DebugAllocator = std.heap.DebugAllocator(.{});
    var da: DebugAllocator = .init;
    defer _ = da.deinit();
    const allocator = da.allocator();
    const result = typez.loadEnv(Settings, allocator, .{
        .delimeter = "__",
        .prefix = "APP",
        // .load_dotenv = false,
    });
    defer result.deinit(allocator);
    const value = try result.getValue();
    const settings = value.data;
    std.log.info("is_enabled: {}, api_key: {s}, base_url: {s}", .{
        settings.is_enabled,
        settings.openai.api_key,
        settings.openai.base_url,
    });

    // switch (result) {
    //     .ok => |val| {
    //         defer val.deinit(allocator);
    //         const settings = val.data;
    // std.log.info("is_enabled: {}, api_key: {s}, base_url: {s}", .{
    //     settings.is_enabled,
    //     settings.openai.api_key,
    //     settings.openai.base_url,
    // });
    //     },
    //     .err => |err| {
    //         defer err.deinit(allocator);
    //         std.log.info("{s}", .{
    //             err.message,
    //         });
    //     },
    // }
}
