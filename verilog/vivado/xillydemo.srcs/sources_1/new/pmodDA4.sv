`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/04/11 23:24:56
// Design Name: 
// Module Name: pmodDA4
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
module pmodDA4 (
                    ad_rcv_intfc.da t,
                    input logic datClk,
                    input logic rst,
                    
                    output logic SYNC,              
                    output logic SDA,
                    
                    input logic [11:0] wData
                    );
    enum {stIdle, stInternalRef, stRefSync, stRefTx, stInit, stSync, stTx, stDone} st;
    
    logic [3:0] cmd = 4'b0011; // write and update channel n, 0010: write and update all channels
    logic [3:0] addr = 4'b1111; // select all channels
    logic [7:0] endBits;
    logic [31:0] data;
    shortint ind = 31; // shift register, shift MSB to DA register first
    logic done = 0;
    
    assign SCLK = datClk;
    assign data = {4'b0000, cmd, addr, wData, endBits};
    assign SDA = (done) ? data[ind] : 1'b0;

    // Power-on reset
//    always_comb begin
//        cmd = (st == stRst) ? 4'b0111 : 4'b0011;
//    end
    // Set internal reference
    always_comb begin
        cmd = ((st == stInternalRef) || (st == stRefSync) || (st == stRefTx)) ? 4'b1000 : 4'b0011;
        endBits = ((st == stInternalRef) || (st == stRefSync) || (st == stRefTx)) ? 8'b0000_0001 : 'b0;
    end
    
    always_ff @(negedge datClk) begin
        if (~rst) begin
            st <= stIdle;
            ind <= 31;
            SYNC <= 1'b1;
            done <= 1'b0;
            t.da_send_done <= 1'b0;
        end
        else begin
            case (st)
                stIdle: begin
                    st <= stInternalRef;
                    ind <= 31;
                    SYNC <= 1'b1;
                    done <= 1'b0;
                    t.da_send_done <= 1'b0;
                end
                stInternalRef: begin
                    st <= stRefTx;
                    ind <= 31;
                    SYNC <= 1'b0;
                    done <= 1'b1;
                    t.da_send_done <= 1'b0;
                end
//                stRefSync: begin
//                    st <= stRefTx;
//                    ind <= 31;
//                    SYNC <= 1'b0;
//                    done <= 1'b1;
//                    t.da_send_done <= 1'b0;
//                end
                stRefTx: begin
                    st <= (ind == 0) ? stInit : stRefTx;
                    ind <= ind - 1;
                    SYNC <= (ind == 0) ? 1'b1 : 1'b0;
                    done <= (ind == 0) ? 1'b0 : 1'b1;
                    t.da_send_done <= 1'b0;
                end
                stInit: begin
                    st <= (t.sig_out_rdy) ? stTx : stInit;
                    ind <= 31;
                    SYNC <= (t.sig_out_rdy) ? 1'b0 : 1'b1;
                    done <= (t.sig_out_rdy) ? 1'b1 : 1'b0;
                    t.da_send_done <= 1'b0;
                end
//                stSync: begin
//                    st <= stTx;
//                    ind <= 31;
//                    SYNC <= 1'b0;
//                    done <= 1'b0; //
//                    t.da_send_done <= 1'b0;
//                end
                stTx: begin
                    st <= (ind == 0) ? stInit : stTx;
                    ind <= ind - 1;
                    SYNC <= (ind == 0) ? 1'b1 : 1'b0;
                    done <= (ind == 0) ? 1'b0 : 1'b1;
                    t.da_send_done <= (ind == 0) ? 1'b1 : 1'b0;
                end
//                stDone: begin
//                    st <= (t.sig_out_rdy) ? stInit : stDone;
//                    ind <= 31;
//                    SYNC <= 1'b1;
//                    done <= 1'b0;
//                    t.da_send_done <= 1'b1;
//                end
                default: begin
                    st <= stIdle;
                    ind <= 31;
                    SYNC <= 1'b1;
                    done <= 1'b0;
                    t.da_send_done <= 1'b0;
                end 
            endcase
        end
    end
endmodule