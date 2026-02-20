open_project C:/Xilinx/Project/RISC-V/RISC-V.xpr
update_compile_order -fileset sources_1
set_property CONFIG.Coe_File {c:/Users/harry/Desktop/Project/RISCV/RISC-V-Processor/Testbench/IM.coe} [get_ips blk_mem_gen_0]
generate_target all [get_files  C:/Xilinx/Project/RISC-V/RISC-V.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci]
export_ip_user_files -of_objects [get_files C:/Xilinx/Project/RISC-V/RISC-V.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci] -no_script -sync -force -quiet
export_simulation -lib_map_path [list {modelsim=C:/Xilinx/Project/RISC-V/RISC-V.cache/compile_simlib/modelsim} {questa=C:/Xilinx/Project/RISC-V/RISC-V.cache/compile_simlib/questa} {riviera=C:/Xilinx/Project/RISC-V/RISC-V.cache/compile_simlib/riviera} {activehdl=C:/Xilinx/Project/RISC-V/RISC-V.cache/compile_simlib/activehdl}] -of_objects [get_files C:/Xilinx/Project/RISC-V/RISC-V.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci] -directory C:/Xilinx/Project/RISC-V/RISC-V.ip_user_files/sim_scripts -ip_user_files_dir C:/Xilinx/Project/RISC-V/RISC-V.ip_user_files -ipstatic_source_dir C:/Xilinx/Project/RISC-V/RISC-V.ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
launch_simulation
run all
close_sim
close_project