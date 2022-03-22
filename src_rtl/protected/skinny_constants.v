module skinny_constants (/*AUTOARG*/
   // Outputs
   constant,
   // Inputs
   cnt
   ) ;
   parameter RNDS_PER_CLK = 40;

   output [6*RNDS_PER_CLK-1:0] constant;
   input [5:0]                 cnt;

   wire [5:0]                  constant_lut [39:0];
   genvar                      i;

   assign constant_lut[ 0] = 6'h01;
   assign constant_lut[ 1] = 6'h03;
   assign constant_lut[ 2] = 6'h07;
   assign constant_lut[ 3] = 6'h0F;
   assign constant_lut[ 4] = 6'h1F;
   assign constant_lut[ 5] = 6'h3E;
   assign constant_lut[ 6] = 6'h3D;
   assign constant_lut[ 7] = 6'h3B;
   assign constant_lut[ 8] = 6'h37;
   assign constant_lut[ 9] = 6'h2F;
   assign constant_lut[10] = 6'h1E;
   assign constant_lut[11] = 6'h3C;
   assign constant_lut[12] = 6'h39;
   assign constant_lut[13] = 6'h33;
   assign constant_lut[14] = 6'h27;
   assign constant_lut[15] = 6'h0E;
   assign constant_lut[16] = 6'h1D;
   assign constant_lut[17] = 6'h3A;
   assign constant_lut[18] = 6'h35;
   assign constant_lut[19] = 6'h2B;
   assign constant_lut[20] = 6'h16;
   assign constant_lut[21] = 6'h2C;
   assign constant_lut[22] = 6'h18;
   assign constant_lut[23] = 6'h30;
   assign constant_lut[24] = 6'h21;
   assign constant_lut[25] = 6'h02;
   assign constant_lut[26] = 6'h05;
   assign constant_lut[27] = 6'h0B;
   assign constant_lut[28] = 6'h17;
   assign constant_lut[29] = 6'h2E;
   assign constant_lut[30] = 6'h1C;
   assign constant_lut[31] = 6'h38;
   assign constant_lut[32] = 6'h31;
   assign constant_lut[33] = 6'h23;
   assign constant_lut[34] = 6'h06;
   assign constant_lut[35] = 6'h0D;
   assign constant_lut[36] = 6'h1B;
   assign constant_lut[37] = 6'h36;
   assign constant_lut[38] = 6'h2D;
   assign constant_lut[39] = 6'h1A;

   generate
      for (i = 0; i < RNDS_PER_CLK; i = i + 1) begin:skinny_constants_gen
         assign constant[5+6*i:6*i] = constant_lut[RNDS_PER_CLK*cnt+i];
      end
   endgenerate

endmodule // skinny_constants
