const std  = @import("std");
const math = std.math;
const img = @import("img.zig");

fn streq(comptime s1 : []const u8, s2 : []const u8 ) bool {
    return std.mem.eql(u8, s1, s2);
}

fn sum(slice : [] const u8) u32 {
    var res: u32 = 0;
    for(slice) |s| {
        res += @as(u32, s);
    }
    return res;
}

const imgToGrayMethod = enum {
    lightness,
    average,
    luminosity
};

fn pxToGrayLightness(r : u8, g : u8, b : u8) u8 {
    //    min(R,G,B) + max(R,G,B)
    //    -----------------------
    //               2
    return @intCast(u8, (@as(u32, math.min3(r, g, b)) + @as(u32, math.max3(r, g, b))) / 2);
}

fn pxToGrayAverage(r : u8, g : u8, b : u8) u8 {
    //    R + G + B
    //    ---------
    //        3
    return @intCast(u8, (@as(u32, r) + @as(u32, g) + @as(u32, b)) / 3);
}

fn pxToGrayLuminosity(r : u8, g : u8, b : u8) u8 {
    //    (0.3 * R) + (0.59 * G} + (0.11 * B)
    return @floatToInt(u8, (0.30 * @intToFloat(f32, r)) + 
                           (0.59 * @intToFloat(f32, g)) + 
                           (0.11 * @intToFloat(f32, b)));
}

// ... calc grayscale value of block ...
// https://www.baeldung.com/cs/convert-rgb-to-grayscale
fn imgToGrayScale(allocator : std.mem.Allocator, image : img.Image, method : imgToGrayMethod) ![] const u8
{
    const px_cnt = image.w * image.h;

    var gray = try allocator.alloc(u8, px_cnt);

    var i : u32 = 0;
    while(i < px_cnt) : (i += 1) {
        const r = image.data[(i * 3) + 0];
        const g = image.data[(i * 3) + 1];
        const b = image.data[(i * 3) + 2];

        gray[i] = switch(method)
        {
            .lightness  => pxToGrayLightness (r, g, b),
            .average    => pxToGrayAverage   (r, g, b),
            .luminosity => pxToGrayLuminosity(r, g, b),
        };
    }

    return gray;
}

fn mapToRange(range_max : usize, c : u32) usize {

    const map_len = @intToFloat(f32, range_max - 1);
    const c_nrm   = @intToFloat(f32, c) / 255.0;

    return @floatToInt(usize, c_nrm * map_len);
}

fn imgToAscii(image : img.Image, alloc : std.mem.Allocator) !void
{
    const ascii_palette = " .,:;ox%#@";
    const block_size = 8;
    const block_cnt_w = image.w / block_size;
    const block_cnt_h = image.h / block_size;

    const grayscale = imgToGrayScale(alloc, image, imgToGrayMethod.luminosity) catch @panic("failed to alloc!");
    defer alloc.free(grayscale);

    const out = std.io.getStdOut().writer();

    var block_h: u32 = 0;
    while (block_h < block_cnt_h) : (block_h += 1) {
        var block_w: u32 = 0;
        while (block_w < block_cnt_w) : (block_w += 1) {
            const upper_left = (block_h * image.w * block_size) + (block_w * block_size);

            var s : u32 = 0;
            var row : u32 = 0;
            while(row < block_size) : (row += 1)
            {
                const row_start = upper_left + (image.w * row);
                const row_end   = row_start + block_size;
                const pix_row = grayscale[row_start .. row_end];
                s += sum(pix_row);
            }
            const idx = mapToRange(ascii_palette.len - 1, s / (block_size * block_size));
            try out.print("{c}", .{ascii_palette[idx]});
        }
        try out.print("\n", .{});
    }

    // TODO: color output? :)
}


const CmdLineArgs = struct {
    input : ?[]const u8     = null,
    method: imgToGrayMethod = .average,
};

const CmdLineError = error {
    invalidFlag,
    missingArg,
    invalidMethod,

    showHelp,
};

fn parseArgs(alloc : std.mem.Allocator) !CmdLineArgs
{
    var args = try std.process.argsWithAllocator(alloc);

    // skip my own exe name
    _ = args.skip();

    var out = CmdLineArgs{};

    while(args.next()) |arg| {
        if(streq("--input", arg) or streq("-i", arg)) {
            out.input = args.next();
        }
        else if(streq("--method", arg))
        {
            const method = args.next();
            if(method) |m|
            {
                     if(streq("lightness",  m)) { out.method = .lightness;  }
                else if(streq("average",    m)) { out.method = .average;    }
                else if(streq("luminosity", m)) { out.method = .luminosity; }
                else
                {
                    std.debug.print("'{s}' is not a valid grayscale method, use 'lightness', 'average' or 'luminosity'\n", .{m});
                    return CmdLineError.invalidMethod;
                }
            }
            else
            {
                std.debug.print("'--method' is missing an argument, use any of 'lightness', 'average' or 'luminosity'\n", .{});
                return CmdLineError.missingArg;
            }
        }
        else if(streq("--help", arg) or streq("-h", arg)) {
            std.debug.print("HEEELP\n", .{});
        }
        else{
            std.debug.print("unknown arg {s}\n", .{arg});
        }
    }

    return out;
}


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const args = try parseArgs(arena.allocator());

    if(args.input) |i|
    {
        var image = try img.Image.loadFromPath(i, arena.allocator());
        defer image.destroy();

        try imgToAscii(image, arena.allocator());
    }
    else
    {
        std.debug.print("read input from stdin\n", .{});
    }

}
