set processor_root {C:/Users/harry/Desktop/Project/risc-v/RISC-V-Processor}
set repository_root {C:/Users/harry/Desktop/Project/risc-v}
set simulation_project ${processor_root}/.vivado_processor_sim

if {[file exists ${simulation_project}]} {
    file delete -force ${simulation_project}
}

create_project processor_axi4_sim ${simulation_project} \
    -part xc7z010clg400-1 -force

set processor_sources [list]
foreach source_file [glob -nocomplain \
    ${processor_root}/RTL/*.v ${processor_root}/RTL/*.sv] {
    if {[file tail ${source_file}] ne {RISCV_PROCESSOR_tb.v}} {
        lappend processor_sources ${source_file}
    }
}

add_files -fileset sources_1 -norecurse ${processor_sources}
add_files -fileset sources_1 -norecurse \
    ${repository_root}/CACHE/I-CACHE/I_Cache.sv
add_files -fileset sources_1 -norecurse \
    ${repository_root}/CACHE/D-CACHE/D_Cache.sv
add_files -fileset sources_1 -norecurse \
    ${repository_root}/CACHE/AXI4/AXI4_Bus.sv

add_files -fileset sim_1 -norecurse \
    ${processor_root}/RTL/RISCV_PROCESSOR_tb.v
add_files -fileset sim_1 -norecurse \
    ${repository_root}/CACHE/AXI4/CHECKER.sv

set_property include_dirs [list ${processor_root}/RTL] [get_filesets sources_1]
set_property include_dirs [list ${processor_root}/RTL] [get_filesets sim_1]
set_property top RISCV_PROCESSOR [get_filesets sources_1]
set_property top RISCV_PROCESSOR_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
close_project
exit
