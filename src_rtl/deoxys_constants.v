module deoxys_constants (/*AUTOARG*/
   // Outputs
   constant,
   // Inputs
   cnt
   ) ;
   parameter RNDS_PER_CLK = 40;

   output [8*(RNDS_PER_CLK)-1:0] constant;
   input [5:0]                 cnt;

   wire [7:0]                  constant_lut [16:0];
   genvar                      i;

   assign constant_lut[ 0] = 8'h2f;
   assign constant_lut[ 1] = 8'h5e;
   assign constant_lut[ 2] = 8'hbc;
   assign constant_lut[ 3] = 8'h63;
   assign constant_lut[ 4] = 8'hc6;
   assign constant_lut[ 5] = 8'h97;
   assign constant_lut[ 6] = 8'h35;
   assign constant_lut[ 7] = 8'h6a;
   assign constant_lut[ 8] = 8'hd4;
   assign constant_lut[ 9] = 8'hb3;
   assign constant_lut[10] = 8'h7d;
   assign constant_lut[11] = 8'hfa;
   assign constant_lut[12] = 8'hef;
   assign constant_lut[13] = 8'hc5;
   assign constant_lut[14] = 8'h91;
   assign constant_lut[15] = 8'h39;
   assign constant_lut[16] = 8'h72;

   generate
      for (i = 0; i < RNDS_PER_CLK; i = i + 1) begin:constants_loop
         assign constant[7+8*i:8*i] = constant_lut[RNDS_PER_CLK*cnt+i];
      end
   endgenerate

endmodule // deoxys_constants
