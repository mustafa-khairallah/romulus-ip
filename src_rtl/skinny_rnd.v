module skinny_rnd (/*AUTOARG*/
   // Outputs
   nextcnt, nextkey, nexttweak, nextstate,
   // Inputs
   roundkey, roundtweak, roundstate, roundcnt, constant
   ) ;
   parameter numrnd = 40;
   parameter fullcnt = 1;

   output [63+64*fullcnt:0] nextcnt;
   output [127:0]           nextkey, nexttweak, nextstate;
   input [127:0]            roundkey, roundtweak, roundstate;
   input [63+64*fullcnt:0]  roundcnt;
   input [5+6*(numrnd-1):0] constant;

   genvar    i, j;

   wire [63+64*fullcnt:0] rndcnt [numrnd:0];
   wire [127:0] sb [0:numrnd-1];
   wire [127:0] rkey [0:numrnd-1];
   wire [127:0] atk [0:numrnd-1];
   wire [127:0] shr [0:numrnd-1];
   wire [127:0] mxc [0:numrnd-1];
   wire [127:0] rndkey [0:numrnd];
   wire [127:0] rndtweak [0:numrnd];

   wire [5:0]   rndconstant [numrnd-1:0];

   generate
      for (j = 0; j < 16; j = j + 1) begin:sbox_round0
         skinny_sbox8_logic sbox0 (.so(sb[0][8*j+7:8*j]),
                             .si(roundstate[8*j+7:8*j]));
      end
   endgenerate

   // Add Tweakey
   assign atk[0] = rkey[0] ^ sb[0];

   // ShiftRows
   assign shr[0][127:96] =  atk[0][127:96];
   assign shr[0][ 95:64] = {atk[0][ 71:64],atk[0][95:72]};
   assign shr[0][ 63:32] = {atk[0][ 47:32],atk[0][63:48]};
   assign shr[0][ 31: 0] = {atk[0][ 23: 0],atk[0][31:24]};

   // MixColumn
   assign mxc[0][ 95:64] = shr[0][127:96];
   assign mxc[0][ 63:32] = shr[0][ 95:64] ^ shr[0][63:32];
   assign mxc[0][ 31: 0] = shr[0][127:96] ^ shr[0][63:32];
   assign mxc[0][127:96] = shr[0][ 31: 0] ^ mxc[0][31: 0];

   generate
      for (i = 1; i < numrnd; i = i + 1) begin:unrolled_rounds
         for (j = 0; j < 16; j = j + 1) begin:sbox_layer
            skinny_sbox8_logic sboxi (.so(sb[i][8*j+7:8*j]),
                                .si(mxc[i-1][8*j+7:8*j]));
         end

         // Add Tweakey
         assign atk[i] = rkey[i] ^ sb[i];

         // ShiftRows
         assign shr[i][127:96] =  atk[i][127:96];
         assign shr[i][ 95:64] = {atk[i][ 71:64],atk[i][95:72]};
         assign shr[i][ 63:32] = {atk[i][ 47:32],atk[i][63:48]};
         assign shr[i][ 31: 0] = {atk[i][ 23: 0],atk[i][31:24]};

         // MixColumn
         assign mxc[i][ 95:64] = shr[i][127:96];
         assign mxc[i][ 63:32] = shr[i][ 95:64] ^ shr[i][63:32];
         assign mxc[i][ 31: 0] = shr[i][127:96] ^ shr[i][63:32];
         assign mxc[i][127:96] = shr[i][ 31: 0] ^ mxc[i][31: 0];
      end
   endgenerate

   assign nextstate = mxc[numrnd-1];

   assign rndkey[0] = roundkey;
   assign rndtweak[0] = roundtweak;
   assign rndcnt[0] = roundcnt;

   generate
      for (i = 0; i < numrnd; i = i + 1) begin:round_constant
         assign rndconstant[i] = constant[5+6*i:0+6*i];
      end
   endgenerate

   generate
      for (i = 0; i < numrnd; i = i + 1) begin:keyexpansion
         key_expansion tk3 (.ko(rndkey[i+1]),.ki(rndkey[i]));
         tweak2_expansion tk2 (.ko(rndtweak[i+1]),.ki(rndtweak[i]));

         if (fullcnt) begin: round_keys
            tweak1_expansion #(.fullcnt(fullcnt)) tk1 (.ko(rndcnt[i+1]),.ki(rndcnt[i]));
            assign rkey[i] = {rndkey[i][127:64],64'h0} ^
                             {rndtweak[i][127:64],64'h0} ^
                             {rndcnt[i][127:64],64'h0}^
		                         {4'h0,rndconstant[i][3:0],24'h0,6'h0,rndconstant[i][5:4],24'h0,8'h02,56'h0};
         end
         else if (i%2 == 0) begin: even_round_keys
            tweak1_expansion #(.fullcnt(fullcnt)) tk1 (.ko(rndcnt[i+2]),.ki(rndcnt[i]));
            assign rkey[i] = {rndkey[i][127:64],64'h0} ^
                             {rndtweak[i][127:64],64'h0} ^
                             {rndcnt[i][127:64],64'h0}^
		                         {4'h0,rndconstant[i][3:0],24'h0,6'h0,rndconstant[i][5:4],24'h0,8'h02,56'h0};
         end
         else begin: odd_round_keys
            assign rndcnt[i] = 64'h0;
            assign rkey[i] = {rndkey[i][127:64],64'h0} ^
                             {rndtweak[i][127:64],64'h0} ^
		                         {4'h0,rndconstant[i][3:0],24'h0,6'h0,rndconstant[i][5:4],24'h0,8'h02,56'h0};
         end
      end
   endgenerate

   assign nextkey = rndkey[numrnd];
   assign nexttweak = rndtweak[numrnd];
   assign nextcnt = rndcnt[numrnd];

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
