/*
 Designer: Mustafa Khairallah
 Nanyang Technological University
 Singapore
 Date: July, 2021
 */

// The DOM-dep multiplier based sbox8 with registered
// shares. Takes 4 cycles. Non-pipelined, so the input
// must remain stable for 4 cycles, including the 
// refreshing mask r.
module skinny_sbox8_dom1_dep_non_pipelined (/*AUTOARG*/
   // Outputs
   bo1, bo0,
   // Inputs
   si1, si0, r, clk
   ) ;
   (*equivalent_register_removal = "no" *)output [7:0] bo1; // share 1
   (*equivalent_register_removal = "no" *)output [7:0] bo0; // share 0

   (*equivalent_register_removal = "no" *)input [7:0] 	si1; // share 1
   (*equivalent_register_removal = "no" *)input [7:0] 	si0; // share 0
   (*equivalent_register_removal = "no" *)input [15:0]  r;   // refreshing mask
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
   
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b764 (a0,bi7,bi6,bi4,r[ 1: 0],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b320 (a1,bi3,bi2,bi0,r[ 3: 2],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b216 (a2,bi2,bi1,bi6,r[ 5: 4],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b015 (a3,a0, a1, bi5,r[ 7: 6],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b131 (a4,a1, bi3,bi1,r[ 9: 8],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b237 (a5,a2, a3, bi7,r[11:10],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b303 (a6,a3, a0, bi3,r[13:12],clk);
   (*equivalent_register_removal = "no" *)dom1_dep_sbox8_cfn_fr b422 (a7,a4, a5, bi2,r[15:14],clk);

   assign {bo1[6],bo0[6]} = a0;
   assign {bo1[5],bo0[5]} = a1;
   assign {bo1[2],bo0[2]} = a2;
   assign {bo1[7],bo0[7]} = a3;
   assign {bo1[3],bo0[3]} = a4;
   assign {bo1[1],bo0[1]} = a5;
   assign {bo1[4],bo0[4]} = a6;
   assign {bo1[0],bo0[0]} = a7;
   
endmodule // skinny_sbox8_dom1_dep_non_pipelined

module dom1_dep_sbox8_cfn_fr (/*AUTOARG*/
   // Outputs
   f,
   // Inputs
   a, b, z, r, clk
   ) ;
   output [1:0]        f;
   input [1:0]         a, b, z;
   input [1:0] 	       r;
   input 	       clk;

  (*equivalent_register_removal = "no" *) wire [1:0] 	       x, y;	      
   (*equivalent_register_removal = "no" *)reg [1:0] 	       g, t;

   assign x = {a[1],~a[0]};
   assign y = {b[1],~b[0]};
   
   always @ (posedge clk) begin
      g[1] <= y[1] ^ r[0];
      g[0] <= y[0] ^ r[0];      
   end

   always @(posedge clk) begin
      t[1] <= (x[1]&r[0])^r[1]^z[1];
      t[0] <= (x[0]&r[0])^r[1]^z[0];
   end

   assign f[1] = x[1]&(y[1]^g[0])^t[1];
   assign f[0] = x[0]&(y[0]^g[1])^t[0];
   
endmodule // dom1_dep_sbox8_cfn_fr


