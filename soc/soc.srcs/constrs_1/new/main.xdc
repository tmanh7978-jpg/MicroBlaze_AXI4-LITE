## ZedBoard XC7Z020-CLG484-1 -- 4 LEDs + external PL clock + active-low reset via SW0
## Apply ONLY if the Vivado project part is xc7z020clg484-1 and the actual board is ZedBoard.
## From Digilent ZedBoard master XDC, LED bank 33, oscillator bank 13, SW0 bank 35.

## 100 MHz on-board PL clock (GCLK)
set_property PACKAGE_PIN Y9 [get_ports {sys_clock}]
set_property IOSTANDARD LVCMOS33 [get_ports {sys_clock}]
create_clock -name sys_clock_pin -period 10.000 [get_ports {sys_clock}]

## User LEDs LD0-LD3 (Bank 33)
set_property PACKAGE_PIN T22 [get_ports {led_out[0]}]
set_property PACKAGE_PIN T21 [get_ports {led_out[1]}]
set_property PACKAGE_PIN U22 [get_ports {led_out[2]}]
set_property PACKAGE_PIN U21 [get_ports {led_out[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out[3]}]

## SW0 as active-low system reset input (Bank 35)
## Switch ON -> logic 1 (reset released), OFF -> logic 0 (reset asserted)
## Ensure the reset IP input genuinely expects active-low reset.
set_property PACKAGE_PIN F22 [get_ports {sys_reset_n[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sys_reset_n[0]}]
