module load_key (/*AUTOARG*/ ) ;
   `include "../src_rtl/romulus_config_pkg.v"

   wire [BUSW-1:0] do_data;
   wire            do_valid, pdi_ready, sdi_ready, do_last;

   reg [BUSW-1:0]  sdi_data, pdi_data;
   reg              sdi_valid, pdi_valid, do_ready;
   reg              rst, clk;

   reg [7:0]  pdi_fifo[39:0];
   reg [7:0]  sdi_fifo[39:0];
   reg [7:0]  pdo_fifo[39:0];
   reg        sdi_rst;
   reg        pdi_rst;

   integer    sdi_cnt;
   integer    pdi_cnt;

   integer    i, j;

   genvar     z;

   LWC uut (
            // Outputs
            do_data, pdi_ready, sdi_ready, do_valid, do_last,
            // Inputs
            pdi_data, sdi_data, pdi_valid, sdi_valid, do_ready, clk, rst
            ) ;

   generate
      for (z = 0; z < BUSW/8; z = z + 1) begin:bus_mapping
         always @ (*) begin
            sdi_data[BUSW-1-8*z:BUSW-8-8*z] <= sdi_fifo[z];
            pdi_data[BUSW-1-8*z:BUSW-8-8*z] <= pdi_fifo[z];
         end
      end
   endgenerate

   // SDI FIFO
   always @(posedge clk) begin
      if (sdi_rst) begin
         sdi_fifo[0] <= LDKEY;
         sdi_fifo[1] <= 8'h00;
         sdi_fifo[2] <= 8'h00;
         sdi_fifo[3] <= 8'h00;

         sdi_fifo[4][7:4] <= KEY;
         sdi_fifo[4][3:0] <= 2;
         sdi_fifo[5] <= 8'h00;
         sdi_fifo[6] <= 8'h00;
         sdi_fifo[7] <= 8'h10;

         for (i = 0; i < 32; i = i + 1) begin
            sdi_fifo[i+8] <= i;
         end
         sdi_valid <= 1;
         sdi_cnt <= 40;
      end
      else if (sdi_ready && sdi_valid) begin
         sdi_cnt <= sdi_cnt - BUSW/8;
         for (i = 0; i < 40-BUSW/8; i = i + 1) begin
            sdi_fifo[i] <= sdi_fifo[i+BUSW/8];
         end
         for (i = 40-BUSW/8; i < 40; i = i + 1) begin
            sdi_fifo[i] <= 0;
         end
         if (sdi_cnt == BUSW/8) begin
            sdi_valid <= 0;
         end
      end
   end // always @ (posedge clk)

   // PDI FIFO
   always @(posedge clk) begin
      if (pdi_rst) begin
         pdi_fifo[0] <= ACTKEY;
         pdi_fifo[1] <= 8'h00;
         pdi_fifo[2] <= 8'h00;
         pdi_fifo[3] <= 8'h00;

         pdi_valid <= 1;
         pdi_cnt <= 4;
      end
      else if (pdi_ready && pdi_valid) begin
         pdi_cnt <= pdi_cnt - BUSW/8;
         for (i = 0; i < 24-BUSW/8; i = i + 1) begin
            pdi_fifo[i] <= pdi_fifo[i+BUSW/8];
         end
         for (i = 24-BUSW/8; i < 24; i = i + 1) begin
            pdi_fifo[i] <= 0;
         end
         if (sdi_cnt == BUSW/8) begin
            pdi_valid <= 0;
         end
      end
   end

   // Clock
   initial begin
      clk = 0;
      forever begin
         #5 clk = ~clk;
      end
   end

   // FSM monitor

   always @ (posedge clk) begin
      $display("current state %h", uut.control_unit.fsm);
   end

   // Stimuli
   initial begin
      sdi_rst = 1;
      pdi_rst = 1;
      rst = ~neg_rst;

      #100;
      sdi_rst = 0;
      pdi_rst = 0;
      rst = neg_rst;

      for (i = 0; i < 24; i = i + 1) begin
         $display("%h",sdi_fifo[i]);
      end
      for (i = 0; i < 4; i = i + 1) begin
         $display("%h",pdi_fifo[i]);
      end
      #1000;

      $finish();
   end

endmodule // load_key
