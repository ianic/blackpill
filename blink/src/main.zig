const micro = @import("microzig");
const std = @import("std");

pub fn main() void {
    const led_pin = micro.Pin("PC13");
    const led = micro.Gpio(led_pin, .{
        .mode = .output,
        .initial_state = .low,
    });
    led.init();

    while (true) {
        //dummy(led);
        //irregular(led);

        //blink_morse(led, "iso medo u ducan nije reko dobar dan ");
        blink_morse(led, "sos ");
    }
}

// blinking led in regular interval
pub fn dummy(comptime led: type) void {
    micro.debug.busySleep(500_000);
    led.toggle();
}

// low is led on, high is off !!!
pub fn irregular(comptime led: type) void {
    led.setToLow();
    micro.debug.busySleep(500_000);
    led.setToHigh();
    micro.debug.busySleep(500_000 * 3);
}

fn blink_morse(comptime led: type, word: []const u8) void {
    const interval = 100_000;

    for (word) |chr| {
        if (chr == ' ') {
            led.setToHigh();
            micro.debug.busySleep(4 * interval);
            continue;
        }

        var codes = morse(chr);
        for (codes) |code| {
            switch (code) {
                Code.dit => {
                    led.setToLow();
                    micro.debug.busySleep(1 * interval);
                    led.setToHigh();
                    micro.debug.busySleep(1 * interval);
                },
                Code.dash => {
                    led.setToLow();
                    micro.debug.busySleep(3 * interval);
                    led.setToHigh();
                    micro.debug.busySleep(1 * interval);
                },
                Code.end => {
                    led.setToHigh();
                    micro.debug.busySleep(3 * interval);
                },
            }
            if (code == Code.end) {
                break;
            }
        }
    }
}

//ref: https://stackoverflow.com/questions/28045172/morse-code-converter-in-c
const letters = "**etianmsurwdkgohvf?l?pjbxcyzq??";

const Code = enum {
    dit,
    dash,
    end,
};

fn morse(chr: u8) [4]Code {
    var ret: [4]Code = .{Code.end} ** 4;
    var idx: u8 = 0;
    while (letters[idx] != chr) : (idx += 1) {}

    var i: u8 = 3;
    if (idx < 16) {
        i = 2;
        if (idx < 8) {
            i = 1;
            if (idx < 4) {
                i = 0;
            }
        }
    }
    while (i >= 0) : (i -= 1) {
        ret[i] = if (idx % 2 == 0) Code.dit else Code.dash;
        idx = idx / 2;
        if (idx <= 1) {
            break;
        }
    }
    return ret;
}

test "access morse field" {
    //std.debug.print("a: {s}\n", .{morse('a')});

    try std.testing.expectEqual(morse('a'), [_]Code{ Code.dit, Code.dash, Code.end, Code.end });
    try std.testing.expectEqual(morse('b'), [_]Code{ Code.dash, Code.dit, Code.dit, Code.dit });
    try std.testing.expectEqual(morse('y'), [_]Code{ Code.dash, Code.dit, Code.dash, Code.dash });
    try std.testing.expectEqual(morse('d'), [_]Code{ Code.dash, Code.dit, Code.dit, Code.end });
}
