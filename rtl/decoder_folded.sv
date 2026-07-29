// -------------------------------------------------------------------------
// decoder_folded.sv -- folded (2,1,4) Viterbi decoder
//
// Same code, same trellis and same decoded output as rtl/decoder_term.sv.
// A different architecture.
//
// Rate 1/2, constraint length K = 4, 8 trellis states.
//   g1 = 1111 (17 octal) -> out[1]
//   g0 = 1011 (13 octal) -> out[0]
//
// Why this file exists
// --------------------
// rtl/decoder.sv and rtl/decoder_term.sv were written by porting the C++
// model structure-for-structure.  That model kept one HammingTable object per
// trellis stage and walked the eight states of each with a switch over cases
// a..h, and the port turned those into:
//
//   the per-stage objects  ->  h1..h10, ten register banks  (~350 LUT4/stage)
//   the per-stage call     ->  the steps_n sequencer
//   the switch over a..h   ->  the stage_n sequencer        (~8 clocks/stage)
//
// The object graph became silicon and the control flow became clock cycles, so
// the trellis ends up unrolled in space *and* serialised in time: more area
// than a folded decoder and less throughput than a pipelined one.  Measured,
// that costs the unrolled decoder the whole device at about 17 message bits;
// this file costs ~15 LUT4 per stage and reaches 100 in a third of an iCE40
// UP5K.  See docs/architecture.md and docs/img/area_blocklen.png.
//
// In hardware a software loop over an array decomposes into time (the loop)
// and space (the array), and the designer picks the trade.  This file picks:
//
//   the loop  ->  reuse over time.  One set of 8 add-compare-select units,
//                 all 8 evaluated in parallel, one trellis stage retired per
//                 clock.  STAGES clocks instead of ~8*STAGES.
//   the array ->  memory.  One byte of survivor decisions per stage, and 8
//                 path-metric registers that are reused, not replicated.
//
// The path metrics are renormalised by subtracting the stage minimum, which
// is what keeps them 4 bits wide no matter how long the block is.  Measured
// over model/viterbi_ref.py at 200 stages and channel error rates from 0.05
// to 0.5, the spread across the 8 states never exceeds 5, so a normalised
// metric never exceeds 5 and a candidate never exceeds 5 + 2 = 7.  METRIC_INF
// is 15, outside that range, and the assertion below enforces the bound.
//
// Everything except the survivor memory and the parallel `dat` input register
// is therefore constant in MSG_BITS -- and both of those are memory rather
// than logic.  The parallel-load interface is kept deliberately: it is the
// same (clk, reset, dat, out, ready) contract rtl/decoder_term.sv presents, so
// tb/system_folded_tb.sv is tb/system_term_tb.sv with the clock counts changed
// and the comparison is like for like.  A streaming sliding-window version
// would drop both remaining costs, at the price of that contract.
//
// Bit-exactness with rtl/decoder_term.sv
// --------------------------------------
// The add-compare-select takes the *low* predecessor only on a strict `<`, so
// a metric tie falls through to the high one.  That matches
// rtl/gen/decoder.sv.j2:132 and model/ber_sweep.py:108.  It is not cosmetic:
// ties change the decoded message in 11% of three-error frames.  See
// docs/known-issues.md #6.
//
// Block:     MSG_BITS message bits + 3 zero tail bits -> MSG_BITS+3 stages
// Decision:  hard
// Trellis:   zero-tail terminated -- traceback starts from state 0.
// Latency:   STAGES trellis clocks + STAGES traceback clocks
// -------------------------------------------------------------------------

module decoder_folded #(
    parameter int MSG_BITS = 7
) (
    input  logic                        clk,
    input  logic                        reset,   // active low
    input  logic [2*(MSG_BITS+3)-1:0]   dat,
    output logic [MSG_BITS-1:0]         out,
    input  logic                        ready
);

  localparam int TAIL_BITS = 3;                       // K - 1 flush bits
  localparam int STAGES    = MSG_BITS + TAIL_BITS;
  localparam int CW_BITS   = 2 * STAGES;

  localparam int MW         = 4;                      // path-metric width
  localparam logic [MW-1:0] METRIC_INF = '1;          // unreachable marker
  localparam int CNTW       = $clog2(STAGES + 1) + 1;

  // ---------------------------------------------------------------------
  // State.  Note what is *not* here: there is no per-stage anything except
  // `surv`, which is one bit per state per stage of memory.
  // ---------------------------------------------------------------------
  logic [CW_BITS-1:0]  data;                  // received word, latched
  logic [MW-1:0]       pm    [0:7];           // path metrics, reused
  logic [7:0]          pmval;                 // which of the 8 are reachable
  logic [7:0]          surv  [0:STAGES-1];    // survivor decisions
  logic [CNTW-1:0]     stage;                 // trellis stage, counts up
  logic [CNTW-1:0]     tb;                    // traceback stage, counts down
  logic [2:0]          tb_state;              // current state during traceback
  logic                acs_done;
  logic                tb_done;

  // ---------------------------------------------------------------------
  // The received pair for the current stage.  dat[CW-1-2k] is out1 of stage
  // k and dat[CW-2-2k] is out0, the same order rtl/decoder_term.sv uses.
  // ---------------------------------------------------------------------
  logic [1:0] rxpair;
  always_comb begin
    rxpair = 2'b00;
    for (int k = 0; k < STAGES; k++)
      if (int'(stage) == k) rxpair = data[CW_BITS-1-2*k -: 2];
  end

  // ---------------------------------------------------------------------
  // One trellis stage, all 8 states at once.  Purely combinational -- this
  // is the hardware that gets reused every clock instead of replicated.
  // ---------------------------------------------------------------------
  logic [MW-1:0] nxt_pm  [0:7];
  logic [7:0]    nxt_val;
  logic [7:0]    nxt_surv;
  logic [MW-1:0] stage_min;

  always_comb begin
    logic [2:0]    lo, hi;
    logic          b;                       // input bit implied by the target
    logic          o1l, o0l, o1h, o0h;      // branch outputs from each pred
    logic [MW-1:0] bm_lo, bm_hi;            // Hamming distance, 0..2
    logic [MW-1:0] cand_lo, cand_hi;
    logic          take_lo;

    for (int s = 0; s < 8; s++) begin
      lo = 3'(2 * (s & 3));                 // predecessors: 2*(s&3) and +1
      hi = lo | 3'b001;
      b  = s[2];                            // g1/g0 from model/viterbi_ref.py

      o1l = b ^ lo[2] ^ lo[1] ^ lo[0];      // g1 = 1111
      o0l = b ^ lo[2] ^ lo[0];              // g0 = 1011
      o1h = b ^ hi[2] ^ hi[1] ^ hi[0];
      o0h = b ^ hi[2] ^ hi[0];

      // Widen each term before adding: a bare (a^b)+(c^d) on 1-bit operands
      // is 1-bit arithmetic and a distance of 2 would wrap to 0.
      bm_lo = MW'(o1l ^ rxpair[1]) + MW'(o0l ^ rxpair[0]);
      bm_hi = MW'(o1h ^ rxpair[1]) + MW'(o0h ^ rxpair[0]);

      cand_lo = pmval[lo] ? pm[lo] + bm_lo : METRIC_INF;
      cand_hi = pmval[hi] ? pm[hi] + bm_hi : METRIC_INF;

      // Strict `<`, so a tie falls through to the high predecessor.  This is
      // the same shape as decoder.sv.j2:132; do not "simplify" it to <=.
      take_lo      = pmval[lo] && (!pmval[hi] || cand_lo < cand_hi);
      nxt_val[s]   = pmval[lo] | pmval[hi];
      nxt_pm[s]    = take_lo ? cand_lo : cand_hi;
      nxt_surv[s]  = take_lo ? 1'b0 : 1'b1;   // 0 = low pred, 1 = high pred
    end

    // Renormalise: subtract the smallest reachable metric.  Subtracting a
    // constant from all 8 cannot change any later comparison, so the decode
    // is unaffected -- but it bounds the width for any block length.
    stage_min = METRIC_INF;
    for (int s = 0; s < 8; s++)
      if (nxt_val[s] && nxt_pm[s] < stage_min) stage_min = nxt_pm[s];
    for (int s = 0; s < 8; s++)
      if (nxt_val[s]) nxt_pm[s] = nxt_pm[s] - stage_min;
  end

  // ---------------------------------------------------------------------
  // Sequencing.  Trellis: one stage per clock.  Traceback: one stage per
  // clock, walking STAGES-1 down to 0 from the known end state 0.
  // ---------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!reset) begin
      data     <= dat;
      pm[0]    <= '0;
      pmval    <= 8'b0000_0001;          // only state 0 is reachable at first
      for (int s = 1; s < 8; s++) pm[s] <= METRIC_INF;
      for (int k = 0; k < STAGES; k++) surv[k] <= '0;
      stage    <= '0;
      tb       <= CNTW'(STAGES - 1);
      tb_state <= 3'd0;                  // zero-tail terminated
      acs_done <= 1'b0;
      tb_done  <= 1'b0;
      out      <= '0;
    end
    else if (!acs_done) begin
      surv[stage] <= nxt_surv;
      for (int s = 0; s < 8; s++) pm[s] <= nxt_pm[s];
      pmval <= nxt_val;
      if (int'(stage) == STAGES - 1) acs_done <= 1'b1;
      stage <= stage + CNTW'(1);
    end
    else if (ready && !tb_done) begin
      // The bit that entered tb_state is its top bit.  Traceback runs from
      // the last stage backwards, so the first TAIL_BITS bits recovered are
      // the zero tail and are dropped.
      if (int'(tb) < MSG_BITS) out[MSG_BITS-1-int'(tb)] <= tb_state[2];
      tb_state <= {tb_state[1:0], surv[tb][tb_state]};
      if (tb == '0) tb_done <= 1'b1;
      else          tb <= tb - CNTW'(1);
    end
  end

`ifndef SYNTHESIS
  // The bound the 4-bit width rests on.  If a future code or a soft-decision
  // branch metric breaks it, fail loudly rather than wrap silently.
  always_ff @(posedge clk)
    if (reset && !acs_done)
      for (int s = 0; s < 8; s++)
        if (nxt_val[s] && nxt_pm[s] > MW'(7))
          $fatal(1, "decoder_folded: normalised metric %0d exceeds the width bound",
                 nxt_pm[s]);
`endif

endmodule
