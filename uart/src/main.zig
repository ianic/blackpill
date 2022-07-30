const std = @import("std");
const micro = @import("microzig");
const chip = micro.chip;
const regs = chip.registers;

pub const interrupts = struct {
    pub fn SysTick() void {
        ticks += 1;
        if (ticks % 1000 == 0) {
            counter += 1;
        }
    }

    pub fn EXTI0() void {
        counter = 0;
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }
};

var ticks: u32 = 0;
var counter: u32 = 1;

pub fn main() void {
    chip.init();
    chip.systick(1);

    const uart_idx = 2;
    const pins = .{ .tx = micro.Pin("PA2"), .rx = micro.Pin("PA3") };

    var uart = micro.Uart(uart_idx, pins).init(.{
        .baud_rate = 9600,
        .stop_bits = .one,
        .parity = null,
        .data_bits = .eight,
    }) catch |err| {
        blinkError(err);

        micro.hang();
    };

    var out = uart.writer();

    var buf: [128]u8 = undefined;
    while (true) {
        const s = std.fmt.bufPrint(buf[0..], "ticks: {d}\r\n", .{ticks}) catch buf[0..0];
        chip.led.on();
        try out.writeAll(s);
        chip.led.off();
        micro.debug.busySleep(1_000_000);
    }
}

fn blinkError(err: micro.uart.InitError) void {
    var blinks: u3 =
        switch (err) {
        error.UnsupportedBaudRate => 1,
        error.UnsupportedParity => 2,
        error.UnsupportedStopBitCount => 3,
        error.UnsupportedWordSize => 4,
    };

    while (blinks > 0) : (blinks -= 1) {
        chip.led.on();
        micro.debug.busySleep(1_000_000);
        chip.led.off();
        micro.debug.busySleep(1_000_000);
    }
}
