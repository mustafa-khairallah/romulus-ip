export SRC_DIR="../src_rtl/protected"
export SRC_SBOX="../src_rtl/protected/dom1/skinny_sbox8_dom1_non_pipelined.v"
iverilog -o loadkey -I $SRC_DIR $SRC_SBOX $SRC_DIR/skinny_constants.v $SRC_DIR/skinny_rnd.v $SRC_DIR/share_router.v $SRC_DIR/padding_mux.v $SRC_DIR/romulus_datapath.v $SRC_DIR/romulus_multi_dim_api.v $SRC_DIR/LWC.v load_key.v
