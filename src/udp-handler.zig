const shock = @import("shock");

const Handler = shock.Handler;
const Processor = shock.Processor;
const Packet = shock.Packet;
const std = @import("std");
const udp = @import("udp");
const UdpGate = udp.UdpGate;
const MessageHandler = udp.MessageHandler;
const net = std.net;

const Parser = @import("shock").SHOCKPackageParser;

pub const UdpHandler = struct {
    handler: Handler,
    allocator: std.mem.Allocator,
    processor: *Processor,
    gate: *UdpGate,
    parser: Parser,
    addresses: std.AutoHashMap(u32, net.Address),
    received_packets: std.ArrayList(Packet),
    port: u16,

    pub fn init(allocator: std.mem.Allocator, processor: *Processor, address: []const u8, port: u16) !*UdpHandler {
        const server_addr = try net.Address.parseIp4(address, port);
        const self = try allocator.create(UdpHandler);

        // Initialize UdpGate
        const gate = try UdpGate.init(allocator, server_addr);

        // Initialize addresses HashMap
        const addresses = std.AutoHashMap(u32, net.Address).init(allocator);

        self.* = UdpHandler{
            .handler = Handler{
                .processor = processor,
                .send = sendImpl,
                .onMessage = undefined,
            },
            .allocator = allocator,
            .processor = processor,
            .received_packets = std.ArrayList(Packet).init(allocator),
            .gate = gate,
            .parser = Parser.init(),
            .addresses = addresses,
            .port = port,
        };

        // Set message handler for the gate
        self.gate.setMessageHandler(MessageHandler{
            .gate = gate,
            .onMessage = handleUdpMessage,
            // .context = self,
        });

        return self;
    }

    pub fn setAddress(self: *UdpHandler, obj: u32, address: []const u8) !void {
        const server_addr = try net.Address.parseIp4(address, self.port);
        try self.addresses.put(obj, server_addr);
    }

    pub fn deinit(self: *UdpHandler) void {
        self.gate.deinit();
        self.addresses.deinit();
        self.received_packets.deinit();
        self.allocator.destroy(self);
    }

    // Handler for UDP messages that will be called by UdpGate
    pub fn handleUdpMessage(ctx: *anyopaque, data: []const u8, sender: net.Address) void {
        const self: *UdpHandler = @ptrCast(@alignCast(ctx));
        _ = sender;

        // Parse the received data into a packet
        // const packet = self.parser.parse(data) catch |err| {
        //     std.debug.print("Error parsing packet: {}\n", .{err});
        //     return;
        // };

        //  const pack = @as(*Packet, packet);
        // Process the packet
        self.handler.onMessage(self.handler.processor, data);
    }

    // Implementation for sending through UDP
    fn sendImpl(ctx: *anyopaque, data: Packet) void {
        const self: *UdpHandler = @ptrCast(@alignCast(ctx));

        const sp = self.parser.parse(data) catch |err| {
            std.debug.print("Error parsing packet: {}\n", .{err});
            return;
        };

        const obj = sp.header_accessor.get_object();

        // Get destination address from packet
        const dest_addr = self.addresses.get(obj) orelse {
            std.debug.print("Error: No address found for object {}\n", .{obj});
            return;
        };

        // Send through UdpGate
        self.gate.send(dest_addr, data);
    }

    // Start listening for UDP messages
    pub fn listen(self: *UdpHandler) !void {
        try self.gate.listen();
    }
};
