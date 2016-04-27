`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/04/07 00:15:47
// Design Name: 
// Module Name: I2CBusController
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


module I2CBusController
#(parameter CLOCKFREQ = 100)
(
                        input logic CLK,
                        input logic SRST, // active low
                        
                        inout logic SCL,
                        inout logic SDA,
                        
                        input logic MSG_I,
                        input logic STB_I,
                        input logic [7:0] A_I,
                        input logic [7:0] D_I,
                        
                        output logic [7:0] D_0,
                        output logic DONE_0,
                        output logic ERR_0
    );

enum {busUnknown, busBusy, busFree} busState;
enum {errArb, errNAck} errTyR, errTy;
enum {stIdle, stStart, stRead, stWrite, stStop,
	  stMAck, stSAck, stMNAckStart, stMNAckStop,
	  stStopError, stError} st, nst;

int FSCL = 100_000; // SCL clock frequency, Hz
int TIMEOUT = 10; // I2C timeout for slave wait period, ms
int TSCL_CYCLES = CLOCKFREQ * 1_000_000 / FSCL;
int TIMEOUT_CYCLES = CLOCKFREQ * TIMEOUT * 1_000;

logic dSda, ddSda, dScl, ddScl;
logic fStart, fStop;

int busFreeCnt = TSCL_CYCLES, sclCnt = TSCL_CYCLES;
int timeOutCnt = TIMEOUT_CYCLES;

logic slaveWait, arbLost;
logic [7:0] dataByte, loadByte, currAddr; // shift register and parallel load
logic rSda = 1'b1, rScl = 1'b1;
logic [1:0] subState = 2'b00;
logic latchData, latchAddr, iDone, iErr, iSda, iScl, shiftBit, dataBitOut, rwBit, addrNData;
logic [2:0] bitCount = 3'b111;
logic int_Rst = 1'b0;

//+--------------------------------------------------------------------------------------------+
//+                                    Bus State Detection                                     +
//+--------------------------------------------------------------------------------------------+
// Sync flip-flops
assign fStart = (dScl) && (~dSda) && (ddSda); // if SCL high while SDA falling, start condition
assign fStop =  (dScl) && (dSda)  && (~ddSda); // if SCL high while SDA rising, stop condition

always_ff @(posedge CLK) begin
    if (SDA == 1'b1) dSda <= 1'b1;
    else             dSda <= SDA;
	ddSda <= dSda;
	if (SCL == 1'b1) dScl <= 1'b1;
	else             dScl <= SCL;
end

// Bus state
always_ff @(posedge CLK) begin
        if (int_Rst == 1'b1)         busState <= busUnknown;
        else if (fStart == 1'b1)     busState <= busBusy;
	    else if (busFreeCnt == 0)    busState <= busFree;
end

// TBUF count
always_ff @(posedge CLK) begin
    if (dScl == 1'b0 || dSda == 1'b0 || int_Rst == 1'b1) busFreeCnt <= TSCL_CYCLES;
    else if (dScl == 1'b1 && dSda == 1'b1)               busFreeCnt <= busFreeCnt - 1;
end

//+--------------------------------------------------------------------------------------------+
//+                                      General Purpose                                       +
//+--------------------------------------------------------------------------------------------+
// Slave wait
assign slaveWait = (dScl == 1'b0 && rScl == 1'b1) ? 1'b1 : 1'b0;
// Arbitrary lost
assign arbLost   = (dScl == 1'b1 && dSda == 1'b0 && rScl == 1'b1) ? 1'b1 : 1'b0;

// Internal reset
always_ff @(posedge CLK) begin
    if (st == stIdle && SRST == 1'b0) int_Rst <= 1'b0;
    else if (SRST == 1'b1)            int_Rst <= 1'b1;
end

// SCL period counter
always_ff @(posedge CLK) begin
    if (sclCnt == 0 || st == stIdle) sclCnt <= TSCL_CYCLES / 4;
    else if (slaveWait == 1'b0)      sclCnt <= sclCnt - 1;
end

always_ff @(posedge CLK) begin
    if (timeOutCnt == 0 || slaveWait == 1'b0) timeOutCnt <= TIMEOUT_CYCLES;
    else if (slaveWait == 1'b1)               timeOutCnt <= timeOutCnt - 1;
end

//+--------------------------------------------------------------------------------------------+
//+                                      Data Byte Shift                                       +
//+--------------------------------------------------------------------------------------------+
// Data byte shift register
assign loadByte   = (latchAddr == 1'b1) ? A_I : D_I;
assign dataBitOut = dataByte[7];
assign D_O        = dataByte;

always_ff @(posedge CLK) begin
    if ((latchData == 1'b1 || latchAddr == 1'b1) && sclCnt == 0) begin
        dataByte <= loadByte;
        bitCount <= 3'b111;
        if (latchData == 1'b1) addrNData <= 1'b0;
        else                   addrNData <= 1'b1;
    end
	else if (shiftBit == 1'b1 && sclCnt == 0) begin
				dataByte <= dataByte[6:0] & dSda; // 6
				bitCount <= bitCount - 1;
    end
end

//+--------------------------------------------------------------------------------------------+
//+                                     Address Register                                       +
//+--------------------------------------------------------------------------------------------+
// Current address register
assign rwBit = currAddr[0];

always_ff @(posedge CLK) begin
    if (latchAddr == 1'b1) currAddr <= A_I;
end

//+--------------------------------------------------------------------------------------------+
//+                                      Substate Count                                        +
//+--------------------------------------------------------------------------------------------+
// Divides each state into 4, to respect the setup and hold times of the bus
// Substate counter
always_ff @(posedge CLK) begin
    if (st == stIdle)     subState <= 2'b00;
	else if (sclCnt == 0) subState <= subState + 1;
end

// Sync				
always_ff @(posedge CLK) begin
    st     <= nst;
    rSda   <= iSda;
    rScl   <= iScl;            
    DONE_0 <= iDone;
    ERR_0  <= iErr;
    errTyR <= errTy;
end

// State Output decode
//assign iSda = rSda;
//assign iScl = rScl;
//assign iDone = 1'b0;
//assign iErr = 1'b0;
//assign errTy = errTyR;
//assign shiftBit = 1'b0;
//assign latchAddr = 1'b0;
//assign latchData = 1'b0;

always_comb begin		
    if (st == stStart) begin
        unique case (subState)
            2'b00: iSda = 1'b1;
            2'b01: begin iSda = 1'b1; iScl = 1'b1; end
            2'b10: begin iSda = 1'b0; iScl = 1'b1; end
            2'b11: begin iSda = 1'b0; iScl = 1'b0; end               
        endcase
	end
		
	if (st == stStop || st == stStopError) begin
        unique case (subState)
            2'b00: iSda = 1'b0;
            2'b01: begin iSda = 1'b0; iScl = 1'b1; end
            2'b10: begin iSda = 1'b1; iScl = 1'b1; end           
        endcase
	end
		
	if (st == stRead || st == stSAck) begin
	   unique case (subState)
           2'b00: iSda = 1'b1;
           2'b01: iScl = 1'b1;
           2'b10: iScl = 1'b1;
           2'b11: iScl = 1'b0;                
       endcase
	end
		
	if (st == stWrite) begin
        unique case (subState)
            2'b00: iSda = dataBitOut;
            2'b01: iScl = 1'b1;
            2'b10: iScl = 1'b1;
            2'b11: iScl = 1'b0;                
        endcase
	end
		
	if (st == stMAck) begin
	   	unique case (subState)
            2'b00: iSda = 1'b0;
            2'b01: iScl = 1'b1;
            2'b10: iScl = 1'b1;
            2'b11: iScl = 1'b0;                
        endcase
	end
		
	if (st == stMNAckStop || st == stMNAckStart) begin
		unique case (subState)
			2'b00: iSda = 1'b1;
			2'b01: iScl = 1'b1;
			2'b10: iScl = 1'b1;
			2'b11: iScl = 1'b0;				
		endcase
	end
		
	if (st == stSAck && sclCnt == 0 && subState == 2'b01) begin
			if (dSda == 1'b1) begin
				iDone = 1'b1;
				iErr = 1'b1;
				errTy = errNAck;
			end
			else if (addrNData == 1'b0) iDone <= 1'b1;
	end
		
	if (st == stRead && subState == 2'b01 && sclCnt == 0 && bitCount == 3'b000)
			iDone = 1'b1;
		
	if (st == stWrite && arbLost == 1'b1) begin
			iDone = 1'b1;
			iErr = 1'b1; // lost the arbitration
			errTy = errArb;
	end
		
	if ((st == stWrite && sclCnt == 0 && subState == 2'b11) ||
			((st == stSAck || st == stRead) && subState == 2'b01)) 
			shiftBit = 1'b1;
		
	if (st == stStart) latchAddr = 1'b1;
		
	if (st == stSAck && subState == 2'b11) latchData = 1'b1;
	
end

// Next state update
always_comb begin
    case (st)
      stIdle : if (STB_I == 1'b1 && busState == busFree && SRST == 1'b0) nst = stStart;
      stStart: if (subState == 2'b11 && sclCnt == 0)                     nst = stWrite;
      
      stWrite: if (arbLost == 1'b1)                                             nst = stIdle;
               else if (subState == 2'b11 && sclCnt == 0 && bitCount == 3'b000) nst = stSAck;
      
      stSAck: if (subState == 2'b11 && sclCnt == 0) begin
              if (int_Rst == 1'b1 || dataByte[0] == 1'b1) nst = stStop;
              else begin
                  if (addrNData == 1'b1) begin
                      if (rwBit == 1'b1)
                          nst = stRead;
                      else
                          nst = stWrite;
                  end
                  else if (STB_I == 1'b1) begin
                      if (MSG_I == 1'b1 || currAddr != A_I)
                          nst = stStart;
                      else begin
                          if (rwBit == 1'b1)
                              nst = stRead;
                          else
                              nst = stWrite;
                      end
                  end
                  else nst = stStop;
              end
              end
          
    stStop: if (subState == 2'b10 && sclCnt == 0) nst = stIdle;
      
    stRead: if (subState == 2'b11 && sclCnt == 0 && bitCount == 3'b111) begin
              if (int_Rst == 1'b0 && STB_I == 1'b1) begin
                  if (MSG_I == 1'b1 || currAddr != A_I) nst = stMNAckStart;
                  else                                  nst = stMAck;
              end
              else nst = stMNAckStop;
            end
      
    stMAck: if (subState == 2'b11 && sclCnt == 0) nst = stRead;
      
    stMNAckStart: if (arbLost == 1'b1)                        nst = stIdle; 
                  else if (subState == 2'b11 && sclCnt == 0)  nst = stStart;
      
    stMNAckStop: if (arbLost == 1'b1)                       nst = stIdle; 
                 else if (subState == 2'b11 && sclCnt == 0) nst = stStop;
    default: nst = stIdle;
endcase
end

// Open-drain outputs for bi-directional SDA and SCL
assign SDA = (rSda == 1'b1) ? 1'bz : 1'b0;
assign SCL = (rScl == 1'b1) ? 1'bz : 1'b0;

endmodule
