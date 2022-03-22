module padding_mux (/*AUTOARG*/
   // Outputs
   pdi_padded,
   // Inputs
   pdi_data, rdi, cnt, seglen, last, pad, share
   ) ;
`include "romulus_config_pkg.v"

   output [BUSW-1:0] pdi_padded;
   input  [BUSW-1:0] pdi_data;
   input  [BUSW-1:0] rdi;
   input  [CNTW-1:0] cnt;
   input  [3:0] seglen;
   input        last;
   input        pad;
   input        share;

   reg [BUSW-1:0] pdi_padded;

   reg [15:0]    seglen_pulse;
   reg [3:0]     pad_select;

   genvar          i;

   always @ (*) begin
      pad_select <= seglen_pulse[3:0];
      case (cnt)
        0: begin
           pad_select <= seglen_pulse[3:0];
        end
        1: begin
           pad_select <= seglen_pulse[7:4];
        end
        2: begin
           pad_select <= seglen_pulse[11:8];
        end
        3: begin
           pad_select <= seglen_pulse[15:12];
        end
      endcase // case (cnt)
      if (pad) begin
         case (seglen)
           0: begin
              seglen_pulse <= 16'h0000;
           end
           1: begin
              seglen_pulse <= 16'h0001;
           end
           2: begin
              seglen_pulse <= 16'h0003;
           end
           3: begin
              seglen_pulse <= 16'h0007;
           end
           4: begin
              seglen_pulse <= 16'h000f;
           end
           5: begin
              seglen_pulse <= 16'h001f;
           end
           6: begin
              seglen_pulse <= 16'h003f;
           end
           7: begin
              seglen_pulse <= 16'h007f;
           end
           8: begin
              seglen_pulse <= 16'h00ff;
           end
           9: begin
              seglen_pulse <= 16'h01ff;
           end
           10: begin
              seglen_pulse <= 16'h03ff;
           end
           11: begin
              seglen_pulse <= 16'h07ff;
           end
           12: begin
              seglen_pulse <= 16'h0fff;
           end
           13: begin
              seglen_pulse <= 16'h1fff;
           end
           14: begin
              seglen_pulse <= 16'h3fff;
           end
           15: begin
              seglen_pulse <= 16'h7fff;
           end
         endcase // case (seglen)
      end // if (pad)
      else begin
         seglen_pulse <= 16'hffff;
      end
   end

   generate
      for (i = 0; i < BUSW/8; i = i + 1) begin:byte_padding
         if (i == BUSW/8-1) begin:padding_final_gen
            always @(*) begin
               if (pad_select[i]) begin
                  pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= pdi_data[BUSW-1-8*i: BUSW-8-8*i];
               end
               else begin
                  if (last) begin
                     if (share) begin
                        pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= {4'h0,seglen}
                                                              ^ rdi[BUSW-1-8*i: BUSW-8-8*i];
                     end
                     else begin
                        pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= {4'h0,seglen};
                     end
                  end
                  else begin
                     if (share) begin
                        pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= rdi[BUSW-1-8*i: BUSW-8-8*i];
                     end
                     else begin
                        pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= 8'h00;
                     end
                  end
               end // else: !if((seglen[1:0] >= i) || (seglen > (cnt << BUSSHIFT)))
            end // always @ (*)
         end // if (i == BUSW/8-1)
         else begin:padding_normal_gen
            always @(*) begin
               if (pad_select[i])  begin
                  pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= pdi_data[BUSW-1-8*i: BUSW-8-8*i];
               end
               else begin
                  if (share) begin
                     pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= rdi[BUSW-1-8*i: BUSW-8-8*i];
                  end
                  else begin
                     pdi_padded[BUSW-1-8*i: BUSW-8-8*i] <= 8'h00;
                  end
               end
            end
         end // else: !if(i == BUSW/8-1)
      end // block: byte_padding
   endgenerate

endmodule // padding_mux
