`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/04/06 22:38:02
// Design Name: 
// Module Name: pmodAD2
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


module pmodAD2(
                ad_rcv_intfc.ad t,
                input logic CLK,
                input logic RST,
                inout logic SDA,
                inout logic SCL,
                output logic [15:0] WDA
    );
    
// General control and timing signals
logic fMessage, fDoTransmit, fDoRead, fDone;

logic [7:0] currentAddr;
logic [6:0] addrAD2 = 7'b0101_000; // 0101_001
logic [7:0] writeCfg = 8'b1111_0000; // channel

int waitCount = 0;

enum {stDone, stWait, stGo, stConfig, stRead1, stRead2} st;

logic [7:0] curResponse;

I2CBusController i2cBusControl //#(100) 
    (.CLK(CLK), .SRST(RST), .SCL(SCL), .SDA(SDA), .MSG_I(fMessage), .STB_I(fDoTransmit),
     .A_I(currentAddr), .D_I(writeCfg), .D_0(curResponse),
     .DONE_0(fDone)
    );

assign currentAddr = {addrAD2, fDoRead};

always_ff @(st) begin
    case (st)
        stConfig: fDoRead <= 1'b0;
        stGo    : fDoRead <= 1'b0;
        default : fDoRead <= 1'b1;
    endcase    
end

always_ff @(posedge CLK, negedge RST) begin
    if (~RST) begin 
        st <= stWait;
        fMessage <= 1'b0;
        fDoTransmit <= 1'b0;
        waitCount <= 0;
    end
    else begin
        case (st)
            stWait: begin 
            //
                if (t.read_en) // || waitCount == 2000) 
                    st <= stGo;
            //
                else st <= stWait;
//                waitCount <= waitCount + 1;
            end
            stGo: begin
                st <= stConfig;
                fMessage <= 1'b0;
                fDoTransmit <= 1'b1;
                t.ad_out_rdy <= 1'b0;
            end
            stConfig: begin
                if (fDone == 1'b1) st <= stRead1;
                else               begin st <= stConfig; fMessage <= 1'b0; end
                fMessage <= 1'b0;
                fDoTransmit <= 1'b0;
                t.ad_out_rdy <= 1'b0;
            end
            stRead1: begin
                if (fDone == 1'b1) begin st <= stRead2; WDA[15:8] <= curResponse; end
                else               st <= stRead1;
                fMessage <= 1'b1;
                fDoTransmit <= 1'b1;
                t.ad_out_rdy <= 1'b0;
            end
            stRead2: begin
                if (fDone == 1'b1) begin st <= stDone; WDA[7:0] <= curResponse; end
                else               st <= stRead2;
                fMessage <= 1'b0;
                fDoTransmit <= 1'b1;
        //
                t.ad_out_rdy <= 1'b1;
            end
            stDone: begin
                st <= (t.read_en) ? stGo : stWait;
                t.ad_out_rdy <= 1'b0;            
            end
        //
            default: begin
                st <= stDone;
                fMessage <= 1'b0;
                fDoTransmit <= 1'b0;
            end
        endcase
    end
end
endmodule
