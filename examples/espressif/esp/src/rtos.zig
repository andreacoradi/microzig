const std = @import("std");
const log = std.log;
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const esp = microzig.hal;
const rtos = esp.rtos;
const gpio = esp.gpio;
const systimer = esp.systimer;
const usb_serial_jtag = esp.usb_serial_jtag;

pub const microzig_options: microzig.Options = .{
    .logFn = usb_serial_jtag.logger.log,
    .interrupts = .{
        .interrupt30 = rtos.general_purpose_interrupt_handler,
        .interrupt31 = rtos.yield_interrupt_handler,
    },
    .log_level = .debug,
    .cpu = .{
        .interrupt_stack = .{
            .enable = true,
        },
    },
    .hal = .{
        .rtos = .{
            .enable = true,
        },
    },
};

var heap_buf: [10 * 1024]u8 = undefined;

fn task1(queue: *rtos.Queue(u32)) void {
    for (0..5) |i| {
        queue.put_one(i) catch {
            std.log.err("failed to put item", .{});
            continue;
        };
        rtos.sleep(.from_ms(500));
    }
}

pub fn main() !void {
    var heap = microzig.Allocator.init_with_buffer(&heap_buf);
    const gpa = heap.allocator();

    var buffer: [1]u32 = undefined;
    var queue: rtos.Queue(u32) = .init(&buffer);

    esp.time.sleep_ms(1000);

    _ = try rtos.spawn(gpa, task1, .{&queue}, .{
        .stack_size = 8000,
    });

    while (true) {
        const item = try queue.get_one(.from_ms(1000));
        std.log.info("got item: {}", .{item});
    }
}
