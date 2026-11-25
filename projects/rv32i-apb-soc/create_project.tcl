set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_project]

create_project rv32i_apb_gpio $project_dir -part xc7a35tcpg236-1 -force
add_files [glob [file join $script_dir rtl *.sv]]
add_files [file join $script_dir rom rom_code_apb_gpio.mem]
add_files -fileset constrs_1 [file join $script_dir constraints Basys3_rv32i_apb_gpio.xdc]
add_files -fileset sim_1 [file join $script_dir sim tb_rv32i_top.sv]

set_property file_type {Memory Initialization Files} \
    [get_files rom_code_apb_gpio.mem]
set_property top rv32i_top [get_filesets sources_1]
set_property top tb_rv32i_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Project created: $project_dir"
puts "Synthesis top: rv32i_top"
puts "Simulation top: tb_rv32i_top"
