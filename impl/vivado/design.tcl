# Define input and output directory area

set script_path [ file dirname [ file normalize [ info script] ] ]
set project_root_dir $script_path/../../.
set source_dir $project_root_dir/.

set_part xc7z020clg484-1

set output_dir $script_path/output/.
file mkdir $output_dir

# Setup design sources and constraints

read_vhdl [ glob $source_dir/spi_master_axis.vhd]
read_xdc $script_path/zedboard.xdc

# Run synthesis
synth_design -top spi_master_axis_top
write_checkpoint -force $output_dir/post_synth.dcp
report_timing_summary -file $output_dir/post_synth_timing_summary.rpt
report_utilization -file $output_dir/post_synth_util.rpt
