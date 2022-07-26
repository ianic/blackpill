skinio svd sa: https://github.com/posborne/cmsis-svd/blob/master/data/STMicro/STM32F411.svd
wget https://raw.githubusercontent.com/posborne/cmsis-svd/master/data/STMicro/STM32F411.svd

clone regz 
napravio regz-om zig file iz svd

../regz/zig-out/bin/regz STM32F411.svd > stm32411.zig

brew install stlink
https://github.com/stlink-org/stlink


### programming
alias stm=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin/STM32_Programmer_CLI

stm -c port=usb1 -d ~/code/zig/embeded/blackpill/blink/zig-out/bin/blink.elf --go



### References
board:   
https://stm32-base.org/boards/STM32F411CEU6-WeAct-Black-Pill-V2.0.html
https://github.com/WeActStudio/WeActStudio.MiniSTM32F4x1
https://github.com/WeActStudio/WeActStudio.MiniSTM32F4x1/blob/master/images/STM32F4x1_PinoutDiagram_RichardBalint.png

cpu documents download page:  
https://www.st.com/en/microcontrollers-microprocessors/stm32f411ce.html#
