const std = @import("std");
const micro = @import("microzig");
const chip = micro.chip;
const regs = chip.registers;

pub const interrupts = struct {
    pub fn SysTick() void {}

    pub fn EXTI0() void {
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }

    pub fn ADC() void {
        adc_conversions += 1;
    }
};

pub fn main() void {
    chip.init();
    chip.systick(1);

    // enable IRQ ADC_IRQn = 18
    regs.NVIC.ISER0.modify(.{ .SETENA = 0x4_0000 });

    adc_init();
    dma_init();
    ts.init();

    var fr = async uart_loop();
    while (true) {
        // if (regs.ADC_Common.CSR.read().EOC1 == 1) { // end of conversion
        adc_data = regs.ADC1.DR.read().DATA; // read ADC data
        //     resume uart_frame;
        // }
        chip.delay.sleep(1000);
        resume uart_frame;
    }
    await fr;
}

var adc_dma_data: [2]u16 = .{ 0, 0 };
var adc_conversions: u32 = 0;

fn adc_init() void {
    regs.RCC.APB2ENR.modify(.{ .ADC1EN = 1 }); // enable clock for adc1

    regs.ADC_Common.CCR.modify(.{ .TSVREFE = 1 }); // wake up temperature sensor from power down

    regs.ADC1.CR2.modify(.{ .ADON = 0 }); // disable ADC
    regs.ADC1.CR2.modify(.{ .CONT = 1 }); // continous mode, 0 for one conversion only
    regs.ADC1.CR2.modify(.{ .DMA = 1, .DDS = 1 }); // DMA mode enabled
    regs.ADC1.CR2.modify(.{ .EOCS = 1 }); // The EOC bit is set at the end of each regular conversion.

    regs.ADC1.SQR3.modify(.{ .SQ1 = 18, .SQ2 = 17 }); // select ADC input channel
    regs.ADC1.SQR1.modify(.{ .L = 0b0001 }); // sequnce length = 2 conversions
    regs.ADC1.CR1.modify(.{ .SCAN = 1 }); // scan mode must be set, if you are using more than 1 channel for the ADC
    regs.ADC1.CR1.modify(.{ .RES = 0b000 }); // resolution of the conversion, 12-bit (15 ADCCLK cycles), 0 to 4095
    regs.ADC1.SMPR1.modify(.{ .SMP18 = 0b111, .SMP17 = 0b111 }); // 480 cycles for this channels (default 3)
    // ADCCLK = APB2 / prescaler, max 18 MHz
    // This clock is generated from the APB2 clock divided by a programmable prescaler
    // that allows the ADC to work at fPCLK2/2, /4, /6 or /8. Max clock is 18 MHz
    regs.ADC_Common.CCR.modify(.{ .ADCPRE = 0b11 }); // prescaler to divide clock by 8

    regs.ADC1.CR1.modify(.{ .EOCIE = 1 }); // enable interrupt

    regs.ADC1.SR.modify(.{ .EOC = 0, .OVR = 0, .STRT = 0 }); // clear status register
    regs.ADC1.CR2.modify(.{ .ADON = 1 }); // enable ADC
    regs.ADC1.CR2.modify(.{ .SWSTART = 1 }); // start the ADC conversion
}

fn dma_init() void {
    regs.RCC.AHB1ENR.modify(.{ .DMA2EN = 1 }); // enable clock for dma2

    regs.DMA2.S0CR.modify(.{ .EN = 0 }); // disable DMA
    regs.DMA2.S0CR.modify(.{
        .DIR = 0b00, // direction peripheral to memoy
        .CIRC = 1, // circular mode
        .MINC = 1, // memory increment mode
        .PINC = 0, // periperal no incerment
        .MSIZE = 0b01, // memory data size 16 bits
        .PSIZE = 0b01, // peripheral data size 16 bits
        .CHSEL = 0b000, // channel 0 sleected
    });
    regs.DMA2.S0NDTR.modify(.{ .NDT = 2 }); // number of data items, that we want transfer using the DMA
    regs.DMA2.S0PAR.modify(.{ .PA = @ptrToInt(regs.ADC1.DR) }); // address of the Peripheral Register, ADC1 DR
    regs.DMA2.S0M0AR.modify(.{ .M0A = @ptrToInt(&adc_dma_data) }); // memory destination address
    regs.DMA2.S0CR.modify(.{ .EN = 1 }); // enable DMA
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
        const s1 = std.fmt.bufPrint(buf[0..], "dma {d} {d}\r\n", .{ adc_dma_data[0], adc_dma_data[1] }) catch buf[0..0];
        try out.writeAll(s1);

        // const s2 = std.fmt.bufPrint(buf[0..], "dr {d}\r\n", .{adc_data}) catch buf[0..0];
        // try out.writeAll(s2);

        const ts_data = adc_dma_data[0];
        if (ts_data == 0) {
            continue;
        }
        const s3 = std.fmt.bufPrint(buf[0..], "data: {d} temperature: {d} C\r\n", .{
            ts_data,
            f2(ts_data),
        }) catch buf[0..0];
        try out.writeAll(s3);

        const vref = adc_dma_data[1];
        const s4 = std.fmt.bufPrint(buf[0..], "data: {d} vref int: {d} V\r\n", .{
            vref,
            @intToFloat(f32, vref) / 0xfff * 3.3,
        }) catch buf[0..0];
        try out.writeAll(s4);

        const s2 = std.fmt.bufPrint(buf[0..], "adc conversions {d}\r\n", .{adc_conversions}) catch buf[0..0];
        try out.writeAll(s2);
    }
}

// use temperature sensor calibration values
fn f1(x: u16) f32 {
    return ts.slope * @intToFloat(f32, x) + ts.intercept;
}

// use temperatur sensor characteristics
fn f2(x: u16) f32 {
    const v_sense = @intToFloat(f32, x) / 0xfff * 3300; // in mV
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
