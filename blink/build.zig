const std = @import("std");
const micro = @import("lib/microzig/src/main.zig");

pub fn build(b: *std.build.Builder) !void {
    const backing = .{
        .chip = micro.chips.stm32f407vg, // ovaj hoce
        //.chip = micro.chips.nrf52832, // ovaj ni nema parse pin
        //.chip = micro.chips.stm32f429zit6u,  // ovaj isto nece
        //.chip = micro.chips.stm32f303vc,  // ovaj nece
    };

    // const stm32411 = micro.Chip{
    //     .name = "stm32411",
    //     .path = "lib/stm32411.zig",
    //     .cpu = micro.cpus.cortex_m4,
    //     .memory_regions = &.{
    //         .{ .offset = 0x08000000, .length = 512 * 1024, .kind = .flash }, // 512 Kbytes (st32f411cE)
    //         .{ .offset = 0x20000000, .length = 128 * 1024, .kind = .ram }, // 128 Kbytes
    //     },
    // };
    // const backing = .{
    //     .chip = stm32411,
    // };

    const bin = try micro.addEmbeddedExecutable(
        b,
        "blink.elf",
        "src/main.zig",
        backing,
        .{
            // optional slice of packages that can be imported into your app:
            // .packages = &my_packages,
        },
    );
    bin.setBuildMode(.ReleaseSmall);

    const bin_path = b.getInstallPath(.{ .bin = .{} }, bin.out_filename);
    const flash_cmd = b.addSystemCommand(&[_][]const u8{
        "/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin/STM32_Programmer_CLI",
        "-c",
        "port=usb1",
        "-d",
        bin_path,
        "--go",
    });
    flash_cmd.step.dependOn(b.getInstallStep());
    const flash_step = b.step("flash", "Flash and run the app on your STM32F411");
    flash_step.dependOn(&flash_cmd.step);

    b.default_step.dependOn(&bin.step);
    bin.install();
}
