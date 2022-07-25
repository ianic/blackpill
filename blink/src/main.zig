const micro = @import("microzig");

pub fn main() void {
    const led_pin = micro.Pin("PC13");
    const led = micro.Gpio(led_pin, .{
        .mode = .output,
        .initial_state = .low,
    });
    led.init();

    while (true) {
        micro.debug.busySleep(500_000);
        led.toggle();
    }
}

// const micro = @import("microzig");
// const regs = micro.chip.registers; // `microzig.chip.registers`: access to register definitions

// pub fn main() !void {
//     // Enable GPIOD port
//     regs.RCC.AHB1ENR.modify(.{ .GPIODEN = 1 });

//     // Set pin 12/13/14/15 mode to general purpose output
//     regs.GPIOD.MODER.modify(.{ .MODER13 = 0b01 });

//     // Set pin 12 and 14
//     regs.GPIOD.BSRR.modify(.{ .BS13 = 1 });

//     // const led = micro.Gpio(u32, .{
//     //     .mode = .output,
//     //     .initial_state = .low,
//     // });
//     // led.init();

//     while (true) {
//         // Read the LED state
//         var leds_state = regs.GPIOD.ODR.read();
//         // Set the LED output to the negation of the currrent output
//         regs.GPIOD.ODR.modify(.{
//             .ODR13 = ~leds_state.ODR13,
//         });

//         micro.debug.busySleep(100_000);

//         // // Sleep for some time
//         // var i: u32 = 0;
//         // while (i < 100000) {
//         //     asm volatile ("nop");
//         //     i += 1;
//         // }
//     }
// }
