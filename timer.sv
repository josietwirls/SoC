// Reaction timer with states: IDLE, START, REACTION, LATE, EARLY, WIN
module timer #(
  parameter int CLK_HZ      = 100_000_000,
  parameter int MS_TICK_HZ  = 1_000,          // 1 kHz -> 1 ms tick
  parameter int RAND_MIN_MS = 2000,           // inclusive
  parameter int RAND_MAX_MS = 15000           // inclusive
)(
  input  logic       clk,
  input  logic       rst_n,        // async active-low -> IDLE
  input  logic       start_btn,    // rising-edge armed
  input  logic       stop_btn,     // rising-edge stop
  output logic       stim_led,     // on during REACTION
  output logic [7:0] sseg,
  output logic [7:0] an
);
  // -------- state encoding --------
  typedef enum logic [2:0] {
    IDLE,       // show "HI"
    START,      // random wait; false start -> EARLY
    REACTION,   // LED on; count ms; stop -> WIN; timeout -> LATE
    WIN,        // freeze display
    LATE,       // show 1000
    EARLY       // show 9999
  } state_t;

  state_t cs, ns;

  // -------- sync + edge detect for buttons --------
  logic [1:0] start_sync, stop_sync;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_sync <= 2'b00;
      stop_sync  <= 2'b00;
    end else begin
      start_sync <= {start_sync[0], start_btn};
      stop_sync  <= {stop_sync[0],  stop_btn};
    end
  end
  wire start_pe = (start_sync[1] & ~start_sync[0]);
  wire stop_pe  = (stop_sync[1]  & ~stop_sync[0]);

  // -------- 1 ms tick generator --------
  localparam int CYCLES_PER_TICK = CLK_HZ / MS_TICK_HZ;
  localparam int TICKW = (CYCLES_PER_TICK > 1) ? $clog2(CYCLES_PER_TICK) : 1;
  logic [TICKW-1:0] tick_cnt;
  wire ms_tick = (tick_cnt == CYCLES_PER_TICK-1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          tick_cnt <= '0;
    else if (ms_tick)    tick_cnt <= '0;
    else                 tick_cnt <= tick_cnt + 1'b1;
  end

  // -------- ms elapsed counter --------
  logic [15:0] ms_elapsed;
  logic        ms_count_en;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      ms_elapsed <= '0;
    else if (ns != cs)
      // clear entering START or REACTION
      ms_elapsed <= ((ns==START) || (ns==REACTION)) ? 16'd0 : ms_elapsed;
    else if (ms_tick && ms_count_en)
      ms_elapsed <= ms_elapsed + 1'b1;
  end

  // -------- PRBS random target (snapshot at START entry) --------
  localparam int N_RANDOM = 14;
  logic [N_RANDOM-1:0] rnd_bus;

  prbs #(.N(N_RANDOM)) u_prbs (
    .clk    (clk),
    .rst_n  (rst_n),
    .rnd_bus(rnd_bus)
  );

  // clamp to [RAND_MIN_MS .. RAND_MAX_MS]
  localparam int RANGE = (RAND_MAX_MS - RAND_MIN_MS + 1);
  logic [15:0] rand_target_ms;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      rand_target_ms <= RAND_MIN_MS[15:0];
    else if (cs != START && ns == START)
      rand_target_ms <= RAND_MIN_MS + (rnd_bus % RANGE);
  end

  // -------- 7-seg driver --------
  logic [15:0] digits;

  sseg u_sseg (
    .clk   (clk),
    .rst_n (rst_n),
    .digits(digits),
    .sseg  (sseg),
    .an    (an)
  );

  // "HI" on the rightmost two nibbles
  localparam logic [3:0] NBLK = 4'hB; // blank
  // in LUT: H=4'hC, I=4'hE
  wire [15:0] HI = {NBLK, NBLK, 4'hC, 4'hE};

  // -------- next-state / outputs --------
  always_comb begin
    ns          = cs;
    stim_led    = 1'b0;
    ms_count_en = 1'b0;
    digits      = HI;

    unique case (cs)
      IDLE: begin
        digits = HI;
        if (start_pe) ns = START;
      end

      START: begin
        digits      = {NBLK,NBLK,NBLK,NBLK}; // blank while waiting
        ms_count_en = 1'b1;                  // count up until target
        if (stop_pe)                     ns = EARLY;           // false start
        else if (ms_elapsed >= rand_target_ms) ns = REACTION; // GO
      end

      REACTION: begin
        stim_led    = 1'b1;
        ms_count_en = 1'b1;
        // show live ms
        digits[3:0]    =  ms_elapsed % 10;
        digits[7:4]    = (ms_elapsed / 10)   % 10;
        digits[11:8]   = (ms_elapsed / 100)  % 10;
        digits[15:12]  = (ms_elapsed / 1000) % 10;

        if (stop_pe)                     ns = WIN;
        else if (ms_elapsed >= 16'd1000) ns = LATE; // 1000 ms cap
      end

      WIN: begin
        digits[3:0]    =  ms_elapsed % 10;
        digits[7:4]    = (ms_elapsed / 10)   % 10;
        digits[11:8]   = (ms_elapsed / 100)  % 10;
        digits[15:12]  = (ms_elapsed / 1000) % 10;
      end

      LATE:  digits = 16'h1000; // timeout
      EARLY: digits = 16'h9999; // false start

      default: ns = IDLE;
    endcase
  end

  // -------- state register --------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cs <= IDLE;
    else        cs <= ns;
  end
endmodule
