module share_router (/*AUTOARG*/
   // Outputs
   tbcstate, stateout, tbckey, keyout, keycorrect,
   // Inputs
   statein, nextstate, keyin, nextkey, pcorrectkey
   ) ;
`include"romulus_config_pkg.v"
   output [128*STATESHARES-1:0] tbcstate;
   output [128*STATESHARES-1:0] stateout;
   output [128*KEYSHARES-1:0]   tbckey;
   output [128*KEYSHARES-1:0]   keyout;
   output [128*KEYSHARES-1:0]   keycorrect;
   input [128*KEYSHARES-1:0]  statein;
   input [128*KEYSHARES-1:0]  nextstate;
   input [128*KEYSHARES-1:0]  keyin;
   input [128*KEYSHARES-1:0]  nextkey;
   input [128*KEYSHARES-1:0]  pcorrectkey;


   genvar                      i, j;

   generate
      for (i = 0; i < STATESHARES; i = i + 1) begin:state_share_loop
         for (j = 0; j < 128/BUSW; j = j + 1) begin:state_word_loop
            assign tbcstate[j*BUSW+BUSW-1+128*i:j*BUSW+128*i] = statein[BUSW*STATESHARES*j+BUSW*i+BUSW-1:BUSW*STATESHARES*j+BUSW*i];
            assign stateout[BUSW*STATESHARES*j+BUSW*i+BUSW-1:BUSW*STATESHARES*j+BUSW*i] = nextstate[j*BUSW+BUSW-1+128*i:j*BUSW+128*i];
         end
      end
   endgenerate

   generate
      for (i = 0; i < KEYSHARES; i = i + 1) begin:key_share_loop
         for (j = 0; j < 128/BUSW; j = j + 1) begin:key_word_loop
            assign tbckey[j*BUSW+BUSW-1+128*i:j*BUSW+128*i] = keyin[BUSW*KEYSHARES*j+BUSW*i+BUSW-1:BUSW*KEYSHARES*j+BUSW*i];
            assign keyout[BUSW*KEYSHARES*j+BUSW*i+BUSW-1:BUSW*KEYSHARES*j+BUSW*i] = nextkey[j*BUSW+BUSW-1+128*i:j*BUSW+128*i];
            assign keycorrect[BUSW*KEYSHARES*j+BUSW*i+BUSW-1:BUSW*KEYSHARES*j+BUSW*i] = pcorrectkey[j*BUSW+BUSW-1+128*i:j*BUSW+128*i];
         end
      end
   endgenerate

endmodule // share_router
