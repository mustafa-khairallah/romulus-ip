module romulus_multi_dim_api (/*AUTOARG*/
                              // Outputs
                              pdo_data, pdi, pdi_ready, sdi_ready, pdo_valid, do_last, xrst, xenc, xen,
                              yrst, yenc, yen, zrst, zenc, zen, srst, senc, sen, constant,
                              // Inputs
                              pdi_data, pdo, sdi_data, pdi_valid, sdi_valid, pdo_ready, rst, clk
                              ) ;
`include "romulus_config_pkg.v"
`include "romulus_states.v"

   output reg [BUSW-1:0] pdo_data;
   output reg [BUSW-1:0] pdi;
   output reg            pdi_ready;
   output reg            sdi_ready;
   output reg            pdo_valid;
   output reg            do_last;

   output reg            xrst, xenc, xen;
   output reg            yrst, yenc, yen;
   output reg            zrst, zenc, zen;
   output reg            srst, senc, sen;

   output [CNTW*RNDS_PER_CLK-1:0] constant;

   input [BUSW-1:0]      pdi_data;
   input [BUSW-1:0]      pdo;
   input [BUSW-1:0]      sdi_data;
   input                 pdi_valid;
   input                 sdi_valid;
   input                 pdo_ready;

   input                 rst;
   input                 clk;

   reg [15:0]            fsm, fsmn;
   reg [CNTW-1:0]        cnt, cntn;

   wire [CNTW-1:0]       cntw;

   genvar                i;

   generate
      assign constant[CNTW-1:0] = cnt;
      if (TBC == DUMMY) begin:dummy_cnt
         assign cntw = cnt + 1;
      end
   endgenerate

   generate
      if (neg_rst) begin:negative_reset
         always @ (posedge clk) begin
            if (!rst) begin
               fsm <= idle;
               cnt <= BBUSC;
            end
            else begin
               fsm <= fsmn;
               cnt <= cntn;
            end
         end
      end
      else begin:positive_reset
         always @ (posedge clk) begin
            if (rst) begin
               fsm <= idle;
               cnt <= BBUSC;
            end
            else begin
               fsm <= fsmn;
               cnt <= cntn;
            end
         end
      end
   endgenerate

   always @ (*) begin
      fsmn <= fsm;
      cntn <= cnt;
      sdi_ready <= 0;
      pdi_ready <= 0;
      pdo_valid <= 0;
      do_last <= 0;
      xrst <= 0;
      xenc <= 0;
      xen <= 0;
      yrst <= 0;
      yenc <= 0;
      yen <= 0;
      zrst <= 0;
      zenc <= 0;
      zen <= 0;
      srst <= 0;
      senc <= 0;
      sen <= 0;
      case (fsm)
        idle: begin
           if (pdi_valid) begin
              if (pdi_data[BUSW-1:BUSW-8] == ACTKEY) begin
                 pdi_ready <= 1;
                 if (sdi_valid) begin
                    if (sdi_data[BUSW-1:BUSW-8] == LDKEY) begin
                       sdi_ready <= 1;
                       fsmn <= keyheader;
                    end // LDKEY
                 end // sdi_valid
                 else begin
                    fsmn <= idle;
                 end
              end // ACTKEY
           end // pdi_valid
        end // idle
        keyheader: begin
           if (sdi_valid) begin
              sdi_ready <= 1;
              if (sdi_data[BUSW-1:BUSW-4] == KEY) begin
                 fsmn <= storekey;
              end
           end
        end // keyheader
        storekey: begin
           if (sdi_valid) begin
              sdi_ready <= 1;
              xrst <= 1;
              if (cnt == SBUSC) begin
                 cntn <= BBUSC;
                 fsmn <= idle;
              end // SBUSC
              else begin
                 cntn <= cntw;
              end
           end // sdi_valid
        end // storekey
      endcase // case (fsm)
   end
endmodule // romulus_multi_dim_api
