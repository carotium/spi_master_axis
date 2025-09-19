# Run 'vivado -mode batch -source design.tcl' 

# Define input and output directory area

set script_path         [ file dirname [ file normalize [ info script] ] ]
set project_root_dir    $script_path/../../.
set source_dir          $project_root_dir/.

set_part xc7z020clg484-1

set output_dir $script_path/output/.
file mkdir $output_dir

# Setup design sources and constraints

read_vhdl   [ glob $source_dir/spi_master_axis.vhd]
read_xdc    $script_path/zedboard.xdc

# Run synthesis
synth_design            -top    spi_master_axis
write_checkpoint        -force  $output_dir/post_synth
report_timing_summary   -file   $output_dir/post_synth_timing_summary.rpt
report_power            -file   $output_dir/post_synth_power.rpt
report_utilization      -file   $output_dir/post_synth_util.rpt

write_vhdl  -force  $output_dir/impl_netlist.vhdl
write_edif  -force  $output_dir/impl_netlist.edif