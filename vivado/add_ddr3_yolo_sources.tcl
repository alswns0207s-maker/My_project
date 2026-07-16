# Run from the root of this package after opening the original VC707 project.
# This adds the DDR3/Yolo integration RTL and the uploaded YOLO modules.
set pkg_dir [file normalize [file dirname [info script]]/..]

add_files -norecurse [glob -nocomplain $pkg_dir/rtl/ddr3/*.v]
add_files -norecurse [glob -nocomplain $pkg_dir/rtl/orig_endpoint/*.v]
add_files -norecurse [glob -nocomplain $pkg_dir/rtl/top/*.v]
add_files -norecurse [glob -nocomplain $pkg_dir/rtl/yolo/*.v]

# Keep existing top until you finish MIG connection. Then set your patched top here.
# set_property top vc707_mb_oss_eth_ddr3_image_yolo_top [current_fileset]
update_compile_order -fileset sources_1
puts "Added DDR3/YOLO integration sources. Next: create MIG 7 Series IP named mig_7series_0 with AXI4 interface."
