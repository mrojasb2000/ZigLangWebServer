const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const stdout = std.io.getStdOut().writer();
const print = std.debug.print;

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stream_server = StreamServer.init(.{});
    defer stream_server.close();
    const address = try Address.resolveIp("127.0.0.1", 8080);
    try stream_server.listen(address);

    while (true) {
        try stdout.print("Server is running on port, {s}!\n", .{"8080"});
        const connection = try stream_server.accept();
        try handler(allocator, connection.stream);
    }
}

const ParsingError = error{
    MethodNotValid,
    VersionNotValid,
};

const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    OPTION,
    DELETE,

    pub fn fromString(s: []const u8) Method {
        return switch (true) {
            std.mem.eql(u8, "GET", s) => .GET,
            std.mem.eql(u8, "POST", s) => .POST,
            std.mem.eql(u8, "PUT", s) => .PUT,
            std.mem.eql(u8, "PATCH", s) => .PATCH,
            std.mem.eql(u8, "OPTION", s) => .OPTION,
            std.mem.eql(u8, "DELETE", s) => .DELETE,
            else => ParsingError.MethodNotValid,
        };
    }
};

const Version = enum {
    @"1.1",
    @"2",

    pub fn fromString(s: []const u8) Version {
        return switch (true) {
            std.mem.eql(u8, "HTTP/1.1", s) => .@"1.1",
            std.mem.eql(u8, "HTTP/2", s) => .@"2",
            else => ParsingError.VersionNotValid,
        };
    }
};

const Request = struct {
    method: Method,
    uri: []const u8,
    version: Version,
    headers: std.StringHashMap([]const u8),
    body: net.Stream.Reader,

    pub fn debugPrint(self: *Request) void {
        print("method:{s}\nuri:{s}\nversion:{s}\n", .{ self.method, self.uri, self.version });
        var headers_iter = self.headers.iterator();
        while (headers_iter.next()) |entry| {
            print("{s} :{s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !Request {
        var first_line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
        first_line = first_line[0..first_line.len];
        var first_line_iter = std.mem.split(u8, first_line, " ");

        const method = first_line_iter.next().?;
        const uri = first_line_iter.next().?;
        const version = first_line_iter.next().?;

        var headers = std.StringHashMap([]const u8).init(allocator);

        while (true) {
            var line = try stream.reader().readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
            if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;
            line = line[0..line.len];

            var line_iter = std.mem.split(u8, line, ":");
            const key = line_iter.next().?;
            var value = line_iter.next().?;
            if (value[0] == ' ') value = value[1..];
            try headers.put(key, value);
        }

        return Request{
            .headers = headers,
            .method = try Method.fromString(method),
            .version = try Version.fromString(version),
            .uri = uri,
        };
    }
};

fn handler(allocator: std.mem.Allocator, stream: net.Stream) !void {
    //_ = allocator;
    defer stream.close();
}
