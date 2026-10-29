// Direct TinyNPU 16x16 systolic-array run for the common INT8 GEMM vector.
// This drives the pinned upstream engine_tb_top wrapper without modifying
// TinyNPU RTL. Inputs and the integer Golden match the NMAForge case 105 TB.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include "Vengine_tb_top.h"

static Vengine_tb_top dut;
static uint64_t cycles = 0;

static void tick() {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    ++cycles;
}

static int8_t operand_a(int row, int k) {
    return static_cast<int8_t>(((row * 3 + k * 2 + 1) % 9) - 4);
}

static int8_t operand_b(int k, int col) {
    // Preserve SystemVerilog signed remainder semantics for negative values.
    return static_cast<int8_t>(((k * 2 - col * 3 + 5) % 9) - 4);
}

static void clear_words() {
    for (int i = 0; i < 4; ++i) {
        dut.sa_a_col_flat[i] = 0;
        dut.sa_b_row_flat[i] = 0;
    }
}

int main() {
    constexpr int M = 16;
    constexpr int N = 16;
    constexpr int K = 16;
    constexpr int useful_macs = M * N * K;
    std::vector<int32_t> golden(M * N, 0);

    dut.clk = 0;
    dut.rst_n = 0;
    dut.sa_en = 0;
    dut.sa_clear_acc = 0;
    dut.sa_acc_rd_row = 0;
    dut.sa_acc_rd_col = 0;
    clear_words();
    for (int i = 0; i < 10; ++i) tick();
    dut.rst_n = 1;
    tick();

    for (int row = 0; row < M; ++row)
        for (int col = 0; col < N; ++col)
            for (int k = 0; k < K; ++k)
                golden[row * N + col] +=
                    static_cast<int32_t>(operand_a(row, k)) *
                    static_cast<int32_t>(operand_b(k, col));

    dut.sa_clear_acc = 1;
    tick();
    dut.sa_clear_acc = 0;
    tick();

    const uint64_t start_cycle = cycles;
    // The upstream array uses diagonal wavefront skew: A row i and B column j
    // are delayed by i/j cycles. The logical matrices are identical to the
    // NMAForge testbench case; only the array's native input schedule differs.
    const int feed_cycles = M + N + K;
    for (int c = 0; c < feed_cycles; ++c) {
        uint32_t a_flat[4] = {0, 0, 0, 0};
        uint32_t b_flat[4] = {0, 0, 0, 0};
        for (int row = 0; row < M; ++row) {
            const int k = c - row;
            if (k >= 0 && k < K) {
                const uint32_t byte = static_cast<uint8_t>(operand_a(row, k));
                a_flat[row / 4] |= byte << ((row % 4) * 8);
            }
        }
        for (int col = 0; col < N; ++col) {
            const int k = c - col;
            if (k >= 0 && k < K) {
                const uint32_t byte = static_cast<uint8_t>(operand_b(k, col));
                b_flat[col / 4] |= byte << ((col % 4) * 8);
            }
        }
        dut.sa_a_col_flat[0] = a_flat[0];
        dut.sa_a_col_flat[1] = a_flat[1];
        dut.sa_a_col_flat[2] = a_flat[2];
        dut.sa_a_col_flat[3] = a_flat[3];
        dut.sa_b_row_flat[0] = b_flat[0];
        dut.sa_b_row_flat[1] = b_flat[1];
        dut.sa_b_row_flat[2] = b_flat[2];
        dut.sa_b_row_flat[3] = b_flat[3];
        dut.sa_en = 1;
        tick();
    }
    dut.sa_en = 0;
    clear_words();
    for (int i = 0; i < 4; ++i) tick();

    int mismatches = 0;
    for (int row = 0; row < M; ++row) {
        for (int col = 0; col < N; ++col) {
            dut.sa_acc_rd_row = row;
            dut.sa_acc_rd_col = col;
            dut.eval();
            const int32_t actual = static_cast<int32_t>(dut.sa_acc_rd_data);
            const int32_t expected = golden[row * N + col];
            if (actual != expected) {
                if (mismatches < 8)
                    std::fprintf(stderr,
                        "GEMM mismatch row=%d col=%d actual=%d expected=%d\n",
                        row, col, actual, expected);
                ++mismatches;
            }
        }
    }

    const uint64_t elapsed = cycles - start_cycle;
    const double mac_per_cycle = static_cast<double>(useful_macs) / elapsed;
    const double utilization = 100.0 * useful_macs / (256.0 * elapsed);
    if (mismatches != 0) {
        std::fprintf(stderr, "TINYNPU_MATCHED_GEMM_FAIL mismatches=%d\n", mismatches);
        return EXIT_FAILURE;
    }
    std::printf(
        "TINYNPU_MATCHED_GEMM_PASS shape=16x16x16 physical_array=16x16 "
        "cycles_input_to_array_stable=%llu macs=%d mac_per_cycle=%.4f "
        "pe_utilization_pct=%.2f golden=256/256\n",
        static_cast<unsigned long long>(elapsed), useful_macs,
        mac_per_cycle, utilization);
    return EXIT_SUCCESS;
}
