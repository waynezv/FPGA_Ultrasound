`default_nettype none

module MagComp
  #(parameter   WIDTH = 8)
  (output logic             AltB, AeqB, AgtB,
   input  logic [WIDTH-1:0] A, B);

  assign AeqB = (A == B);
  assign AltB = (A <  B);
  assign AgtB = (A >  B);

endmodule: MagComp

module MagComp_test;

  logic AltB, AeqB, AgtB;
  logic [1:0] A, B;
  logic [3:0] vector;
  
  assign {A, B} = vector;
  
  MagComp #(2) dut(.*);
  
  initial begin
    $monitor("A:%b B:%b ->> AltB(%b) AeqB(%b) AgtB(%b)", A, B, AltB, AeqB, AgtB);
    for (vector = 4'b0; vector != 4'b1111; vector++) 
      #1;
    #1 
    $finish;
  end
endmodule : MagComp_test

module Adder
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] A, B,
   input  logic             Cin,
   output logic [WIDTH-1:0] S,
   output logic             Cout);
   
   assign {Cout, S} = A + B + Cin;
   
endmodule : Adder

module Adder_test;

  logic [3:0] A, B;
  logic       Cin;
  logic [3:0] S;
  logic       Cout;
  
  logic [8:0] vector;
  assign {Cin, A, B} = vector;
  
  Adder #(4) dut(.*);
  
  initial begin
    $monitor("Cin:%b A:%b B:%b ->> Cout:%b S:%b", Cin, A, B, Cout, S);
    for (vector = 9'b0; vector != 9'b1_1111_1111; vector++) 
      #1;
    #1;
    $finish;
  end  
  
endmodule : Adder_test

module Multiplexer
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0]         I,
   input  logic [$clog2(WIDTH)-1:0] S,
   output logic                     Y);
   
   assign Y = I[S];
   
endmodule : Multiplexer

module Multiplexer_test;

  logic [7:0] I;
  logic [2:0] S;
  logic       Y;
  
  Multiplexer dut(.*);
  
  initial begin
    $monitor("I(%b), Sel(%b) --> Y(%b)", I, S, Y);
    I = 8'b1011_0011;
    for (S=3'b000; S != 3'b111; S++)
      #1;
    #1;
    $finish;
  end
  
endmodule : Multiplexer_test

module Mux2to1
  #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] I0, I1,
   input  logic             S,
   output logic [WIDTH-1:0] Y);
   
  assign Y = (S) ? I1 : I0;
  
endmodule : Mux2to1

module Mux4to1
  #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] I0, I1, I2, I3,
   input  logic [1:0]       S,
   output logic [WIDTH-1:0] Y);
   
  logic [WIDTH-1:0] int1, int2;
  
  Mux2to1 (.I0(I0), .I1(I1), .S(S[0]), .Y(int1));
  Mux2to1 (.I0(I2), .I1(I3), .S(S[0]), .Y(int2));
  Mux2to1 (.I0(int1), .I1(int2), .S(S[1]), .Y(Y));
    
endmodule : Mux4to1

module Mux2to1_test;

  logic [1:0] I0, I1;
  logic       S;
  logic [1:0] Y;
  
  logic [4:0] vector;
  assign {S, I1, I0} = vector;
  
  Mux2to1 #(2) dut(.*);
  
  initial begin
    $monitor("Sel(%b) I1(%h) I0(%h) -> Y(%h)", S, I1, I0, Y);
    for(vector = 5'b0; vector != 5'b11111; vector++)
      #1;
    #1;
    $finish;
  end
  
endmodule : Mux2to1_test

module Decoder
  #(parameter WIDTH=8)
  (input  logic [$clog2(WIDTH)-1:0] I,
   input  logic                     en,
   output logic [WIDTH-1:0]         D);
   
  always_comb begin
    D = 0;
    if (en)
      D = 1'b1 << I;
  end
  
endmodule : Decoder

module Decoder_test;

  logic [2:0] I;
  logic       en;
  logic [7:0] D;
  
  logic [3:0] vector;
  assign {en, I} = vector;

  Decoder #(8) dut(.*);
  
  initial begin
    $monitor("I(%b) en(%b) -> D(%b)", I, en, D);
    for(vector = 4'd0; vector != 4'b1111; vector++)
      #1;
    #1;
    $finish;
  end
  
endmodule : Decoder_test

module Register
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, clock,
   output logic [WIDTH-1:0] Q);
   
  always_ff @(posedge clock)
    if (en)
      Q <= D;
    else if (clear)
      Q <= 0;
      
endmodule : Register

module Register_test;

  logic [7:0] D;
  logic       en, clear, clock;
  logic [7:0] Q;
  
  Register dut(.*);
  
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end
  
  initial begin
    $monitor("D(%b) clear(%b) en(%b) -> Q(%b)", D, clear, en, Q);
    D <= 8'b0111_0001; clear <= 0; en <= 1;
    #7;
    D <= 8'b1000_1110; en <= 0;
    #20;
    clear <= 1;
    #10;
    $finish;
  end
  
endmodule : Register_test

module Counter
  #(parameter W=8)
  (input  logic [W-1:0] D,
   input  logic         clock, reset, clear, up, en,
   output logic [W-1:0] Q);

  always_ff @(posedge clock, posedge reset)
    if (reset)
      Q <= 0;
    else if (clear & en)
      Q <= 0;
    else if (load)
      Q <= D;
    else if (en)
      Q <= (up) ? Q+1 : Q-1;
      
endmodule : Counter

module Counter_test();

  logic [7:0] D, Q;
  logic       clock, reset, clear, up, en;

  initial begin
    clock = 0;
    reset = 1;
    reset <= 0;
    forever #2 clock = ~clock;
  end

  Counter #(8) dut (.*);
  
  initial begin
    $monitor("D(%b) clear(%b) load(%b) en(%b) up(%b) -> Q(%b)", 
      D, clear, load, en, up, Q);
    D <= 8'b0111_0001; clear <= 0; load <= 1; up <= 1; en <= 1;
    @(posedge clock);
    load <= 0;
    #17;
    up <= 0;
    #22;
    @(posedge clock);
    clear <= 1;
    @(posedge clock);
    clear <= 0;
    #30;
    $finish;
  end
    
endmodule : Counter_test

module ShiftRegister
  #(parameter W=8)
  (input  logic         s_in, en, clock, left,
   output logic [W-1:0] Q);

  always_ff @(posedge clock)
    if (en)
      Q <= (left) ? {Q[W-2:0], s_in} : {s_in, Q[W-1:1]};
    
endmodule : ShiftRegister

module ShiftRegister_test();

  logic       s_in, en, clock, left;
  logic [7:0] Q;


  ShiftRegister #(8) dut (.*);
  
  initial begin
    clock = 0;
    forever #2 clock = ~clock;
  end

  initial begin
    $monitor($time,,"en(%b) left(%b) s_in(%b) -> Q(%b)",
      en, left, s_in, Q);
    en = 0; left = 0; s_in = 0; 
    #9;
    en = 1;
    #16;
    left = 0;
    s_in = 1;
    #16;
    $finish;
  end  

endmodule : ShiftRegister_test

module DFF
  (input  logic D, clock, reset,
   output logic Q);

  always_ff @(posedge clock, posedge reset)
    if (reset)
      Q <= 1'b0;
    else
      Q <= D;
      
endmodule : DFF

module Debouncer
  (input  logic btn, clock_100, reset,
   output logic btn_db);
   
  logic ff1, ff2, ffs_not_equal;
  
  DFF dff1(.D(btn), 
           .Q(ff1),
           .reset(reset), 
           .clock(clock_100)); 
  DFF dff2(.D(ff1), 
           .Q(ff2),
           .reset(reset), 
           .clock(clock_100));
  DFF dff3(.D(ff2), 
           .Q(btn_db),
           .reset(reset), 
           .clock(clock_100));
  
  xor x(ffs_not_equal, ff1, ff2);
  
  logic [18:0] clk_val;  // 19 bit counter has debounce period of 10.49mS
  
  // Need a saturating counter.  Will count until MSB is set, then keep value
  always_ff @(posedge clock_100, posedge reset)
    if (reset)
      clk_val <= 19'0;
    else if (ffs_not_equal) // clear
      clk_val <= 19'0;
    else if (~clk_val[18])
      clk_val <= clk_val + 1;
      
                 
endmodule : Debouncer