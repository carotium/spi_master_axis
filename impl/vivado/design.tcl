#------------------------------------------------------------------------
# reportCriticalPaths
#------------------------------------------------------------------------
# This function generates a CSV file that provides a summary of the first
# 50 violations for both Setup and Hold analysis. So a maximum number of 
# 100 paths are reported.
#------------------------------------------------------------------------
proc reportCriticalPaths { fileName } {
  # Open the specified output file in write mode
  set FH [open $fileName w]
  # Write the current date and CSV format to a file header
  puts $FH "#\n# File created on [clock format [clock seconds]]\n#\n"
  puts $FH "Startpoint,Endpoint,DelayType,Slack,#Levels,#LUTs"
  # Iterate through both Min and Max delay types
  foreach delayType {max min} {
    # Collect details from the 50 worst timing paths for the current analysis 
    # (max = setup/recovery, min = hold/removal) 
    # The $path variable contains a Timing Path object.
    foreach path [get_timing_paths -delay_type $delayType -max_paths 50 -nworst 1] {
      # Get the LUT cells of the timing paths
      set luts [get_cells -filter {REF_NAME =~ LUT*} -of_object $path]
      # Get the startpoint of the Timing Path object
      set startpoint [get_property STARTPOINT_PIN $path]
      # Get the endpoint of the Timing Path object
      set endpoint [get_property ENDPOINT_PIN $path]
      # Get the slack on the Timing Path object
      set slack [get_property SLACK $path]
      # Get the number of logic levels between startpoint and endpoint
      set levels [get_property LOGIC_LEVELS $path]
      # Save the collected path details to the CSV file
      puts $FH "$startpoint,$endpoint,$delayType,$slack,$levels,[llength $luts]"
    }
  }
  # Close the output file
  close $FH
  puts "CSV file $fileName has been created.\n"
  return 0
}; # End PROC
#
#
# Run 'vivado -mode batch -source design.tcl' 
#
# Define input and output directory area
#
set script_path         [ file dirname [ file normalize [ info script] ] ]
set project_root_dir    $script_path/../../.
set source_dir          $project_root_dir/.
#
# Genesys2 board 
set_part xc7k325tffg900-2
# Zedboard
#set_part xc7z020clg484-1
#
set output_dir $script_path/output/.
file mkdir $output_dir
#
# Setup design sources and constraints
#
read_vhdl   [glob $source_dir/spi_master_wrapper.vhd]
read_vhdl   [ glob $source_dir/spi_master_axis.vhd]
#read_xdc    $script_path/zedboard.xdc
read_xdc    $script_path/genesys.xdc
#
# Run synthesis, write design checkpoint, report timing
# and uzilization estimates
#
synth_design            -top    spi_master_wrapper
write_checkpoint        -force  $output_dir/post_synth
report_timing_summary   -file   $output_dir/post_synth_timing_summary.rpt
#report_power            -file   $output_dir/post_synth_power.rpt
report_utilization      -file   $output_dir/post_synth_util.rpt
#
# Report critical timing paths
#
reportCriticalPaths $output_dir/post_synth_crit_path_report.csv
#
# Run logic optimization, placement and physical logic implementation,
# write design checkpoint, report utilization and timing estimates.
#
opt_design
reportCriticalPaths $output_dir/post_opt_critpath_report.csv
place_design
report_clock_utilization -file $output_dir/clock_util.rpt
#
# Optionally run optimization if there are timing violations after placement
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
    puts "Found setup timing violations => running physical optimization"
    phys_opt_design
}
write_checkpoint        -force  $output_dir/post_place.dcp
report_utilization      -file   $output_dir/post_place_util.rpt
report_timing_summary   -file   $output_dir/post_place_timing_summary.rpt
#
# Run the router, write the post-route design checkpoint, report the routing
# status, report timing, power and DRC, and finally save the VHDL netlist.
#
route_design
write_checkpoint            -force  $output_dir/post_route.dcp
report_route_status         -file   $output_dir/post_route_status.rpt
report_timing_summary       -file   $output_dir/post_route_timing_summary.rpt
report_power                -file   $output_dir/post_route_power.rpt
report_drc                  -file   $output_dir/post_imp_drc.rpt
write_verilog               -force  $output_dir/impl_netlist.vhdl -mode timesim -sdf_anno true
#
write_edif                  -force  $output_dir/impl_netlist.edif
#
# Generate a bitstream
#
write_bitstream             -force  $output_dir/spi_master.bit