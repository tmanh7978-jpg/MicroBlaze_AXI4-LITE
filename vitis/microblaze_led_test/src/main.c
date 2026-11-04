/*
 * AXI4-Lite LED Controller - 6 focused test cases
 * Target: MicroBlaze Standalone application in AMD Vitis
 *
 * Register map inherited from the user's original main.c:
 *   LED_DATA: AXI base + 0x00, low 4 bits select an LED data pattern.
 *   LED_CTRL: AXI base + 0x04, control word written by software.
 *
 * IMPORTANT:
 *   LED_CTRL bit meanings MUST be checked against the actual Verilog RTL.
 *   If CTRL[0] is enable and CTRL[1] is blink, writing CTRL=0x2
 *   disables the output, even if LED_DATA is 0xB / 1011.
 *   The tests below apply the combinations requested; they DO NOT
 *   assume that a written DATA pattern necessarily appears on the LEDs.
 *
 * This code checks AXI register readback only. It cannot automatically
 * prove physical LED behavior or the rate of blinking.
 */

#include "xil_io.h"
#include <stdint.h>

#define LED_BASE_ADDR        0x44A00000U
#define LED_DATA_ADDR        (LED_BASE_ADDR + 0x00U)
#define LED_CTRL_ADDR        (LED_BASE_ADDR + 0x04U)

#define LED_DATA_MASK        0x0FU
#define LED_CTRL_TEST_MASK   0x03U
#define NUMBER_OF_CASES     6U

/* 0 = long hold for real board; 1 = short hold for a testbench/debugger.
 * Busy-loop timing is not calibrated in milliseconds.
 */
#define FAST_SIMULATION      0
/* 1 = cycle through all 6 cases repeatedly, 0 = do one pass and stop. */
#define REPEAT_SEQUENCE      1

#if FAST_SIMULATION
  #define NORMAL_HOLD_LOOPS   1000U
  #define BLINK_HOLD_LOOPS   10000U
#else
  #define NORMAL_HOLD_LOOPS   20000000U
  #define BLINK_HOLD_LOOPS   120000000U
#endif

typedef struct {
    uint32_t led_data;
    uint32_t led_ctrl;
    uint32_t hold_loops;
} LedTestCase;

/*
 * Test#  DATA(4b) CTRL(4b)  Purpose
 *   1     0000     0000     all off
 *   2     0101     0001     user request: DATA=0101, CTRL=0001
 *   3     1011     0010     user request: DATA=1011, CTRL=0010
 *   4     1010     0011     user request: DATA=1010, CTRL=0011
 *   5     1111     0001     all four LEDs on (if CTRL bit0 is enable)
 *   6     1111     0000     controller off despite DATA=1111
 */
static const LedTestCase tests[NUMBER_OF_CASES] = {
    {0x00U, 0x00U, NORMAL_HOLD_LOOPS}, /* 1 */
    {0x05U, 0x01U, NORMAL_HOLD_LOOPS}, /* 2 */
    {0x0BU, 0x02U, BLINK_HOLD_LOOPS},  /* 3 */
    {0x0AU, 0x03U, BLINK_HOLD_LOOPS},  /* 4 */
    {0x0FU, 0x01U, NORMAL_HOLD_LOOPS}, /* 5 */
    {0x0FU, 0x00U, NORMAL_HOLD_LOOPS}  /* 6 */
};

/* Vitis debugger / testbench observation variables. */
volatile uint32_t current_case_number = 0U; /* 1 .. 6 */
volatile uint32_t current_led_data = 0U;
volatile uint32_t current_led_ctrl = 0U;
volatile uint32_t last_data_readback = 0U;
volatile uint32_t last_ctrl_readback = 0U;
volatile uint32_t case_pass[NUMBER_OF_CASES] = {0U};
volatile uint32_t case_data_readback[NUMBER_OF_CASES] = {0U};
volatile uint32_t case_ctrl_readback[NUMBER_OF_CASES] = {0U};
volatile uint32_t test_total = 0U;
volatile uint32_t test_passed = 0U;
volatile uint32_t test_failed = 0U;
volatile uint32_t completed_cycles = 0U;
volatile uint32_t first_cycle_done = 0U;

static void hold_output(uint32_t loops)
{
    volatile uint32_t k;
    for (k = 0U; k < loops; ++k) {
        /* Deliberate delay to observe each physical LED state. */
    }
}

int main(void)
{
    uint32_t i;
    uint32_t requested_data;
    uint32_t requested_ctrl;
    uint32_t actual_data;
    uint32_t actual_ctrl;
    uint32_t pass;

    /* Start from a known state. */
    Xil_Out32(LED_CTRL_ADDR, 0x00U);
    Xil_Out32(LED_DATA_ADDR, 0x00U);

    do {
        for (i = 0U; i < NUMBER_OF_CASES; ++i) {
            requested_data = tests[i].led_data;
            requested_ctrl = tests[i].led_ctrl;

            current_case_number = i + 1U;
            current_led_data = requested_data;
            current_led_ctrl = requested_ctrl;

            /* Disable first to avoid intermediate LED patterns. */
            Xil_Out32(LED_CTRL_ADDR, 0x00U);
            Xil_Out32(LED_DATA_ADDR, requested_data);
            Xil_Out32(LED_CTRL_ADDR, requested_ctrl);

            actual_data = Xil_In32(LED_DATA_ADDR);
            actual_ctrl = Xil_In32(LED_CTRL_ADDR);
            last_data_readback = actual_data;
            last_ctrl_readback = actual_ctrl;
            case_data_readback[i] = actual_data;
            case_ctrl_readback[i] = actual_ctrl;

            /* Readback PASS != physical LED operation PASS. */
            pass = (((actual_data & LED_DATA_MASK) == requested_data) &&
                    ((actual_ctrl & LED_CTRL_TEST_MASK) == requested_ctrl)) ? 1U : 0U;
            case_pass[i] = pass;
            ++test_total;
            if (pass != 0U) {
                ++test_passed;
            } else {
                ++test_failed;
            }

            hold_output(tests[i].hold_loops);
        }

        ++completed_cycles;
        first_cycle_done = 1U;
    } while (REPEAT_SEQUENCE != 0);

    /* For single-pass simulations, hold at last test state. */
    while (1) {
    }

    /* Unreachable. */
    /* return 0; */
}
