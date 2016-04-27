`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/04/15 10:44:19
// Design Name: 
// Module Name: da_dut
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

module da_dut(
                    ad_rcv_intfc.da t,
                    input logic datClk,
                    input logic rst,
                    
                    output logic SYNC,              
                    output logic SDA,
                    
                    input logic [11:0] wData
                    );
    enum {stRst, stRstTx, stRstSync, stInit, stSync, stTx, stDone} st;
    
    logic [3:0] cmd = 4'b0011; // write and update channel n, 0010: write and update all channels
    logic [3:0] addr = 4'b1111; // select all channels
    logic [31:0] data;
    shortint ind = 31; // shift register, shift MSB to DA register first
    logic done = 0;
    
    assign SCLK = datClk;
    assign data = {4'bx, cmd, addr, wData, 8'bx};
    assign SDA = (done) ? data[ind] : 1'bx;

    // Power-on reset
    always_comb begin
        cmd = (st == stRst) ? 4'b0111 : 4'b0011;
    end
    
    always_ff @(negedge datClk) begin
        if (~rst) begin
//            st <= stRst;
            st <= stInit;
            ind <= 31;
            SYNC <= 1'b1;
            done <= 1'b0;
            t.da_send_done <= 1'b0;
        end
        else begin
            case (st)
//                stRst: begin
//                    st <= stRstSync;
//                    ind <= 31;
//                    SYNC <= 1'b0;
//                    done <= 1'b0;
//                    t.da_send_done <= 1'b0;
//                end
//                stRstSync: begin
//                    st <= stRstTx;
//                    ind <= 31;
//                    SYNC <= 1'b0;
//                    done <= 1'b1;
//                    t.da_send_done <= 1'b0;
//                end
//                stRstTx: begin
//                    st <= (ind == 0) ? stInit : stRstTx;
//                    ind <= ind - 1;
//                    SYNC <= 1'b1;
//                    done <= 1'b1;
//                    t.da_send_done <= 1'b0;
//                end
                stInit: begin
                    st <= (t.sig_out_rdy) ? stSync : stInit;
                    ind <= 31;
                    SYNC <= (t.sig_out_rdy) ? 1'b0 : 1'b1;
                    done <= 1'b0;
                    t.da_send_done <= 1'b0;
                end
                stSync: begin
                    st <= stTx;
                    ind <= 31;
                    SYNC <= 1'b0;
                    done <= 1'b1;
                    t.da_send_done <= 1'b0;
                end
                stTx: begin
                    st <= (ind == 0) ? stDone : stTx;
                    ind <= ind - 1;
                    SYNC <= 1'b0;
                    done <= (ind == 0) ? 1'b0 : 1'b1;
                    t.da_send_done <= 1'b0;
                end
                stDone: begin
                    st <= stInit;
                    ind <= 31;
                    SYNC <= 1'b1;
                    done <= 1'b0;
                    t.da_send_done <= 1'b1;
                end
                default: begin
                    st <= stInit;
                    ind <= 31;
                    SYNC <= 1'b1;
                    done <= 1'b0;
                    t.da_send_done <= 1'b0;
                end 
            endcase
        end
    end
endmodule

//+--------------------------------------------------------------------------------------------+
//+                                       Signal Generator                                     +
//+--------------------------------------------------------------------------------------------+
module signal_generator(
                        ad_rcv_intfc.sig_gen t,
                        //
                        input logic START,
                        //
                        input logic clk, rst,
                        output logic [11:0] sig
                        );
logic [11:0] sig_reg = 12'h000;
logic start_gen = 1'b0;
logic done_gen = 1'b0;
enum {idleSt, genSt, doneSt} st;

assign sig = (done_gen) ? sig_reg : 'bx;

always_ff @(posedge clk) begin
    if (rst == 1'b0) begin
        st <= idleSt;
        start_gen <= 1'b0;
        done_gen <= 1'b0;
        sig_reg <= 12'h000;
        t.sig_out_rdy <= 1'b0;
    end
    else begin
        case (st)
            idleSt: begin
//                st <= (t.sig_gen_en) ? (genSt) : (idleSt);
                st <= (START) ? (genSt) : (idleSt);
//                start_gen <= (t.sig_gen_en) ? (1'b1) : (1'b0);
                start_gen <= (START) ? (1'b1) : (1'b0);
                done_gen <= (START) ? 1'b1 : 1'b0;
                t.sig_out_rdy <= 1'b0;
            end
            genSt: begin
                st <= doneSt;
                start_gen <= 1'b0;
                done_gen <= 1'b1;
                //
                sig_reg <= (start_gen) ? (sig_reg + 1'b1) : (sig_reg);
                //
                t.sig_out_rdy <= 1'b1;
            end
            doneSt: begin
                st <= (t.da_send_done) ? (genSt) : (doneSt);
                start_gen <= (t.da_send_done) ? 1'b1: 1'b0;
                done_gen <= 1'b1;
                t.sig_out_rdy <= 1'b1;
            end
            default: begin
                st <= idleSt;
                start_gen <= 1'b0;
                done_gen <= 1'b0;
                t.sig_out_rdy <= 1'b0;  
            end
        endcase
    end
end                      
endmodule

//+--------------------------------------------------------------------------------------------+
//+                                        Clock Divider                                       +
//+--------------------------------------------------------------------------------------------+
module clk_divider( // Divide clocks
    input clk_100, rst,
    output sclk_500k, // serial clock for AD
    output sclk_40k // serial clock for generating signals
    );
    
logic fClkInternal = 1'b0;
logic fClkInternal2 = 1'b0;

logic [8:0] divisor = 8'd100; // 100MHz / 500KHz = 200, half divisor is 100
int divisor2 = 1250; // 100MHz / 40KHz = 2500, half divisor is 1250

logic [8:0] count = 8'h00;
int count2 = 0;

assign sclk_500k = fClkInternal;
assign sclk_40k = fClkInternal2;

always_ff @(posedge clk_100) begin
    if (rst == 1'b0) begin
        fClkInternal <= 1'b0;
        fClkInternal <= 1'b0;
        count <= 8'h00;
        count2 <= 0;
    end
    else begin
        if (count == divisor - 1'b1) begin
            fClkInternal <= ~fClkInternal;
            count <= 8'h00;
        end
        else count <= count + 1'b1;
        
        if (count2 == divisor2 - 1) begin
            fClkInternal2 <= ~fClkInternal2;
            count2 <= 0;
        end
        else count2 <= count2 + 1;
    end
end

endmodule: clk_divider
 
//+--------------------------------------------------------------------------------------------+
//+                                      AD-FIFO Interface                                     +
//+--------------------------------------------------------------------------------------------+
interface ad_rcv_intfc( // Interface between the AD module and the fifo
    input clk, rst,
    input START
    );
// for master signal receiving controller
logic read_en;
// for signal generator
logic sig_gen_en;
logic sig_out_rdy;
//for da module
logic da_send_done;
// for ad module
logic ad_out_rdy;
// for data processor
logic data_procOut_rdy;

modport sig_gen (  
                   input clk,
                   input sig_gen_en,
                   input da_send_done,
                   output sig_out_rdy
                   );
                   
modport da (
            input sig_out_rdy,
            output da_send_done
            );
            
modport ad ( //input clk, rst,
            input read_en,
            output ad_out_rdy);
            
modport ad_proc (input clk, rst,
                 input read_en,
                 input ad_out_rdy,
input sig_out_rdy,
                 output data_procOut_rdy);
                 
modport ad_2_fifo (input clk, rst,
                   output read_en,
                   output sig_gen_en
                   );
                   
modport xil_read (input rst,
input read_en,
                  input data_procOut_rdy);

endinterface: ad_rcv_intfc