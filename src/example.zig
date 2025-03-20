const std = @import("std");
const net = std.net;
const mem = std.mem;
const xev = @import("xev");
const udp = @import("udp");
const UdpHandler = @import("udp-handler.zig").UdpHandler;
const UdpGate = @import("udp").UdpGate;
const Processor = @import("shock").Processor;
const Router = @import("shock").Router;
const MessageHandler = udp.MessageHandler;
const DEFAULT_PORT = 8080;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Get port from command line arguments
    var port: u16 = DEFAULT_PORT;

    var args = std.process.args();
    _ = args.skip(); // Skip program name

    if (args.next()) |arg| {
        port = try std.fmt.parseInt(u16, arg, 10);
    }
    var router = Router.init(allocator);
    defer router.deinit();

    var processor = Processor.init(allocator, &router);
    defer processor.deinit();

    // Initialize server address

    // print listen port
    std.debug.print("Listening on port {d}\n", .{port});

    const server_addr = try net.Address.parseIp4("127.0.0.1", 8888);
    var gate = try UdpHandler.init(allocator, &processor, server_addr);
    defer gate.deinit();
    try gate.listen();
}
