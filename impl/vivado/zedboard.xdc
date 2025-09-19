set_property PACKAGE_PIN R6 [get_ports spi_ss_o]
set_property PACKAGE_PIN T4 [get_ports spi_miso_i]
set_property PACKAGE_PIN U4 [get_ports spi_sclk_o]

#set_property PACKAGE_PIN T22 [get_ports M_O_RX_DATA[0]]
#set_property PACKAGE_PIN T21 [get_ports M_O_RX_DATA[1]]
#set_property PACKAGE_PIN U22 [get_ports M_O_RX_DATA[2]]
#set_property PACKAGE_PIN U21 [get_ports M_O_RX_DATA[3]]
#set_property PACKAGE_PIN V22 [get_ports M_O_RX_DATA[4]]
#set_property PACKAGE_PIN W22 [get_ports M_O_RX_DATA[5]]
#set_property PACKAGE_PIN U19 [get_ports M_O_RX_DATA[6]]
#set_property PACKAGE_PIN U14 [get_ports M_O_RX_DATA[7]]

set_property PACKAGE_PIN F22 [get_ports {spi_packet_mode[0]}];  # "SW0"
set_property PACKAGE_PIN G22 [get_ports {spi_packet_mode[1]}];  # "SW1"
set_property PACKAGE_PIN H22 [get_ports {spi_packet_mode[2]}];  # "SW2"
set_property PACKAGE_PIN F21 [get_ports {spi_packet_mode[3]}];  # "SW3"
set_property PACKAGE_PIN H19 [get_ports {spi_packet_mode[4]}];  # "SW4"
set_property PACKAGE_PIN H18 [get_ports {spi_packet_mode[5]}];  # "SW5"
set_property PACKAGE_PIN H17 [get_ports {spi_packet_mode[6]}];  # "SW6"
set_property PACKAGE_PIN M15 [get_ports {spi_packet_mode[7]}];  # "SW7"

set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 33]]
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 34]]
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 35]];
set_property IOSTANDARD LVCMOS33 [get_ports -of_objects [get_iobanks 13]]