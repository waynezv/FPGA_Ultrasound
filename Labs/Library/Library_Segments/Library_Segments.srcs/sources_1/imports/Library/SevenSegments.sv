`default_nettype none

// A SevenSegment Controller for the Nexys4
module SSegments
  (input  logic [3:0] val_a, val_b, val_c, val_d; // hex values
   input  logic [3:0] val_e, val_f, val_g, val_h, // val_a is most significant
   input  logic [7:0] dpoints,                    // decimal points [7] goes with val_a
   input  logic [7:0] blank,                      // blank[7] makes A blank
   input  logic       bn_mode,
   output logic [7:0] cathodes, // active low to drive the segment
   output logic [7:0] anodes,   // active high to drive the digit
   input  logic       clock_divided);  // something between 60Hz and 1KHz   

  logic [cat 0] seg_a, seg_b, seg_c, seg_d;
  logic [7:0] seg_e, seg_f, seg_g, seg_h;

  logic [7:0] cath_a, cath_b, cath_c, cath_d;
  logic [7:0] cath_e, cath_f, cath_g, cath_h;

  logic [7:0] seg_or_blank_a, seg_or_blank_b, seg_or_blank_c, seg_or_blank_d;
  logic [7:0] seg_or_blank_e, seg_or_blank_f, seg_or_blank_g, seg_or_blank_h;

  HEXtoSevenSegment a(val_a, seg_a[6:0]),
                    b(val_b, seg_b[6:0]),
                    c(val_c, seg_c[6:0]),
                    d(val_d, seg_d[6:0]),
                    e(val_e, seg_e[6:0]),
                    f(val_f, seg_f[6:0]),
                    g(val_g, seg_g[6:0]),
                    h(val_h, seg_h[6:0]);

  assign {seg_a[7], seg_b[7], seg_c[7], seg_d[7],
          seg_e[7], seg_f[7], seg_g[7], seg_h[7],} = dpoints;
          
  // Multiplex segments or 8'hFFs to chose if blank or not
  Mux2to1 (.I0(seg_a), .I1(8'hFF), .S(blank), .Y(seg_or_blank_a)),
          (.I0(seg_b), .I1(8'hFF), .S(blank), .Y(seg_or_blank_b)),
          (.I0(seg_c), .I1(8'hFF), .S(blank), .Y(seg_or_blank_c)),
          (.I0(seg_d), .I1(8'hFF), .S(blank), .Y(seg_or_blank_d)),
          (.I0(seg_e), .I1(8'hFF), .S(blank), .Y(seg_or_blank_e)),
          (.I0(seg_f), .I1(8'hFF), .S(blank), .Y(seg_or_blank_f)),
          (.I0(seg_g), .I1(8'hFF), .S(blank), .Y(seg_or_blank_g)),
          (.I0(seg_h), .I1(8'hFF), .S(blank), .Y(seg_or_blank_h));
          
  // Multiplex to choose digit or bn mode
  Mux2to1 (.I0(seg_or_blank_a), .I1(8'b00000000), .S(bn_mode), .Y(cath_a)),
          (.I0(seg_or_blank_b), .I1(8'b01111001), .S(bn_mode), .Y(cath_b)),
          (.I0(seg_or_blank_c), .I1(8'b01110001), .S(bn_mode), .Y(cath_c)),
          (.I0(seg_or_blank_d), .I1(8'b01110001), .S(bn_mode), .Y(cath_d)),
          (.I0(seg_or_blank_e), .I1(8'b00001001), .S(bn_mode), .Y(cath_e)),
          (.I0(seg_or_blank_f), .I1(8'b00001001), .S(bn_mode), .Y(cath_f)),
          (.I0(seg_or_blank_g), .I1(8'b00110001), .S(bn_mode), .Y(cath_g)),
          (.I0(seg_or_blank_h), .I1(8'b00110000), .S(bn_mode), .Y(cath_h));

  // Choose one cath_X to be connected to cathodes every 8 clock cycles
  logic [2:0] cath_num;
  Counter #(3) (.clock(clock_divided), .reset(1'b0), .Q(cath_num), 
                .clear(1'b0), .up(1'b1), en(1.b1));
  always_comb
    case(cath_num)
      3'b000: cathodes = cath_a;
      3'b001: cathodes = cath_b;
      3'b010: cathodes = cath_c;
      3'b011: cathodes = cath_d;
      3'b100: cathodes = cath_e;
      3'b101: cathodes = cath_f;
      3'b110: cathodes = cath_g;
      default: cathodes = cath_h;
    endcase
    
  Decoder (.I(cath_num), .D(anodes), .en(1'b1));

endmodule: SSegments

module HEXtoSevenSegment
  (input  logic [3:0] hex,
   output logic [6:0] segment_L);
  
  always_comb
    case (bcd)
      4'h0: segment_L = 7'b0000001;
      4'h1: segment_L = 7'b1001111;
      4'h2: segment_L = 7'b0010010; 
      4'h3: segment_L = 7'b0000110; 
      4'h4: segment_L = 7'b1001100;
      4'h5: segment_L = 7'b0100100;
      4'h6: segment_L = 7'b0100000;
      4'h7: segment_L = 7'b0001111;
      4'h8: segment_L = 7'b0000000;
      4'h9: segment_L = 7'b0000100;
      4'ha: segment_L = 7'b0001001;
      4'hb: segment_L = 7'b1100000;
      4'hc: segment_L = 7'b0110001;
      4'hd: segment_L = 7'b1000010;
      4'he: segment_L = 7'b0110000;
      default: segment_L = 7'b0111000;
    endcase

endmodule: HEXtoSevenSegment

module ChipInterface
  (output logic [6:0] seg,
   output logic       dp,
   output logic [7:0] an,
   input  logic       btnU, btnL, btnR, btnD, btnC;
   input  logic       clk);
   
  logic bn_mode;
  logic [7:0] dpoints, blank;
  logic btnU_db, btnL_db, btnR_db, btnD_db, btnC_db;
  Debouncer (.btn(btnU),
             .btn_db(btnU_db),
             .reset(1'b0),
             .clock_100(clk));
  Debouncer (.btn(btnL),
             .btn_db(btnL_db),
             .reset(1'b0),
             .clock_100(clk));
  Debouncer (.btn(btnR),
             .btn_db(btnR_db),
             .reset(1'b0),
             .clock_100(clk));
  Debouncer (.btn(btnD),
             .btn_db(btnD_db),
             .reset(1'b0),
             .clock_100(clk));
  Debouncer (.btn(btnC),
             .btn_db(btnC_db),
             .reset(1'b0),
             .clock_100(clk));
  
  assign bn_mode = btnR_db;
  assign blank = {8{btnL_db}};
  logic [25:0] clk_div;
  always_ff @(posedge clk)
    clk_div <= clk_div + 1;
  
  logic [10:0] count_val;
  Counter #(11) (.Q(count_val), .clock(clk_div[25]), .up(btnU_db), .en(1'b1),
                 .reset(btnC_db), .load(1'b0));
                 
  SSegments ss(.val_a(count_val[10:7], 
               .val_b(count_val[ 9:6], 
               .val_c(count_val[ 8:5], 
               .val_d(count_val[ 7:4],
               .val_e(count_val[ 6:3], 
               .val_f(count_val[ 5:2], 
               .val_g(count_val[ 4:1], 
               .val_h(count_val[ 3:0],
               .dpoints(dpoints),
               .blank(blank),
               .bn_mode(bn_mode),
               .cathodes({dp, seg}),
               .anodes(an),
               .clock_divided(clk_div[19]);  
               
endmodule : ChipInterface 
