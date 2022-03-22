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
module skinny_sbox8_dom1_non_pipelined (/*AUTOARG*/
   // Outputs
   bo1, bo0,
   // Inputs
   si1, si0, r, clk
   ) ;
   (*equivalent_register_removal = "no" *)output [7:0] bo1; // share 1
   (*equivalent_register_removal = "no" *)output [7:0] bo0; // share 0

   (*equivalent_register_removal = "no" *)input [7:0] 	si1; // share 1
   (*equivalent_register_removal = "no" *)input [7:0] 	si0; // share 0
   (*equivalent_register_removal = "no" *)input [7:0]  r;   // refreshing mask
   (*equivalent_register_removal = "no" *)input        clk;

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
   
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b764 (a0,bi7,bi6,bi4,r[0],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b320 (a1,bi3,bi2,bi0,r[1],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b216 (a2,bi2,bi1,bi6,r[2],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b015 (a3,a0, a1, bi5,r[3],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b131 (a4,a1, bi3,bi1,r[4],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b237 (a5,a2, a3, bi7,r[5],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b303 (a6,a3, a0, bi3,r[6],clk);
   (*equivalent_register_removal = "no" *)dom1_sbox8_cfn_fr b422 (a7,a4, a5, bi2,r[7],clk);

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
// fr: fully registered, all and operations are
// registered.
// cfn: core function
// The core function is basically (x nor y) xor z
// We use de morgan's law to convert it to:
// ((~x) and (~y)) xor z and use the DOM-Indep
// multiplier for the and gate. We add the shares of
// z to the independent and gates and register the
// output of (a and b) xor c, while for the mixed
// shares we also use (a and b) xor c, but c is the
// fresh randomness.
module dom1_sbox8_cfn_fr (/*AUTOARG*/
   // Outputs
   f,
   // Inputs
   x, y, z, r, clk
   ) ;
   output [1:0]        f;
   input [1:0]         x, y, z;   
   input               r, clk;

   (*equivalent_register_removal = "no" *)reg [1:0]    g, t;
   always @ (posedge clk) begin
      g[1] <= (~x[1]) & (~y[1]) ^ z[1];
      g[0] <=   x[0]  &   y[0]  ^ z[0];
      
      t[1] <= ((~x[1]) &  y[0] ) ^ r;
      t[0] <= ((~y[1]) &  x[0] ) ^ r;
   end   

   assign f[0] = t[0] ^ g[0];
   assign f[1] = t[1] ^ g[1];
   
endmodule // dom1_sbox8_cfn_fr

