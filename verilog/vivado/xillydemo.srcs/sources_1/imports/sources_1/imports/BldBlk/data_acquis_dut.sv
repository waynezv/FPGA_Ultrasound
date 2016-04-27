`timescale 1ns / 1ps
//`default_nettye none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/03/05 10:42:03
// Design Name: Wenbo Zhao
// Module Name:
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

// The multi-channel ultrasound data acquisition module

// +----------------------------------+
// +               TODO               +
// +----------------------------------+
//beam_former(); // generate beam
//pulser(); // send array sequence             
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

//logic [7:0][12:0] sin_wav = {12'd4, 12'd6, 12'd8, 12'd6, 12'd4, 12'd2, 12'd0, 12'd2};
//logic [7:0][11:0] sin_wav = {12'd2048, 12'd3496, 12'd4096, 12'd3496, 12'd2048, 12'd600, 12'd0, 12'd600};
logic [38:0][11:0] sin_wav = {12'd2048, 12'd2377, 12'd2697, 12'd3000, 12'd3278, 12'd3525, 12'd3733, 12'd3898,
                              12'd4015, 12'd4081, 12'd4094, 12'd4055, 12'd3963, 12'd3822, 12'd3634, 12'd3406,
                              12'd3143, 12'd2851, 12'd2538, 12'd2213, 12'd1883, 12'd1558, 12'd1245, 12'd953,
                              12'd690,  12'd462,  12'd274,  12'd133,  12'd41,   12'd2,    12'd15,   12'd81,
                              12'd198,  12'd363,  12'd571,  12'd818,  12'd1096, 12'd1399, 12'd1719
                              };
shortint ind = 38; // count 39 points                             
enum {idleSt, genSt, doneSt} st;

assign sig = (done_gen) ? sig_reg : 'b0;

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
                st <= (t.sig_gen_en) ? (genSt) : (idleSt);
//                st <= (START) ? (genSt) : (idleSt);
                start_gen <= (t.sig_gen_en) ? (1'b1) : (1'b0);
//                start_gen <= (START) ? (1'b1) : (1'b0);
                done_gen <= 1'b0;
                t.sig_out_rdy <= 1'b0;
            end
            genSt: begin
                st <= doneSt;
                start_gen <= 1'b0;
                done_gen <= 1'b1;
                
                sig_reg <= (start_gen) ? (sin_wav[ind]) : (sig_reg);
                ind <= ind - 1;
                if (ind == 0) ind <= 38;
                
                t.sig_out_rdy <= 1'b1;
            end
            doneSt: begin
                st <= (t.da_send_done) ? (idleSt) : (doneSt);
                start_gen <= (t.da_send_done) ? 1'b1: 1'b0;
                done_gen <= 1'b1;
                t.sig_out_rdy <= (t.da_send_done)? 1'b0 : 1'b1;
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
    output sclk_10M, // for sending 8-points, 40KHz sine waves
    output sclk_500k, // serial clock for AD
    output sclk_40k // serial clock for generating signals
    );

logic fClk = 1'b0;  
logic fClkInternal = 1'b0;
logic fClkInternal2 = 1'b0;

int div = 1; // 100MHz / 10Mhz = 10, half is 5;
logic [8:0] divisor = 8'd100; // 100MHz / 500KHz = 200, half divisor is 100
//int divisor2 = 1250; // 100MHz / 40KHz = 2500, half divisor is 1250
int divisor2 = 4000000; // 100MHz / 40KHz = 2500, half divisor is 1250

int cnt = 0;
logic [8:0] count = 8'h00;
int count2 = 0;

assign sclk_10M = fClk;
assign sclk_500k = fClkInternal;
assign sclk_40k = fClkInternal2;

always_ff @(posedge clk_100) begin
//    if (rst == 1'b0) begin // NEVER RESET CLOCK 
//        fClk <= 1'b0;
//        fClkInternal <= 1'b0;
//        fClkInternal2 <= 1'b0;
//        cnt <= 0;
//        count <= 8'h00;
//        count2 <= 0;
//    end
//    else begin
        if (cnt == div - 1) begin
            fClk <= ~fClk;
            cnt <= 0;
        end
        else cnt <= cnt + 1;
                
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
//    end
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

//+--------------------------------------------------------------------------------------------+
//+                                          DSP Module                                        +
//+--------------------------------------------------------------------------------------------+
module ad_processor( // Process ad data
    ad_rcv_intfc.ad_proc t,
    input logic bus_clk,
    input logic proc_en,
    input logic [15:0]  ad_data_in,
    output logic [31:0] ad_data_procOut
    );
logic data_avail;
logic load_data, send_rdy;

logic [31:0] data_reg;

enum {wait_s,  // wait state
      load1,   // load state
      load2,
      done
      } st;

//assign data_avail = 1'b1;
//assign data_avail = (t.ad_out_rdy) ? 1 : 0;
//assign data_avail = (t.sig_out_rdy) ? 1 : 0;
assign data_avail = (proc_en) ? 1 : 0;
//assign ad_data_procOut = (send_rdy) ? data_reg : ('bx);
//assign ad_data_procOut = (send_rdy) ? data_reg : (32'b1111_0000_1111_0000_0101_1010_0101_1010); // debug f0 f0 5a 5a
assign ad_data_procOut = (1) ? data_reg : (32'b1111_0000_1111_0000_0101_1010_0101_1010); // debug f0 f0 5a 5a
//assign ad_data_procOut = (32'b1111_0000_1111_0000_0101_1010_0101_1010); // debug f0 f0 5a 5a

always_ff @(posedge bus_clk) begin
        if (~t.rst) begin
            st <= wait_s;
            load_data <= 1'b0;
            send_rdy <= 1'b0;
            t.data_procOut_rdy <= 1'b0;
        end
        else begin
            case (st)
                wait_s:begin 
                    st <= (t.read_en && data_avail) ? (load1) : (wait_s);
                    load_data <= (t.read_en && data_avail) ? 1'b1 : 1'b0;
                    send_rdy <= 1'b0;
                    t.data_procOut_rdy <= 1'b0;   
                end
                load1: begin
                    st <= (load2);
//                    data_reg[31:16] <= (load_data) ? ad_data_in : 'b0;
                    data_reg[15:0] <= (load_data) ? ad_data_in : 'b0;
                    load_data <=  1'b1;
                    send_rdy <= 1'b0;
                    t.data_procOut_rdy <=  1'b1;
                end
                load2: begin
//                    st <= done;
                    st <= (~t.read_en || ~data_avail) ? wait_s : load1;
//                    data_reg[15:0] <= (load_data) ? ad_data_in : 'b0;
                    data_reg[31:16] <= (load_data) ? ad_data_in : 'b0;
                    load_data <= 1'b0;
                    send_rdy <= 1'b1;
                    t.data_procOut_rdy <=  1'b1;
                end
//                done: begin
//                    st <= (~t.read_en || ~data_avail) ? (wait_s) : (load1);
//                    load_data <= 1'b0;
//                    send_rdy <= 1'b0;
//                    t.data_procOut_rdy <= 1'b1;
//                end
                default: begin
                    st <= wait_s;
                    load_data <= 1'b0;
                    send_rdy <= 1'b0;
                    t.data_procOut_rdy <= 1'b0;
                end
            endcase
        end
end
    
endmodule: ad_processor

//+--------------------------------------------------------------------------------------------+
//+                                     Xillybus Reader                                        +
//+--------------------------------------------------------------------------------------------+
module xilly_reader( // Xillybus controller for sending data upstream to the host
                input capture_clk,
                ad_rcv_intfc.xil_read t,
                
                input logic user_r_read_32_open,
                input logic user_r_read_32_empty,
                input logic capture_full,
                input logic  [31:0] d,
                
                output logic capture_en,               
                output logic [31:0] capture_data,
                output logic user_r_read_32_eof
);

logic        capture_open;
logic        capture_has_been_full;
logic        capture_has_been_nonfull;

//assign capture_en = capture_open && (!capture_full) && (!capture_has_been_full) && (1'b1); // NEED CHECK
assign capture_en = capture_open && (!capture_full) && (!capture_has_been_full) && (t.data_procOut_rdy); // NEED CHECK
//assign capture_en = capture_open && (!capture_full) && (!capture_has_been_full) && (t.read_en); // NEED CHECK
assign user_r_read_32_eof = user_r_read_32_empty && capture_has_been_full;

always_ff @(posedge capture_clk) begin
//        capture_data <= (capture_en) ? (d) : ('b0);
        capture_data <= (capture_en) ? (d) : (32'd5);
//        capture_data <= (capture_en) ? ({d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11], d[12], d[13], d[14], d[15], d[16], d[17], d[18], d[19], d[20], d[21], d[22], d[23], d[24], d[25], d[26], d[27], d[28], d[29], d[30], d[31]}) : ('bz);
        if (capture_full) capture_has_been_nonfull <= 1;
        else if (!capture_open) capture_has_been_nonfull <= 0; 
                
        if (capture_full && capture_has_been_nonfull) capture_has_been_full <= 1;
        else if (!capture_open) capture_has_been_full <= 0;
end
        
// Clock crossing logic: bus_clk -> capture_clk
always @(posedge capture_clk) begin
         capture_open <= user_r_read_32_open;
         end
     
endmodule: xilly_reader

//+--------------------------------------------------------------------------------------------+
//+                                AD-FIFO Signal Controller                                   +
//+--------------------------------------------------------------------------------------------+
module ad_2_fifo_sender (// Master FSM controlling the signals from ad_process_out to FIFO
                        ad_rcv_intfc.ad_2_fifo p,
                        input logic START // master controlling signal for starting the receiving process
                        );
                
logic start_rcv, stop_rcv;
enum {idle, awake} st, nst;

assign start_rcv = START;
assign stop_rcv = ~START;

always_ff @(posedge p.clk) begin
    if (~p.rst) begin
        st <= idle;
        p.read_en <= 1'b0;
        p.sig_gen_en <= 1'b0;
    end
    else begin
        case (st)
            idle: begin
                st <= (start_rcv) ? (awake) : (idle);
//                p.read_en <= (p.da_send_done && start_rcv) ? 1'b1 : 1'b0; 
                p.read_en <= (start_rcv) ? 1'b1 : 1'b0;
                p.sig_gen_en <= (start_rcv) ? 1'b1 : 1'b0;
            end
            awake: begin 
                st <= (stop_rcv) ? (idle) : (awake);
//                p.read_en <= (p.da_send_done) ? 1'b1 : 1'b0; 
                p.read_en <= (stop_rcv) ? 1'b0 : 1'b1;
                p.sig_gen_en <= (stop_rcv) ? 1'b0 : 1'b1;
            end
            default: begin
                st <= idle;
                p.read_en <= 1'b0;
                p.sig_gen_en <= 1'b0;
            end
        endcase
    end
end

endmodule: ad_2_fifo_sender

//+--------------------------------------------------------------------------------------------+
//+                                    AD Module (Depreciated)                                 +
//+--------------------------------------------------------------------------------------------+
//module ad_module ( // Ad module
//    // pmod AD2 interface
//    input logic [7:0] SCH,
//    input logic SDATA,
//    output logic SCLK,
//    // user interface
//    ad_rcv_intfc.ad t,
//    output logic [11:0] ad_data
//    );

//logic divisor = 8'h05; // divide system clock to below 20 MHz
//logic [2:0] clk_counter = 3'b000;

//logic [3:0] shift_counter = 4'h0;
//logic shift_counter_en;
//logic load_en;

//logic start_in, stop_in;

//assign start_in = (t.read_en) ? 1'b1 : 1'b0;
//assign stop_in = ~start_in;

//// states
//enum bit[1:0] {wait_s = 2'b01, // idle
//               shift_in_s = 2'b10, // shift data in
//               load_s = 2'b11 // load data out
//               } st, nst;

//logic [11:0] tmp; // temporarily stores ad data

//logic sclk_reg = 1'b1;
//logic [11:0] data_reg = 12'h000;

//assign SCLK = sclk_reg;
//assign ad_data = data_reg;

//// divide clock
//always_ff @(posedge t.clk) begin
//    if (st == shift_in_s && clk_counter == divisor - 1'b1) clk_counter <= 3'b000;
//    else clk_counter <= clk_counter + 1'b1;

//    if (clk_counter == (divisor - 1'b1 ) / 2 ) sclk_reg <= 1'b1;
//    else if (clk_counter == divisor - 1'b1) sclk_reg <= 1'b0;
//end

//// shift counter
//always_ff @(posedge t.clk) begin
//    if (clk_counter == divisor - 1'b1)
//        if (shift_counter_en) begin
//            tmp <= {tmp[10:0], SDATA};
//            shift_counter <= shift_counter + 1'b1;
//            end
//    if (load_en) begin
//        shift_counter <= 4'h0;
//        data_reg <= tmp[11:0];
//        t.ad_out_rdy <= 1'b1;
//        end
//end

//// state output
//always_ff @(st) begin
//    if (st == wait_s) begin
//        shift_counter_en <= 1'b0;
//        stop_in <= 1'b1;
//        load_en <= 1'b0;
//        end
//    else if (st == shift_in_s) begin
//        shift_counter_en <= 1'b1;
//        stop_in <= 1'b0;
//        load_en <= 1'b0;
//        end
//    else if (st == load_s) begin
//        shift_counter_en = 1'b0;
//        stop_in <= 1'b0;
//        load_en <= 1'b1;
//        end
//end

//// sync & reset
//always_ff @(posedge t.clk, negedge t.rst) begin
//    if (~t.rst) st <= wait_s;
//    else st <= nst;
//end

//// state transition
//always_ff @(st, start_in, shift_counter, clk_counter) begin
//    nst <= st;
//    case (st)
//        wait_s:     nst <= start_in ? shift_in_s : st;
//        shift_in_s: if (shift_counter == 4'hf && clk_counter == divisor - 1'b1) nst <= load_s;
//        load_s:     nst <= (~start_in) ? wait_s : st;
//        default:    nst <= wait_s;
//    endcase
//end
//endmodule:ad_module