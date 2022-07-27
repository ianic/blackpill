const micro = @import("microzig");
const regs = micro.chip.registers;

pub const interrupts = struct {
    pub fn SysTick() void {
        //led.toggle();
        //@panic("hit systick!");
        //clicked += 1;
    }

    pub fn EXTI0() void {
        counter += 1;
        blink(counter);
        //led.toggle();
        //@panic("unhandled interrupt");
        // clicked += 1;
        // if (delay == 200_000) {
        //     delay = 1_000_000;
        // } else {
        //
        //delay = 200_000;
        // }
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }
};

const short = 200_000;
const long = 1_000_000;
var clicked: u32 = 1;
var delay: u32 = 200_000;
var counter: u32 = 0;

const led_pin = micro.Pin("PC13");
const led = micro.Gpio(led_pin, .{
    .mode = .output,
    .initial_state = .high,
});

const key_pin = micro.Pin("PA0");
const key = micro.Gpio(key_pin, .{
    .mode = .input,
    .initial_state = .high,
});

fn blink(times: u32) void {
    var i: u32 = 0;
    while (i < times) : (i += 1) {
        led.setToLow();
        sleep(delay);
        led.setToHigh();
        sleep(delay);
    }
}

pub fn main() void {
    //systemInit();
    setup();
    //led.toggle();
    blink(3);

    while (true) {
        //const delay: u32 = if (clicked % 2 == 0) long else short;
        sleep(delay);
        //led.toggle();

        //const state = key.read();
        //led.write(state);
        //@panic("try to panic");
    }
}

fn sleep(duration: u32) void {
    var i: u32 = 0;
    while (i < duration) {
        asm volatile ("nop");
        i += 1;
    }
}

fn setup() void {
    // // Enable HSI
    // regs.RCC.CR.modify(.{ .HSION = 1 });

    // // Wait for HSI ready
    // while (regs.RCC.CR.read().HSIRDY != 1) {}

    // // Select HSI as clock source
    // regs.RCC.CFGR.modify(.{ .SW0 = 0, .SW1 = 0 });

    // // Enable external high-speed oscillator (HSE)
    // regs.RCC.CR.modify(.{ .HSEON = 1 });

    led.init();
    key.init();

    // PA0
    //micro.interrupts.sei();

    regs.SYSCFG.EXTICR1.modify(.{ .EXTI0 = 1 });
    regs.EXTI.RTSR.modify(.{ .TR0 = 1 });
    regs.EXTI.IMR.modify(.{ .MR0 = 1 });

    regs.NVIC.ISER0.modify(.{ .SETENA = 0x40 });
}

fn systemInit() void {
    // This init does these things:
    // - Enables the FPU coprocessor
    // - Sets the external oscillator to achieve a clock frequency of 168MHz
    // - Sets the correct PLL prescalers for that clock frequency
    // - Enables the flash data and instruction cache and sets the correct latency for 168MHz

    // Enable FPU coprocessor
    // WARN: currently not supported in qemu, comment if testing it there
    regs.FPU_CPACR.CPACR.modify(.{ .CP = 0b11 });

    // Enable HSI
    regs.RCC.CR.modify(.{ .HSION = 1 });

    // Wait for HSI ready
    while (regs.RCC.CR.read().HSIRDY != 1) {}

    // Select HSI as clock source
    regs.RCC.CFGR.modify(.{ .SW0 = 0, .SW1 = 0 });

    // Enable external high-speed oscillator (HSE)
    regs.RCC.CR.modify(.{ .HSEON = 1 });

    // Wait for HSE ready
    while (regs.RCC.CR.read().HSERDY != 1) {}

    // Set prescalers for 168 MHz: HPRE = 0, PPRE1 = DIV_2, PPRE2 = DIV_4
    regs.RCC.CFGR.modify(.{ .HPRE = 0, .PPRE1 = 0b101, .PPRE2 = 0b100 });

    // Disable PLL before changing its configuration
    regs.RCC.CR.modify(.{ .PLLON = 0 });

    // Set PLL prescalers and HSE clock source
    // TODO: change the svd to expose prescalers as packed numbers instead of single bits
    regs.RCC.PLLCFGR.modify(.{
        .PLLSRC = 1,
        // PLLM = 8 = 0b001000
        .PLLM0 = 0,
        .PLLM1 = 0,
        .PLLM2 = 0,
        .PLLM3 = 1,
        .PLLM4 = 0,
        .PLLM5 = 0,
        // PLLN = 336 = 0b101010000
        .PLLN0 = 0,
        .PLLN1 = 0,
        .PLLN2 = 0,
        .PLLN3 = 0,
        .PLLN4 = 1,
        .PLLN5 = 0,
        .PLLN6 = 1,
        .PLLN7 = 0,
        .PLLN8 = 1,
        // PLLP = 2 = 0b10
        .PLLP0 = 0,
        .PLLP1 = 1,
        // PLLQ = 7 = 0b111
        .PLLQ0 = 1,
        .PLLQ1 = 1,
        .PLLQ2 = 1,
    });

    // Enable PLL
    regs.RCC.CR.modify(.{ .PLLON = 1 });

    // Wait for PLL ready
    while (regs.RCC.CR.read().PLLRDY != 1) {}

    // Enable flash data and instruction cache and set flash latency to 5 wait states
    regs.FLASH.ACR.modify(.{ .DCEN = 1, .ICEN = 1, .LATENCY = 5 });

    // Select PLL as clock source
    regs.RCC.CFGR.modify(.{ .SW1 = 1, .SW0 = 0 });

    // Wait for PLL selected as clock source
    var cfgr = regs.RCC.CFGR.read();
    while (cfgr.SWS1 != 1 and cfgr.SWS0 != 0) : (cfgr = regs.RCC.CFGR.read()) {}

    // Disable HSI
    regs.RCC.CR.modify(.{ .HSION = 0 });
}
