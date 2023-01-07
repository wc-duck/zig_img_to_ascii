const std = @import("std");
const fs   = std.fs;
const stbi = @cImport(@cInclude("stb_image.h"));

pub const Image = struct {
    w     : u32,
    h     : u32,
    pitch : u32,
    data  : [] u8, // why not const

    pub fn destroy(pi : *Image) void
    {
        stbi.stbi_image_free(pi.data.ptr);
    }

    pub fn loadFromPath(path : []const u8, temp_alloc : std.mem.Allocator) !Image
    {
        // ... read file from disk ...
        var file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const buffer_size = 0xFFFFFFFF;
        const file_buffer = try file.readToEndAlloc(temp_alloc, buffer_size);
        defer temp_alloc.free(file_buffer);

        var _w : c_int = undefined;
        var _h : c_int = undefined;
        var _c : c_int = undefined;
        const channel_count = 3;
        var _data = stbi.stbi_load_from_memory(file_buffer.ptr, @intCast(c_int, file_buffer.len), &_w, &_h, &_c, channel_count);

        var img : Image = undefined;
        img.w        = @intCast(u32, _w);
        img.h        = @intCast(u32, _h);
        img.pitch    = img.w * channel_count;
        img.data     = _data[0 .. img.h * img.pitch];
        return img;
    }
};