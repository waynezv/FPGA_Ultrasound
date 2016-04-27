`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/04/10 10:21:23
// Design Name: 
// Module Name: data_acquis_dut
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module data_acquis_dut;

logic clk_100;
logic SCLK = 1'b0;
logic SDATA;

data_acquis_controller DAQ_control(.clk_100(clk_100), .SDATA(SDATA), .SCLK(SCLK));

parameter MAX_NUM = 16;
bit [MAX_NUM:0] ad_data;
//class randomData;
//    localparam MAX_NUM = 16;
//    local bit [MAX_NUM:0] ad_data;
//    local bit [15:0] ad_data2[MAX_NUM];
//    local byte seq_num;
    
    task sendRandomData;
        for (byte i=0; i<MAX_NUM; i++)
                ad_data[i] = $urandom_range(1, 0);
        foreach (ad_data[j]) begin @(posedge clk_100) SDATA <= ad_data[j]; end
    endtask
    
//    function void makeRandomData (output bit [MAX_NUM:0] ad_data);
//        for (byte i=0; i<MAX_NUM; i++)
//            ad_data[i] = $urandom_range(1, 0);
//    endfunction
//endclass

initial begin
//    randomData randData;
    clk_100 = 0;
//    bus_clk = 0;
//    forever #1 bus_clk = ~bus_clk;
    forever #5 clk_100 = ~clk_100;
//    @(negedge bus_clk) RST <= 0;
//    @(negedge bus_clk) RST <= 1;
//    @(posedge bus_clk) START <= 0;
//    @(posedge bus_clk) START <= 1;
    sendRandomData;
//    randsequence (main)
//        main: first second;
//        first: {randData.makeRandomData;};
//        second: {repeat ($urandom_range(5, 1)) randData.sendRandomData;};
//    endsequence
    @(posedge clk_100);
end

endmodule
