/*****************************************************************//**
 * @file main.cpp
 *
 * @brief Bop It game implementation using FPGA peripherals
 *
 * @description
 * - Button (btn[0]): Start game / "Bop It"
 * - Switch (sw[0]): "Pull It"
 * - Accelerometer tilt: "Twist It"
 * - Seven-segment display: Shows action (left) and score (right)
 * - LEDs: Visual indicators for actions
 * - DDFS/ADSR: Audio feedback
 *
 *********************************************************************/

#include "chu_init.h"
#include "gpio_cores.h"
#include "sseg_core.h"
#include "spi_core.h"
#include "ddfs_core.h"
#include "adsr_core.h"
#include <stdlib.h>
#include <time.h>

// Game states
enum GameState {
    IDLE,
    PLAYING,
    GAME_OVER
};

// Action types
enum Action {
    BOP = 0,
    PULL = 1,
    TWIST = 2
};

// Audio frequencies (Hz)
const int FREQ_START = 523;      // C5 - Game start
const int FREQ_BOP = 659;        // E5 - Bop action
const int FREQ_PULL = 784;       // G5 - Pull action
const int FREQ_TWIST = 880;      // A5 - Twist action
const int FREQ_SUCCESS = 1047;   // C6 - Correct action
const int FREQ_FAIL = 196;       // G3 - Game over

// Game timing
const int BASE_TIME = 3000;      // Base time in ms (3 seconds initially)
const int MIN_TIME = 800;        // Minimum time in ms
const int TIME_DECREMENT = 150;  // Time decrease per level (gets faster)

// Accelerometer constants
const uint8_t RD_CMD = 0x0b;
const uint8_t DATA_REG = 0x08;
const float TILT_THRESHOLD = 0.5; // G-force threshold for tilt detection

// Global objects
GpoCore led(get_slot_addr(BRIDGE_BASE, S2_LED));
GpiCore sw(get_slot_addr(BRIDGE_BASE, S3_SW));
DebounceCore btn(get_slot_addr(BRIDGE_BASE, S7_BTN));
SsegCore sseg(get_slot_addr(BRIDGE_BASE, S8_SSEG));
SpiCore spi(get_slot_addr(BRIDGE_BASE, S9_SPI));
DdfsCore ddfs(get_slot_addr(BRIDGE_BASE, S12_DDFS));
AdsrCore adsr(get_slot_addr(BRIDGE_BASE, S13_ADSR), &ddfs);

/**
 * Play a tone for a specified duration
 */
void play_tone(int freq, int duration_ms) {
    ddfs.set_carrier_freq(freq);
    ddfs.set_env(1.0);  // Full volume
    sleep_ms(duration_ms);
    ddfs.set_env(0.0);  // Silence
}

/**
 * Initialize SPI for accelerometer
 */
void init_accelerometer() {
    spi.set_freq(400000);
    spi.set_mode(0, 0);
}

/**
 * Read accelerometer x, y, z values
 * Returns true if read successful
 */
bool read_accel(float &x, float &y, float &z) {
    const float raw_max = 127.0 / 2.0;  // 128 max 8-bit reading for +/-2g
    int8_t xraw, yraw, zraw;
    
    spi.assert_ss(0);
    spi.transfer(RD_CMD);
    spi.transfer(DATA_REG);
    xraw = spi.transfer(0x00);
    yraw = spi.transfer(0x00);
    zraw = spi.transfer(0x00);
    spi.deassert_ss(0);
    
    x = (float)xraw / raw_max;
    y = (float)yraw / raw_max;
    z = (float)zraw / raw_max;
    
    return true;
}

/**
 * Detect if board is tilted significantly
 */
bool is_tilted() {
    float x, y, z;
    read_accel(x, y, z);
    
    // Check if x or y axis exceeds threshold (board tilted)
    if (abs(x) > TILT_THRESHOLD || abs(y) > TILT_THRESHOLD) {
        return true;
    }
    return false;
}

/**
 * Display action text on left side of seven-segment display
 * Note: For seven-segment displays, 0 = segment ON, 1 = segment OFF
 */
void display_action(Action action) {
    sseg.set_dp(0x00);
    
    switch(action) {
        case BOP:
            // Display "bOP  "
            sseg.write_1ptn(0xFF, 7);           // blank
            sseg.write_1ptn(0b10000000, 6);     // b (segments: a,b,c,d,e,f,g = 1111100)
            sseg.write_1ptn(0b11000000, 5);     // O (segments: a,b,c,d,e,f)
            sseg.write_1ptn(0b10001100, 4);     // P (segments: a,b,e,f,g)
            break;
            
        case PULL:
            // Display "PULL"
            sseg.write_1ptn(0b10001100, 7);     // P (segments: a,b,e,f,g)
            sseg.write_1ptn(0b11000001, 6);     // U (segments: b,c,d,e,f)
            sseg.write_1ptn(0b11000111, 5);     // L (segments: d,e,f)
            sseg.write_1ptn(0b11000111, 4);     // L (segments: d,e,f)
            break;
            
        case TWIST:
            // Display "turn"
            sseg.write_1ptn(0b10000111, 7);     // t (segments: d,e,f,g)
            sseg.write_1ptn(0b11000001, 6);     // U (segments: b,c,d,e,f)
            sseg.write_1ptn(0b11001110, 5);     // r (segments: e,g)
            sseg.write_1ptn(0b11001000, 4);     // n (segments: c,e,g)
            break;
    }
}

/**
 * Display score on right side of seven-segment display
 */
void display_score(int score) {
    int digit;
    
    // Display up to 4 digits (0-9999)
    for (int i = 0; i < 4; i++) {
        digit = score % 10;
        sseg.write_1ptn(sseg.h2s(digit), i);
        score /= 10;
    }
}

/**
 * Set LED pattern based on action
 */
void set_led_pattern(Action action) {
    switch(action) {
        case BOP:
            led.write(0b00011000);  // Center LEDs
            break;
        case PULL:
            led.write(0b11111111);  // All LEDs
            break;
        case TWIST:
            led.write(0b10000001);  // Edge LEDs
            break;
    }
}

/**
 * Clear all displays
 */
void clear_displays() {
    led.write(0x00);
    sseg.set_dp(0x00);
    // Clear all 8 digits - 0xFF turns off all segments
    for (int i = 0; i < 8; i++) {
        sseg.write_1ptn(0xFF, i);
    }
}

/**
 * Check if button is pressed
 */
bool button_pressed() {
    static int last_btn = 0;
    int current_btn = btn.read_db();
    
    // Check if button 0 was just pressed (rising edge)
    if ((current_btn & 0x01) && !(last_btn & 0x01)) {
        last_btn = current_btn;
        return true;
    }
    last_btn = current_btn;
    return false;
}

/**
 * Check if switch is flipped to ON position
 */
bool switch_pulled() {
    static int last_sw = -1;  // Initialize to -1 for first read
    int current_sw = sw.read();
    
    // First read - just store the state
    if (last_sw == -1) {
        last_sw = current_sw;
        return false;
    }
    
    // Check if switch 0 transitioned from OFF to ON (rising edge)
    bool result = false;
    if ((current_sw & 0x01) && !(last_sw & 0x01)) {
        result = true;
    }
    
    last_sw = current_sw;
    return result;
}

/**
 * Reset switch state tracking (call before waiting for new action)
 */
void reset_switch_state() {
    sw.read();  // Read current state to update internal tracking
}

/**
 * Check if any wrong action was performed
 */
bool wrong_action_performed(Action expected_action) {
    if (expected_action != BOP && button_pressed()) {
        uart.disp("Wrong action: pressed button when not BOP\n\r");
        return true;
    }
    if (expected_action != PULL && switch_pulled()) {
        uart.disp("Wrong action: pulled switch when not PULL\n\r");
        return true;
    }
    if (expected_action != TWIST && is_tilted()) {
        uart.disp("Wrong action: tilted board when not TWIST\n\r");
        return true;
    }
    return false;
}

/**
 * Check if correct action was performed
 */
bool check_action(Action expected_action) {
    if (expected_action == BOP) {
        return button_pressed();
    } else if (expected_action == PULL) {
        return switch_pulled();
    } else { // TWIST
        return is_tilted();
    }
}

/**
 * Generate random action
 */
Action get_random_action() {
    return (Action)(rand() % 3);
}

/**
 * Calculate time allowed based on score
 */
int get_time_limit(int score) {
    int time = BASE_TIME - (score * TIME_DECREMENT);
    if (time < MIN_TIME) {
        time = MIN_TIME;
    }
    return time;
}

/**
 * Play action prompt tone with distinctive patterns
 */
void play_action_tone(Action action) {
    switch(action) {
        case BOP:
            // Two quick beeps for "BOP IT"
            play_tone(FREQ_BOP, 100);
            sleep_ms(50);
            play_tone(FREQ_BOP, 100);
            break;
        case PULL:
            // Rising tone for "PULL IT"
            play_tone(FREQ_PULL - 100, 80);
            play_tone(FREQ_PULL, 80);
            play_tone(FREQ_PULL + 100, 80);
            break;
        case TWIST:
            // Warbling tone for "TWIST IT"
            for (int i = 0; i < 3; i++) {
                play_tone(FREQ_TWIST, 60);
                play_tone(FREQ_TWIST + 50, 60);
            }
            break;
    }
}

/**
 * Main game loop
 */
void play_game(int &high_score) {
    int score = 0;
    Action current_action;
    unsigned long action_start_time;
    int time_limit;
    bool action_completed;
    bool wrong_action;
    
    // Game start sequence
    clear_displays();
    play_tone(FREQ_START, 500);
    sleep_ms(500);
    
    while (true) {
        // Generate new action
        current_action = get_random_action();
        time_limit = get_time_limit(score);
        
        uart.disp("Action: ");
        if (current_action == BOP) uart.disp("BOP");
        else if (current_action == PULL) uart.disp("PULL");
        else uart.disp("TWIST");
        uart.disp(" | Time: ");
        uart.disp(time_limit);
        uart.disp(" ms\n\r");
        
        // Display action
        display_action(current_action);
        display_score(score);
        set_led_pattern(current_action);
        
        // Play action tone
        play_action_tone(current_action);
        
        // Reset switch state before waiting for action
        reset_switch_state();
        
        // Wait for action or timeout
        action_start_time = now_ms();
        action_completed = false;
        wrong_action = false;
        
        while ((now_ms() - action_start_time) < time_limit) {
            // Check for correct action
            if (check_action(current_action)) {
                action_completed = true;
                uart.disp("Correct action!\n\r");
                break;
            }
            
            // Check for wrong action
            if (wrong_action_performed(current_action)) {
                wrong_action = true;
                break;
            }
            
            sleep_ms(10);  // Small delay to prevent excessive polling
        }
        
        // Check if player made a mistake
        if (wrong_action) {
            uart.disp("Wrong action! Game Over.\n\r");
            break;
        }
        
        if (!action_completed) {
            // Game over - failed to complete action in time
            uart.disp("Timeout! Game Over.\n\r");
            break;
        }
        
        // Success - increment score and play success tone
        score++;
        uart.disp("Score: ");
        uart.disp(score);
        uart.disp("\n\r");
        play_tone(FREQ_SUCCESS, 150);
        sleep_ms(200);
    }
    
    // Update high score if needed
    if (score > high_score) {
        high_score = score;
    }
    
    uart.disp("Final Score: ");
    uart.disp(score);
    uart.disp(" | High Score: ");
    uart.disp(high_score);
    uart.disp("\n\r");
    
    // Game over sequence
    play_tone(FREQ_FAIL, 800);
    
    // Display final score and high score
    clear_displays();
    
    // Show "LOSE" on left side
    sseg.write_1ptn(0b11000111, 7);  // L (segments: d,e,f)
    sseg.write_1ptn(0b11000000, 6);  // O (segments: a,b,c,d,e,f)
    sseg.write_1ptn(0b10010010, 5);  // S (segments: a,c,d,f,g)
    sseg.write_1ptn(0b10000110, 4);  // E (segments: a,d,e,f,g)
    
    // Show high score on right side
    display_score(high_score);
    
    // Flash LEDs
    for (int i = 0; i < 5; i++) {
        led.write(0xFF);
        sleep_ms(200);
        led.write(0x00);
        sleep_ms(200);
    }
    
    sleep_ms(3000);
    clear_displays();
}

/**
 * Idle state - wait for start button
 */
void wait_for_start() {
    // Ensure everything is cleared first
    sseg.set_dp(0x00);
    for (int i = 0; i < 8; i++) {
        sseg.write_1ptn(0xFF, i);
    }
    led.write(0x00);
    
    sleep_ms(50);  // Brief delay to ensure clear
    
    // Display "PUSH" on left to indicate start
    sseg.write_1ptn(0b10001100, 7);  // P (segments: a,b,e,f,g)
    sseg.write_1ptn(0b11000001, 6);  // U (segments: b,c,d,e,f)
    sseg.write_1ptn(0b10010010, 5);  // S (segments: a,c,d,f,g)
    sseg.write_1ptn(0b10001001, 4);  // H (segments: b,c,e,f,g)
    
    // Right side shows 0000
    for (int i = 0; i < 4; i++) {
        sseg.write_1ptn(sseg.h2s(0), i);
    }
    
    // Animate LEDs
    int led_pattern = 0b00000001;
    while (!button_pressed()) {
        led.write(led_pattern);
        led_pattern = (led_pattern << 1) | (led_pattern >> 7);
        if (led_pattern == 0) led_pattern = 0b00000001;
        sleep_ms(100);
    }
    
    led.write(0x00);
}

/**
 * Main function
 */
int main() {
    int high_score = 0;
    
    // Initialize peripherals
    init_accelerometer();
    
    // Initialize DDFS to use direct envelope control (not ADSR)
    ddfs.set_env_source(0);  // Use direct envelope control
    ddfs.set_env(0.0);       // Start silent
    
    // Explicitly clear all displays at startup
    sseg.set_dp(0x00);
    for (int i = 0; i < 8; i++) {
        sseg.write_1ptn(0xFF, i);
    }
    led.write(0x00);
    
    // Small delay to ensure displays are cleared
    sleep_ms(100);
    
    // Seed random number generator
    srand(now_ms());
    
    uart.disp("Bop It Game Starting...\n\r");
    uart.disp("Button 0: Start/Bop It\n\r");
    uart.disp("Switch 0: Pull It\n\r");
    uart.disp("Tilt Board: Twist It\n\r\n\r");
    
    while (true) {
        // Wait for player to start game
        wait_for_start();
        
        // Play game
        play_game(high_score);
        
        // Short delay before returning to idle
        sleep_ms(1000);
    }
    
    return 0;
}
