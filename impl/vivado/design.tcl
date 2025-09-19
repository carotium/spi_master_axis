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

reportCriticalPaths $output_dir/post_synth_crit_path_report.csv

write_vhdl  -force  $output_dir/impl_netlist.vhdl
write_edif  -force  $output_dir/impl_netlist.edif