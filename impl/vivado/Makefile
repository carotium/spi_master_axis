.PHONY: all synth clean

all: synth

synth: output/impl_netlist.vhd

output/impl_netlist.vhd:
	vivado -mode batch -source design.tcl

clean:
	rm -rf output/ *.jou *.log