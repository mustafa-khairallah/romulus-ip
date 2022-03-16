module deoxys_constants (/*AUTOARG*/
   // Outputs
   constant,
   // Inputs
   cnt
   ) ;
   parameter RNDS_PER_CLK = 40;

   output [8*(RNDS_PER_CLK+1)-1:0] constant;
   input [5:0]                 cnt;

   wire [7:0]                  constant_lut [16:0];
   genvar                      i;

   assign constant_lut[ 0] = 6'h2f;
   assign constant_lut[ 1] = 6'h5e;
   assign constant_lut[ 2] = 6'hbc;
   assign constant_lut[ 3] = 6'h63;
   assign constant_lut[ 4] = 6'hc6;
   assign constant_lut[ 5] = 6'h97;
   assign constant_lut[ 6] = 6'h35;
   assign constant_lut[ 7] = 6'h6a;
   assign constant_lut[ 8] = 6'hd4;
   assign constant_lut[ 9] = 6'hb3;
   assign constant_lut[10] = 6'h7d;
   assign constant_lut[11] = 6'hfa;
   assign constant_lut[12] = 6'hef;
   assign constant_lut[13] = 6'hc5;
   assign constant_lut[14] = 6'h91;
   assign constant_lut[15] = 6'h39;
   assign constant_lut[16] = 6'h72;

   generate
      for (i = 0; i <= RNDS_PER_CLK; i = i + 1) begin
         assign constant[7+8*i:8*i] = constant_lut[RNDS_PER_CLK*cnt+i];
      end
   endgenerate

endmodule // deoxys_constants
