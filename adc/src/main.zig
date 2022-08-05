const std = @import("std");
const micro = @import("microzig");
const chip = micro.chip;
const regs = chip.registers;

pub const interrupts = struct {
    pub fn SysTick() void {}

    pub fn EXTI0() void {
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }
};

pub fn main() void {
    chip.init();
    chip.systick(1);

    adc_init();
    while (true) {}
}

fn adc_init() void {
    regs.RCC.APB2ENR.modify(.{ .ADC1EN = 1 }); // enable clock for adc1

    regs.ADC1.CR2.modify(.{ .ADON = 1 }); // wake up ADC
    regs.ADC1.CR2.modify(.{ .CONT = 1 }); // continous mode, 0 for one conversion only

    regs.ADC1.SQR3.modify(.{ .SQ1 = 18 }); // select ADC input channel
    regs.ADC1.SQR1.modify(.{ .L = 1 }); // sequnce length

    regs.ADC_Common.CCR.modify(.{ .TSVREFE = 1 }); // wake up temperature sensor from power down
    regs.ADC_Common.CCR.modify(.{ .ADCPRE = 0b11 }); // prescaler to divide clock by 8
    regs.ADC1.CR2.modify(.{ .SWSTART = 1 }); // start the ADC conversion

    ts.init();

    var fr = async uart_loop();
    while (true) {
        if (regs.ADC_Common.CSR.read().EOC1 == 1) { // end of conversion
            adc_data = regs.ADC1.DR.read().DATA; // read ADC data
            resume uart_frame;
        }
        chip.delay.sleep(1000);
    }
    await fr;
}

var adc_data: u16 = 0;
var uart_frame: anyframe = undefined;

fn uart_loop() void {
    const uart_idx = 2;
    const pins = .{ .tx = micro.Pin("PA2"), .rx = micro.Pin("PA3") };

    var uart = micro.Uart(uart_idx, pins).init(.{
        .baud_rate = 9600,
        .stop_bits = .one,
        .parity = null,
        .data_bits = .eight,
    }) catch {
        return;
    };

    var out = uart.writer();

    var buf: [128]u8 = undefined;
    while (true) {
        suspend {
            uart_frame = @frame();
        }
        const s = std.fmt.bufPrint(buf[0..], "data: {d} ts_cal1: {d} ts_cal2: {d} temp f1: {d} f2: {d} diff: {d}\r\n", .{
            adc_data,
            ts.cal1(),
            ts.cal2(),
            f1(adc_data),
            f2(adc_data),
            f1(adc_data) - f2(adc_data),
        }) catch buf[0..0];
        try out.writeAll(s);
    }
}

// use temperature sensor calibration values
fn f1(x: u16) f32 {
    return ts.slope * @intToFloat(f32, x) + ts.intercept;
}

// use temperatur sensor characteristics
fn f2(x: u16) f32 {
    const v_sense = @intToFloat(f32, x) / 4096 * 3300; // in mV
    return (v_sense - ts_char.v25) / ts_char.avg_slope + 25;
}

const ts_char = struct {
    const avg_slope: f32 = 2.500; // mV/°C
    const v25: f32 = 760; // mV voltage at 25°C
};

// temperature sensor calibration values
const ts = struct {
    var slope: f32 = 0;
    var intercept: f32 = 0;

    const self = @This();

    fn init() void {
        self.slope = @intToFloat(f32, 110 - 30) / @intToFloat(f32, self.cal2() - self.cal1());
        self.intercept = 110 - self.slope * @intToFloat(f32, self.cal2());
    }

    fn cal1() u16 {
        const ptr = @intToPtr(*u16, 0x1FFF7A2C); //TS ADC raw data acquired at temperature of 30 °C, VDDA= 3.3
        return ptr.*;
    }

    fn cal2() u16 {
        const ptr = @intToPtr(*u16, 0x1FFF7A2E); //TS ADC raw data acquired at temperature of 110 °C, VDDA= 3.3 V
        return ptr.*;
    }
};
