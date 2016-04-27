@echo off
set xv_path=D:\\Xilinx\\Vivado\\2015.1\\bin
call %xv_path%/xelab  -wto 1ff02c9557344e22bbf25fbd77c8be91 -m64 --debug typical --relax --mt 2 --include "../../../../../../vivado-essentials/vivado_system/ip/vivado_system_auto_pc_0/axi_infrastructure_v1_1/hdl/verilog" --include "../../../../../../vivado-essentials/vivado_system/ip/vivado_system_processing_system7_0_0" --include "../../../../../../vivado-essentials/vivado_system/ip/vivado_system_processing_system7_0_0/hdl" --include "../../../../../../vivado-essentials/vivado_system/ip/vivado_system_xbar_0/axi_infrastructure_v1_1/hdl/verilog" -L xil_defaultlib -L unisims_ver -L secureip --snapshot data_acquis_dut_func_impl xil_defaultlib.data_acquis_dut xil_defaultlib.glbl -log elaborate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
