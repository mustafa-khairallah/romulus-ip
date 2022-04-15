module skinny_rnd_nc (/*AUTOARG*/
   // Outputs
   nextcnt, nextkey, nexttweak, nextstate,
   // Inputs
   roundkey, roundtweak, roundstate, randomness, roundcnt, constant, ring_en,
   clk
   ) ;
`include"romulus_config_pkg.v"

   output [127:0] nextcnt;
   output [128*KEYSHARES-1:0] nextkey;
   output [127:0]             nexttweak;
   output [128*STATESHARES-1:0] nextstate;
   input [128*KEYSHARES-1:0]    roundkey;
   input [127:0]                roundtweak;
   input [128*STATESHARES-1:0]  roundstate;
   input [RNDW-1:0]             randomness;
   input [127:0]                roundcnt;
   input [5:0]                  constant;
   input [CLKS_PER_RND-1:0]     ring_en;
   input                        clk;

   genvar                       i, j;

   wire [127:0]                 rndcnt;
   wire [128*STATESHARES-1:0]   sb;
   wire [128*KEYSHARES-1:0]     rkey;
   wire [128*STATESHARES-1:0]   atk;
   wire [128*STATESHARES-1:0]   shr;
   wire [128*STATESHARES-1:0]   mxc;
   wire [128*KEYSHARES-1:0]     rndkey;
   wire [127:0]                 rndtweak;

   wire [5:0]                   rndconstant;

   generate
      for (j = 0; j < 16; j = j + 1) begin:sbox_loop
         if (MASKING==DOM1NC) begin:dom1nc
            skinny_sbox8_dom1_sni_non_complete sbox0 (.bo1(sb[8*j+ 7+128:8*j+128+0]),
                                                      .bo0(sb[8*j+ 7+  0:8*j+  0+0]),
                                                      .si1(roundstate[8*j+128+7:8*j+128+0]),
                                                      .si0(roundstate[8*j+  0+7:8*j+  0+0]),
                                                      .r(randomness[RNDW/16*j+7:RNDW/16*j]),
						                                          .cycle(ring_en[CLKS_PER_RND-3:0]),
                                                      .clk(clk));
         end
      end
   endgenerate


   wire [STATESHARES-1:0] sb_pg;
   wire [KEYSHARES-1:0] rkey_pg;

   assign sb_pg[255:128] = ring_en[CLKS_PER_RND-1] ? sb[255:128] : 128'h0;
   assign sb_pg[127:  0] = ring_en[CLKS_PER_RND-2] ? sb[127:  0] : 128'h0;

   assign rkey_pg[255:128] = ring_en[CLKS_PER_RND-1] ? rkey[255:128] : 128'h0;
   assign rkey_pg[127:  0] = ring_en[CLKS_PER_RND-2] ? rkey[127:  0] : 128'h0;

   // Add Tweakey
   assign atk = rkey ^ sb_pg;

   generate
      for (i = 0; i < STATESHARES; i = i + 1) begin:shiftrowsloop
         // ShiftRows
         assign shr[127+128*i:96+128*i] =  atk[127+128*i:96*i];
         assign shr[ 95+128*i:64+128*i] = {atk[ 71+128*i:64*i],atk[95+128*i:72+128*i]};
         assign shr[ 63+128*i:32+128*i] = {atk[ 47+128*i:32*i],atk[63+128*i:48+128*i]};
         assign shr[ 31+128*i: 0+128*i] = {atk[ 23+128*i: 0*i],atk[31+128*i:24+128*i]};

         // MixColumn
         assign mxc[ 95+128*i:64+128*i] = shr[127+128*i:96+128*i];
				 assign mxc[ 63+128*i:32+128*i] = shr[ 95+128*i:64+128*i] ^ shr[63+128*i:32+128*i];
				 assign mxc[ 31+128*i: 0+128*i] = shr[127+128*i:96+128*i] ^ shr[63+128*i:32+128*i];
				 assign mxc[127+128*i:96+128*i] = shr[ 31+128*i: 0+128*i] ^ mxc[31+128*i: 0+128*i];
      end // block: shiftrowsloop
   endgenerate

   assign nextstate = mxc;

   assign rndkey = roundkey;
   assign rndtweak = roundtweak;
   assign rndcnt = roundcnt;

   assign rndconstant = constant;

   wire [255:0] nextstate_pg;

   assign nextstate_pg[255:128] = ring_en[CLKS_PER_RND-1] ? nextstate[255:128] : 128'h0;
   assign nextstate_pg[127:  0] = ring_en[CLKS_PER_RND-2] ? nextstate[127:  0] : 128'h0;

   wire [255:0] nextkey_pg;

   assign nextkey_pg[255:128] = ring_en[CLKS_PER_RND-1] ? nextkey[255:128] : 128'h0;
   assign nextkey_pg[127:  0] = ring_en[CLKS_PER_RND-2] ? nextkey[127:  0] : 128'h0;

   wire [255:0] rndkey_pg;

   assign rndkey_pg[255:128] = ring_en[CLKS_PER_RND-1] ? rndkey[255:128] : 128'h0;
   assign rndkey_pg[127:  0] = ring_en[CLKS_PER_RND-2] ? rndkey[127:  0] : 128'h0;

   generate
      for (i = 0; i < KEYSHARES; i = i + 1) begin:keyexpansion
         key_expansion tk3 (.ko(nextkey[127+128*i:128*i]),.ki(rndkey_pg[127+128*i:128*i]));
      end
   endgenerate

   tweak2_expansion tk2 (.ko(nexttweak),.ki(rndtweak));

   tweak1_expansion #(.fullcnt(fullcnt)) tk1 (.ko(nextcnt),.ki(rndcnt));
   assign rkey[127:0] = {rndkey[127:64],64'h0} ^
                        {rndtweak[127:64],64'h0} ^
                        {rndcnt[127:64],64'h0}^
		                    {4'h0,rndconstant[3:0],24'h0,6'h0,rndconstant[5:4],24'h0,8'h02,56'h0};
   generate
      for(i = 1; i < KEYSHARES; i = i + 1) begin:round_keys_loop
         assign rkey[127+128*i:0+128*i] = {rndkey[127+128*i:64+128*i],64'h0};
      end
   endgenerate


endmodule // skinny_rnd

module key_expansion (/*AUTOARG*/
   // Outputs
   ko,
   // Inputs
   ki
   ) ;
   output [127:0] ko;
   input  [127:0] ki;

   wire [127:0]   kp;

   assign kp[127:120] = ki[ 55: 48];
   assign kp[119:112] = ki[  7:  0];
   assign kp[111:104] = ki[ 63: 56];
   assign kp[103: 96] = ki[ 23: 16];
   assign kp[ 95: 88] = ki[ 47: 40];
   assign kp[ 87: 80] = ki[ 15:  8];
   assign kp[ 79: 72] = ki[ 31: 24];
   assign kp[ 71: 64] = ki[ 39: 32];
   assign kp[ 63: 56] = ki[127:120];
   assign kp[ 55: 48] = ki[119:112];
   assign kp[ 47: 40] = ki[111:104];
   assign kp[ 39: 32] = ki[103: 96];
   assign kp[ 31: 24] = ki[ 95: 88];
   assign kp[ 23: 16] = ki[ 87: 80];
   assign kp[ 15:  8] = ki[ 79: 72];
   assign kp[  7:  0] = ki[ 71: 64];

   assign ko[127:120] = {kp[120]^kp[126],kp[127:121]};
   assign ko[119:112] = {kp[112]^kp[118],kp[119:113]};
   assign ko[111:104] = {kp[104]^kp[110],kp[111:105]};
   assign ko[103: 96] = {kp[ 96]^kp[102],kp[103: 97]};
   assign ko[ 95: 88] = {kp[ 88]^kp[ 94],kp[ 95: 89]};
   assign ko[ 87: 80] = {kp[ 80]^kp[ 86],kp[ 87: 81]};
   assign ko[ 79: 72] = {kp[ 72]^kp[ 78],kp[ 79: 73]};
   assign ko[ 71: 64] = {kp[ 64]^kp[ 70],kp[ 71: 65]};

   assign ko[ 63:  0] = kp[ 63:  0];

endmodule // key_expansion

module tweak2_expansion (/*AUTOARG*/
   // Outputs
   ko,
   // Inputs
   ki
   ) ;
   output [127:0] ko;
   input  [127:0] ki;

   wire [127:0]   kp;

   assign kp[127:120] = ki[ 55: 48];
   assign kp[119:112] = ki[  7:  0];
   assign kp[111:104] = ki[ 63: 56];
   assign kp[103: 96] = ki[ 23: 16];
   assign kp[ 95: 88] = ki[ 47: 40];
   assign kp[ 87: 80] = ki[ 15:  8];
   assign kp[ 79: 72] = ki[ 31: 24];
   assign kp[ 71: 64] = ki[ 39: 32];
   assign kp[ 63: 56] = ki[127:120];
   assign kp[ 55: 48] = ki[119:112];
   assign kp[ 47: 40] = ki[111:104];
   assign kp[ 39: 32] = ki[103: 96];
   assign kp[ 31: 24] = ki[ 95: 88];
   assign kp[ 23: 16] = ki[ 87: 80];
   assign kp[ 15:  8] = ki[ 79: 72];
   assign kp[  7:  0] = ki[ 71: 64];

   assign ko[127:120] = {kp[126:120],kp[127]^kp[125]};
   assign ko[119:112] = {kp[118:112],kp[119]^kp[117]};
   assign ko[111:104] = {kp[110:104],kp[111]^kp[109]};
   assign ko[103: 96] = {kp[102: 96],kp[103]^kp[101]};
   assign ko[ 95: 88] = {kp[ 94: 88],kp[ 95]^kp[ 93]};
   assign ko[ 87: 80] = {kp[ 86: 80],kp[ 87]^kp[ 85]};
   assign ko[ 79: 72] = {kp[ 78: 72],kp[ 79]^kp[ 77]};
   assign ko[ 71: 64] = {kp[ 70: 64],kp[ 71]^kp[ 69]};

   assign ko[ 63:  0] = kp[ 63:  0];

endmodule // tweak2_expansion

module tweak1_expansion (/*AUTOARG*/
   // Outputs
   ko,
   // Inputs
   ki
   ) ;
   parameter fullcnt = 0;

   output [63+64*fullcnt:0] ko;
   input [63+64*fullcnt:0]  ki;

   wire [63+64*fullcnt:0]   kp;

   generate
      if (fullcnt) begin:full_size_counter
         assign kp[127:120] = ki[ 55: 48];
         assign kp[119:112] = ki[  7:  0];
         assign kp[111:104] = ki[ 63: 56];
         assign kp[103: 96] = ki[ 23: 16];
         assign kp[ 95: 88] = ki[ 47: 40];
         assign kp[ 87: 80] = ki[ 15:  8];
         assign kp[ 79: 72] = ki[ 31: 24];
         assign kp[ 71: 64] = ki[ 39: 32];
         assign kp[ 63: 56] = ki[127:120];
         assign kp[ 55: 48] = ki[119:112];
         assign kp[ 47: 40] = ki[111:104];
         assign kp[ 39: 32] = ki[103: 96];
         assign kp[ 31: 24] = ki[ 95: 88];
         assign kp[ 23: 16] = ki[ 87: 80];
         assign kp[ 15:  8] = ki[ 79: 72];
         assign kp[  7:  0] = ki[ 71: 64];
      end // block: full_size_counter
      else begin:half_size_counter
         assign kp[63:56] = ki[ 55: 48];
         assign kp[55:48] = ki[  7:  0];
         assign kp[47:40] = ki[ 63: 56];
         assign kp[39:32] = ki[ 23: 16];
         assign kp[31:24] = ki[ 47: 40];
         assign kp[23:16] = ki[ 15:  8];
         assign kp[15: 8] = ki[ 31: 24];
         assign kp[ 7: 0] = ki[ 39: 32];
      end
   endgenerate

   assign ko = kp;

endmodule // tweak1_expansion


/*
 Designer: Mustafa Khairallah
 Nanyang Technological University
 Singapore
 Date: July, 2021
 */

/*
 This file is the basic implementation of the logic-based Skinny Sbox8.
 */

module skinny_sbox8_logic (
                     // Outputs
                     so,
                     // Inputs
                     si
                     ) ;
   output [7:0] so;
   input [7:0]  si;

   wire [7:0]   a;

   skinny_sbox8_cfn b764 (a[0],si[7],si[6],si[4]);
   skinny_sbox8_cfn b320 (a[1],si[3],si[2],si[0]);
   skinny_sbox8_cfn b216 (a[2],si[2],si[1],si[6]);
   skinny_sbox8_cfn b015 (a[3], a[0], a[1],si[5]);
   skinny_sbox8_cfn b131 (a[4], a[1],si[3],si[1]);
   skinny_sbox8_cfn b237 (a[5], a[2], a[3],si[7]);
   skinny_sbox8_cfn b303 (a[6], a[3], a[0],si[3]);
   skinny_sbox8_cfn b452 (a[7], a[4], a[5],si[2]);

   assign so[6] = a[0];
   assign so[5] = a[1];
   assign so[2] = a[2];
   assign so[7] = a[3];
   assign so[3] = a[4];
   assign so[1] = a[5];
   assign so[4] = a[6];
   assign so[0] = a[7];

endmodule // skinny_sbox8

// The core repeated function (x nor y) xor z
module skinny_sbox8_cfn (
                         // Outputs
                         f,
                         // Inputs
                         x, y, z
                         ) ;
   output f;
   input  x, y, z;

   assign f = ((~x) & (~y)) ^ z;

endmodule // skinny_sbox8_cfn


module skinny_correctfullperm (/*AUTOARG*/
   // Outputs
   tko,
   // Inputs
   tki
   ) ;
   output [127:0] tko;

   input  [127:0] tki;

   wire [127:0]   kp [8:0];

   genvar         i;

   assign kp[0] = tki;
   generate
      for (i = 1; i <= 8; i = i + 1) begin
         assign kp[i][127:120] = kp[i-1][ 55: 48];
         assign kp[i][119:112] = kp[i-1][  7:  0];
         assign kp[i][111:104] = kp[i-1][ 63: 56];
         assign kp[i][103: 96] = kp[i-1][ 23: 16];
         assign kp[i][ 95: 88] = kp[i-1][ 47: 40];
         assign kp[i][ 87: 80] = kp[i-1][ 15:  8];
         assign kp[i][ 79: 72] = kp[i-1][ 31: 24];
         assign kp[i][ 71: 64] = kp[i-1][ 39: 32];
         assign kp[i][ 63: 56] = kp[i-1][127:120];
         assign kp[i][ 55: 48] = kp[i-1][119:112];
         assign kp[i][ 47: 40] = kp[i-1][111:104];
         assign kp[i][ 39: 32] = kp[i-1][103: 96];
         assign kp[i][ 31: 24] = kp[i-1][ 95: 88];
         assign kp[i][ 23: 16] = kp[i-1][ 87: 80];
         assign kp[i][ 15:  8] = kp[i-1][ 79: 72];
         assign kp[i][  7:  0] = kp[i-1][ 71: 64];
      end // for (i = 0; i < 8; i = i + 1)
   endgenerate
   assign tko = kp[8];

endmodule // skinny_correctfullperm


module skinny_lfsr2_20 (/*AUTOARG*/
   // Outputs
   so,
   // Inputs
   si
   ) ;
   output [127:0] so;
   input [127:0]  si;

   wire [7:0]     m [15:0];
   wire [7:0]     z [15:0];

   assign m[0] = si[7:0];
   assign m[1] = si[15:8];
   assign m[2] = si[23:16];
   assign m[3] = si[31:24];
   assign m[4] = si[39:32];
   assign m[5] = si[47:40];
   assign m[6] = si[55:48];
   assign m[7] = si[63:56];
   assign m[8] = si[71:64];
   assign m[9] = si[79:72];
   assign m[10] = si[87:80];
   assign m[11] = si[95:88];
   assign m[12] = si[103:96];
   assign m[13] = si[111:104];
   assign m[14] = si[119:112];
   assign m[15] = si[127:120];

   assign z[0] = {m[0][3]^m[0][5]^m[0][7], m[0][2]^m[0][4]^m[0][6], m[0][1]^m[0][3]^m[0][5], m[0][0]^m[0][2]^m[0][4], m[0][1]^m[0][3]^m[0][5]^m[0][7], m[0][0]^m[0][2]^m[0][4]^m[0][6], m[0][1]^m[0][3]^m[0][7], m[0][0]^m[0][2]^m[0][6]};
   assign z[1] = {m[1][3]^m[1][5]^m[1][7], m[1][2]^m[1][4]^m[1][6], m[1][1]^m[1][3]^m[1][5], m[1][0]^m[1][2]^m[1][4], m[1][1]^m[1][3]^m[1][5]^m[1][7], m[1][0]^m[1][2]^m[1][4]^m[1][6], m[1][1]^m[1][3]^m[1][7], m[1][0]^m[1][2]^m[1][6]};
   assign z[2] = {m[2][3]^m[2][5]^m[2][7], m[2][2]^m[2][4]^m[2][6], m[2][1]^m[2][3]^m[2][5], m[2][0]^m[2][2]^m[2][4], m[2][1]^m[2][3]^m[2][5]^m[2][7], m[2][0]^m[2][2]^m[2][4]^m[2][6], m[2][1]^m[2][3]^m[2][7], m[2][0]^m[2][2]^m[2][6]};
   assign z[3] = {m[3][3]^m[3][5]^m[3][7], m[3][2]^m[3][4]^m[3][6], m[3][1]^m[3][3]^m[3][5], m[3][0]^m[3][2]^m[3][4], m[3][1]^m[3][3]^m[3][5]^m[3][7], m[3][0]^m[3][2]^m[3][4]^m[3][6], m[3][1]^m[3][3]^m[3][7], m[3][0]^m[3][2]^m[3][6]};
   assign z[4] = {m[4][3]^m[4][5]^m[4][7], m[4][2]^m[4][4]^m[4][6], m[4][1]^m[4][3]^m[4][5], m[4][0]^m[4][2]^m[4][4], m[4][1]^m[4][3]^m[4][5]^m[4][7], m[4][0]^m[4][2]^m[4][4]^m[4][6], m[4][1]^m[4][3]^m[4][7], m[4][0]^m[4][2]^m[4][6]};
   assign z[5] = {m[5][3]^m[5][5]^m[5][7], m[5][2]^m[5][4]^m[5][6], m[5][1]^m[5][3]^m[5][5], m[5][0]^m[5][2]^m[5][4], m[5][1]^m[5][3]^m[5][5]^m[5][7], m[5][0]^m[5][2]^m[5][4]^m[5][6], m[5][1]^m[5][3]^m[5][7], m[5][0]^m[5][2]^m[5][6]};
   assign z[6] = {m[6][3]^m[6][5]^m[6][7], m[6][2]^m[6][4]^m[6][6], m[6][1]^m[6][3]^m[6][5], m[6][0]^m[6][2]^m[6][4], m[6][1]^m[6][3]^m[6][5]^m[6][7], m[6][0]^m[6][2]^m[6][4]^m[6][6], m[6][1]^m[6][3]^m[6][7], m[6][0]^m[6][2]^m[6][6]};
   assign z[7] = {m[7][3]^m[7][5]^m[7][7], m[7][2]^m[7][4]^m[7][6], m[7][1]^m[7][3]^m[7][5], m[7][0]^m[7][2]^m[7][4], m[7][1]^m[7][3]^m[7][5]^m[7][7], m[7][0]^m[7][2]^m[7][4]^m[7][6], m[7][1]^m[7][3]^m[7][7], m[7][0]^m[7][2]^m[7][6]};
   assign z[8] = {m[8][3]^m[8][5]^m[8][7], m[8][2]^m[8][4]^m[8][6], m[8][1]^m[8][3]^m[8][5], m[8][0]^m[8][2]^m[8][4], m[8][1]^m[8][3]^m[8][5]^m[8][7], m[8][0]^m[8][2]^m[8][4]^m[8][6], m[8][1]^m[8][3]^m[8][7], m[8][0]^m[8][2]^m[8][6]};
   assign z[9] = {m[9][3]^m[9][5]^m[9][7], m[9][2]^m[9][4]^m[9][6], m[9][1]^m[9][3]^m[9][5], m[9][0]^m[9][2]^m[9][4], m[9][1]^m[9][3]^m[9][5]^m[9][7], m[9][0]^m[9][2]^m[9][4]^m[9][6], m[9][1]^m[9][3]^m[9][7], m[9][0]^m[9][2]^m[9][6]};
   assign z[10] = {m[10][3]^m[10][5]^m[10][7], m[10][2]^m[10][4]^m[10][6], m[10][1]^m[10][3]^m[10][5], m[10][0]^m[10][2]^m[10][4], m[10][1]^m[10][3]^m[10][5]^m[10][7], m[10][0]^m[10][2]^m[10][4]^m[10][6], m[10][1]^m[10][3]^m[10][7], m[10][0]^m[10][2]^m[10][6]};
   assign z[11] = {m[11][3]^m[11][5]^m[11][7], m[11][2]^m[11][4]^m[11][6], m[11][1]^m[11][3]^m[11][5], m[11][0]^m[11][2]^m[11][4], m[11][1]^m[11][3]^m[11][5]^m[11][7], m[11][0]^m[11][2]^m[11][4]^m[11][6], m[11][1]^m[11][3]^m[11][7], m[11][0]^m[11][2]^m[11][6]};
   assign z[12] = {m[12][3]^m[12][5]^m[12][7], m[12][2]^m[12][4]^m[12][6], m[12][1]^m[12][3]^m[12][5], m[12][0]^m[12][2]^m[12][4], m[12][1]^m[12][3]^m[12][5]^m[12][7], m[12][0]^m[12][2]^m[12][4]^m[12][6], m[12][1]^m[12][3]^m[12][7], m[12][0]^m[12][2]^m[12][6]};
   assign z[13] = {m[13][3]^m[13][5]^m[13][7], m[13][2]^m[13][4]^m[13][6], m[13][1]^m[13][3]^m[13][5], m[13][0]^m[13][2]^m[13][4], m[13][1]^m[13][3]^m[13][5]^m[13][7], m[13][0]^m[13][2]^m[13][4]^m[13][6], m[13][1]^m[13][3]^m[13][7], m[13][0]^m[13][2]^m[13][6]};
   assign z[14] = {m[14][3]^m[14][5]^m[14][7], m[14][2]^m[14][4]^m[14][6], m[14][1]^m[14][3]^m[14][5], m[14][0]^m[14][2]^m[14][4], m[14][1]^m[14][3]^m[14][5]^m[14][7], m[14][0]^m[14][2]^m[14][4]^m[14][6], m[14][1]^m[14][3]^m[14][7], m[14][0]^m[14][2]^m[14][6]};
   assign z[15] = {m[15][3]^m[15][5]^m[15][7], m[15][2]^m[15][4]^m[15][6], m[15][1]^m[15][3]^m[15][5], m[15][0]^m[15][2]^m[15][4], m[15][1]^m[15][3]^m[15][5]^m[15][7], m[15][0]^m[15][2]^m[15][4]^m[15][6], m[15][1]^m[15][3]^m[15][7], m[15][0]^m[15][2]^m[15][6]};

   assign so = {z[15],
		z[14],
		z[13],
		z[12],
		z[11],
		z[10],
		z[9],
		z[8],
		z[7],
		z[6],
		z[5],
		z[4],
		z[3],
		z[2],
		z[1],
		z[0]};

endmodule // skinny_lfsr2_20


module skinny_lfsr3_20 (/*AUTOARG*/
   // Outputs
   so,
   // Inputs
   si
   ) ;
   output [127:0] so;
   input [127:0]  si;

   wire [7:0] 	  m [15:0];
   wire [7:0] 	  z [15:0];

   assign m[0] = si[7:0];
   assign m[1] = si[15:8];
   assign m[2] = si[23:16];
   assign m[3] = si[31:24];
   assign m[4] = si[39:32];
   assign m[5] = si[47:40];
   assign m[6] = si[55:48];
   assign m[7] = si[63:56];
   assign m[8] = si[71:64];
   assign m[9] = si[79:72];
   assign m[10] = si[87:80];
   assign m[11] = si[95:88];
   assign m[12] = si[103:96];
   assign m[13] = si[111:104];
   assign m[14] = si[119:112];
   assign m[15] = si[127:120];

   assign z[0] =  {m[0][5] ^ m[0][3], m[0][4] ^ m[0][2], m[0][3] ^ m[0][1], m[0][2] ^ m[0][0], m[0][7] ^ m[0][5] ^ m[0][1], m[0][6] ^ m[0][4] ^ m[0][0], m[0][7] ^ m[0][3], m[0][6] ^ m[0][2]};
   assign z[1] =  {m[1][5] ^ m[1][3], m[1][4] ^ m[1][2], m[1][3] ^ m[1][1], m[1][2] ^ m[1][0], m[1][7] ^ m[1][5] ^ m[1][1], m[1][6] ^ m[1][4] ^ m[1][0], m[1][7] ^ m[1][3], m[1][6] ^ m[1][2]};
   assign z[2] =  {m[2][5] ^ m[2][3], m[2][4] ^ m[2][2], m[2][3] ^ m[2][1], m[2][2] ^ m[2][0], m[2][7] ^ m[2][5] ^ m[2][1], m[2][6] ^ m[2][4] ^ m[2][0], m[2][7] ^ m[2][3], m[2][6] ^ m[2][2]};
   assign z[3] =  {m[3][5] ^ m[3][3], m[3][4] ^ m[3][2], m[3][3] ^ m[3][1], m[3][2] ^ m[3][0], m[3][7] ^ m[3][5] ^ m[3][1], m[3][6] ^ m[3][4] ^ m[3][0], m[3][7] ^ m[3][3], m[3][6] ^ m[3][2]};
   assign z[4] =  {m[4][5] ^ m[4][3], m[4][4] ^ m[4][2], m[4][3] ^ m[4][1], m[4][2] ^ m[4][0], m[4][7] ^ m[4][5] ^ m[4][1], m[4][6] ^ m[4][4] ^ m[4][0], m[4][7] ^ m[4][3], m[4][6] ^ m[4][2]};
   assign z[5] =  {m[5][5] ^ m[5][3], m[5][4] ^ m[5][2], m[5][3] ^ m[5][1], m[5][2] ^ m[5][0], m[5][7] ^ m[5][5] ^ m[5][1], m[5][6] ^ m[5][4] ^ m[5][0], m[5][7] ^ m[5][3], m[5][6] ^ m[5][2]};
   assign z[6] =  {m[6][5] ^ m[6][3], m[6][4] ^ m[6][2], m[6][3] ^ m[6][1], m[6][2] ^ m[6][0], m[6][7] ^ m[6][5] ^ m[6][1], m[6][6] ^ m[6][4] ^ m[6][0], m[6][7] ^ m[6][3], m[6][6] ^ m[6][2]};
   assign z[7] =  {m[7][5] ^ m[7][3], m[7][4] ^ m[7][2], m[7][3] ^ m[7][1], m[7][2] ^ m[7][0], m[7][7] ^ m[7][5] ^ m[7][1], m[7][6] ^ m[7][4] ^ m[7][0], m[7][7] ^ m[7][3], m[7][6] ^ m[7][2]};
   assign z[8] =  {m[8][5] ^ m[8][3], m[8][4] ^ m[8][2], m[8][3] ^ m[8][1], m[8][2] ^ m[8][0], m[8][7] ^ m[8][5] ^ m[8][1], m[8][6] ^ m[8][4] ^ m[8][0], m[8][7] ^ m[8][3], m[8][6] ^ m[8][2]};
   assign z[9] =  {m[9][5] ^ m[9][3], m[9][4] ^ m[9][2], m[9][3] ^ m[9][1], m[9][2] ^ m[9][0], m[9][7] ^ m[9][5] ^ m[9][1], m[9][6] ^ m[9][4] ^ m[9][0], m[9][7] ^ m[9][3], m[9][6] ^ m[9][2]};
   assign z[10] =  {m[10][5] ^ m[10][3], m[10][4] ^ m[10][2], m[10][3] ^ m[10][1], m[10][2] ^ m[10][0], m[10][7] ^ m[10][5] ^ m[10][1], m[10][6] ^ m[10][4] ^ m[10][0], m[10][7] ^ m[10][3], m[10][6] ^ m[10][2]};
   assign z[11] =  {m[11][5] ^ m[11][3], m[11][4] ^ m[11][2], m[11][3] ^ m[11][1], m[11][2] ^ m[11][0], m[11][7] ^ m[11][5] ^ m[11][1], m[11][6] ^ m[11][4] ^ m[11][0], m[11][7] ^ m[11][3], m[11][6] ^ m[11][2]};
   assign z[12] =  {m[12][5] ^ m[12][3], m[12][4] ^ m[12][2], m[12][3] ^ m[12][1], m[12][2] ^ m[12][0], m[12][7] ^ m[12][5] ^ m[12][1], m[12][6] ^ m[12][4] ^ m[12][0], m[12][7] ^ m[12][3], m[12][6] ^ m[12][2]};
   assign z[13] =  {m[13][5] ^ m[13][3], m[13][4] ^ m[13][2], m[13][3] ^ m[13][1], m[13][2] ^ m[13][0], m[13][7] ^ m[13][5] ^ m[13][1], m[13][6] ^ m[13][4] ^ m[13][0], m[13][7] ^ m[13][3], m[13][6] ^ m[13][2]};
   assign z[14] =  {m[14][5] ^ m[14][3], m[14][4] ^ m[14][2], m[14][3] ^ m[14][1], m[14][2] ^ m[14][0], m[14][7] ^ m[14][5] ^ m[14][1], m[14][6] ^ m[14][4] ^ m[14][0], m[14][7] ^ m[14][3], m[14][6] ^ m[14][2]};
   assign z[15] =  {m[15][5] ^ m[15][3], m[15][4] ^ m[15][2], m[15][3] ^ m[15][1], m[15][2] ^ m[15][0], m[15][7] ^ m[15][5] ^ m[15][1], m[15][6] ^ m[15][4] ^ m[15][0], m[15][7] ^ m[15][3], m[15][6] ^ m[15][2]};

   assign so = {z[15],
		z[14],
		z[13],
		z[12],
		z[11],
		z[10],
		z[9],
		z[8],
		z[7],
		z[6],
		z[5],
		z[4],
		z[3],
		z[2],
		z[1],
		z[0]};

endmodule // skinny_lfsr3_20

