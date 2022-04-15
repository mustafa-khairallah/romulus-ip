/*
 Designer: Mustafa Khairallah
 Nanyang Technological University
 Singapore
 Date: July, 2021
 */

// The DOM-Indep multiplier based sbox8 with registered
// shares. Takes 4 cycles. Non-pipelined, so the input
// must remain stable for 4 cycles, including the
// refreshing mask r.
module skinny_sbox8_dom1_sni_non_complete (/*AUTOARG*/
   // Outputs
   bo1, bo0,
   // Inputs
   si1, si0, r, cycle, clk
   ) ;
   output [7:0] bo1; // share 1
   output [7:0] bo0; // share 0

   input [7:0] 	si1; // share 1
   input [7:0] 	si0; // share 0
   input [7:0]  r;   // refreshing mask
   input [23:0] cycle;
   input        clk;

   wire [1:0]   bi7;
   wire [1:0]   bi6;
   wire [1:0]   bi5;
   wire [1:0]   bi4;
   wire [1:0]   bi3;
   wire [1:0]   bi2;
   wire [1:0]   bi1;
   wire [1:0]   bi0;

   wire [1:0]   a7;
   wire [1:0]   a6;
   wire [1:0]   a5;
   wire [1:0]   a4;
   wire [1:0]   a3;
   wire [1:0]   a2;
   wire [1:0]   a1;
   wire [1:0]   a0;

   assign bi0 = {si1[0],si0[0]};
   assign bi1 = {si1[1],si0[1]};
   assign bi2 = {si1[2],si0[2]};
   assign bi3 = {si1[3],si0[3]};
   assign bi4 = {si1[4],si0[4]};
   assign bi5 = {si1[5],si0[5]};
   assign bi6 = {si1[6],si0[6]};
   assign bi7 = {si1[7],si0[7]};

   dom1_sni_sbox8_cfn_nc b764 (a0,bi7,bi6,bi4,cycle[ 5: 0],r[0],clk);
   dom1_sni_sbox8_cfn_nc b320 (a1,bi3,bi2,bi0,cycle[ 5: 0],r[1],clk);
   dom1_sni_sbox8_cfn_nc b216 (a2,bi2,bi1,bi6,cycle[ 5: 0],r[2],clk);
   dom1_sni_sbox8_cfn_nc b015 (a3,a0, a1, bi5,cycle[11: 6],r[3],clk);
   dom1_sni_sbox8_cfn_nc b131 (a4,a1, bi3,bi1,cycle[11: 6],r[4],clk);
   dom1_sni_sbox8_cfn_nc b237 (a5,a2, a3, bi7,cycle[17:12],r[5],clk);
   dom1_sni_sbox8_cfn_nc b303 (a6,a3, a0, bi3,cycle[17:12],r[6],clk);
   dom1_sni_sbox8_cfn_nc b422 (a7,a4, a5, bi2,cycle[23:18],r[7],clk);

   assign {bo1[6],bo0[6]} = a0;
   assign {bo1[5],bo0[5]} = a1;
   assign {bo1[2],bo0[2]} = a2;
   assign {bo1[7],bo0[7]} = a3;
   assign {bo1[3],bo0[3]} = a4;
   assign {bo1[1],bo0[1]} = a5;
   assign {bo1[4],bo0[4]} = a6;
   assign {bo1[0],bo0[0]} = a7;

endmodule // skinny_sbox8_dom1_non_pipelined

// The core registered function of the skinny sbox8.
// nc: hardware non-completeness.
// cfn: core function
// The core function is basically (x nor y) xor z
// We use de morgan's law to convert it to:
// ((~x) and (~y)) xor z and use the DOM-Indep
// multiplier for the and gate. We add the shares of
// z to the independent and gates and register the
// output of (a and b) xor c, while for the mixed
// shares we also use (a and b) xor c, but c is the
// fresh randomness.
module dom1_sni_sbox8_cfn_nc (/*AUTOARG*/
   // Outputs
   f,
   // Inputs
   x, y, z, cycle, r, clk
   ) ;
   output reg [1:0]        f;
   input [1:0]         x, y, z;
   input [5:0]         cycle;
   input               r, clk;

   wire                s0, s1, s2, s3;
   wire                a0, a1, b0, b1, c0, c1, ri;

   wire                cs0, cs1; // compressed shares: input to the final regs
   wire                cw0, cw1; // compressed shares: comb logic

   reg [1:0]           g, t; // Sub-shares registers

   assign a0 = (cycle[1] || cycle[3]) ? x[0] : 0;
   assign a1 = (cycle[0] || cycle[2]) ? ~x[1] : 0;
   assign b0 = (cycle[1] || cycle[2]) ? y[0] : 0;
   assign b1 = (cycle[0] || cycle[3]) ? ~y[1] : 0;
   assign c0 = cycle [1] ? z[0] : 0;
   assign c1 = cycle [0] ? z[1] : 0;
   assign ri = (cycle[2] || cycle[3]) ? r : 0;

   assign s0 = (cycle[0]) ? (a1 & b1) ^ c1 : 0;
   assign s1 = (cycle[1]) ? (a0 & b0) ^ c0 : 0;
   assign s2 = (cycle[2]) ? (a1 & b0) ^ ri : 0;
   assign s3 = (cycle[3]) ? (a0 & b1) ^ ri : 0;

   assign cw0 = (cycle[4]) ? t[0] ^ g[0] : 0;
   assign cw1 = (cycle[5]) ? t[1] ^ g[1] : 0;

   assign cs0 = (cycle[4]) ? cw0 : 0;
   assign cs1 = (cycle[5]) ? cw1 : 0;



   always @ (posedge clk) begin
      if (cycle[0]) g[1] <= s0;
      if (cycle[1]) g[0] <= s1;

      if (cycle[2]) t[1] <= s2;
      if (cycle[3]) t[0] <= s3;

      if (cycle[4]) f[0] <= cs0;
      if (cycle[5]) f[1] <= cs1;
   end

endmodule // dom1_sbox8_cfn_nc
