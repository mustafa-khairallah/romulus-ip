module tweakablecipher (/*AUTOARG*/
   // Outputs
   nextcnt, nextkey, nexttweak, nextstate,
   // Inputs
   roundkey, roundtweak, roundstate, roundcnt, constant
   ) ;
   parameter numrnd = 2;
   parameter fullcnt = 1;

   output [63+64*fullcnt:0] nextcnt;
   output [127:0]           nextkey, nexttweak, nextstate;
   input [127:0]            roundkey, roundtweak, roundstate;
   input [63+64*fullcnt:0]  roundcnt;
   input [5+6*(numrnd-1):0] constant;

   roundfunction #(.fullcnt(fullcnt), .num_rnd(num_rnd)) skinny_rnd (.nextcnt(tkztbc),
                                                                     .nextkey(tkxtbc),
                                                                     .nexttweak(tkytbc),
                                                                     .nextstate(tbcstate),
                                                                     .roundkey(key),
                                                                     .roundtweak(tweak),
                                                                     .roundcnt(domainseparator),
                                                                     .roundstate(state),
                                                                     .constant(constant)
                                                                     );
endmodule // tweakablecipher
