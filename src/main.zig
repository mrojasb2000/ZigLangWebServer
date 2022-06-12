const std = @import("std");
const net = std.net;
const StreamServer = net.StreamServer;
const Address = net.Address;
const stdout = std.io.getStdOut().writer();

pub fn main() anyerror!void {
    var stream_server = StreamServer.init(.{});
    defer stream_server.close();
    const address = try Address.resolveIp("127.0.0.1", 8080);
    try stream_server.listen(address);

    while(true) {
        try stdout.print("Server is running on port, {s}!\n", .{"8080"});
        const connection = try stream_server.accept();
        try handler(connection.stream);
    }
}

fn handler(stream: net.Stream) !void {
    defer stream.close();
    try stream.writer().print("Hello world from zig", .{});
}
