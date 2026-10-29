// Direct TinyNPU tiled 16x16 systolic-array runs for common INT8 GEMM vectors.
// This drives the pinned upstream engine_tb_top wrapper without modifying
// TinyNPU RTL. Inputs and integer Golden match NMAForge cases 105-107.
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

static bool run_gemm(int m, int n, int k) {
    constexpr int TILE = 16;
    std::vector<int32_t> golden(m * n, 0);
    std::vector<int32_t> actual(m * n, 0);

    for (int row = 0; row < m; ++row)
        for (int col = 0; col < n; ++col)
            for (int kk = 0; kk < k; ++kk)
                golden[row * n + col] +=
                    static_cast<int32_t>(operand_a(row, kk)) *
                    static_cast<int32_t>(operand_b(kk, col));

    uint64_t start_cycle = 0;
    for (int tile_row = 0; tile_row < m; tile_row += TILE) {
        for (int tile_col = 0; tile_col < n; tile_col += TILE) {
            // One accumulator clear per output tile; K tiles accumulate into
            // the same 16x16 array before its values are read back.
            dut.sa_clear_acc = 1;
            tick();
            dut.sa_clear_acc = 0;
            tick();
            if (tile_row == 0 && tile_col == 0)
                start_cycle = cycles;

            for (int k_base = 0; k_base < k; k_base += TILE) {
                // The upstream array uses a diagonal wavefront: each A row
                // and B column is skewed by its local index. Forty-eight
                // cycles include the feed and the empty drain slots between
                // K tiles; accumulators are retained across those K tiles.
                for (int c = 0; c < 3 * TILE; ++c) {
                    uint32_t a_flat[4] = {0, 0, 0, 0};
                    uint32_t b_flat[4] = {0, 0, 0, 0};
                    for (int row = 0; row < TILE; ++row) {
                        const int local_k = c - row;
                        if (local_k >= 0 && local_k < TILE) {
                            const uint32_t byte = static_cast<uint8_t>(
                                operand_a(tile_row + row, k_base + local_k));
                            a_flat[row / 4] |= byte << ((row % 4) * 8);
                        }
                    }
                    for (int col = 0; col < TILE; ++col) {
                        const int local_k = c - col;
                        if (local_k >= 0 && local_k < TILE) {
                            const uint32_t byte = static_cast<uint8_t>(
                                operand_b(k_base + local_k, tile_col + col));
                            b_flat[col / 4] |= byte << ((col % 4) * 8);
                        }
                    }
                    for (int word = 0; word < 4; ++word) {
                        dut.sa_a_col_flat[word] = a_flat[word];
                        dut.sa_b_row_flat[word] = b_flat[word];
                    }
                    dut.sa_en = 1;
                    tick();
                }
                dut.sa_en = 0;
                clear_words();
            }

            // Let the final products in this output tile settle before
            // reading them or clearing the array for another output tile.
            for (int i = 0; i < 4; ++i) tick();
            for (int row = 0; row < TILE; ++row) {
                for (int col = 0; col < TILE; ++col) {
                    dut.sa_acc_rd_row = row;
                    dut.sa_acc_rd_col = col;
                    dut.eval();
                    actual[(tile_row + row) * n + tile_col + col] =
                        static_cast<int32_t>(dut.sa_acc_rd_data);
                }
            }
        }
    }

    const uint64_t elapsed = cycles - start_cycle;
    const int useful_macs = m * n * k;
    const double mac_per_cycle = static_cast<double>(useful_macs) / elapsed;
    const double utilization = 100.0 * useful_macs / (256.0 * elapsed);
    int mismatches = 0;
    for (int index = 0; index < m * n; ++index) {
        if (actual[index] != golden[index]) {
            if (mismatches < 8)
                std::fprintf(stderr,
                    "GEMM mismatch shape=%dx%dx%d output=%d actual=%d expected=%d\n",
                    m, n, k, index, actual[index], golden[index]);
            ++mismatches;
        }
    }
    if (mismatches != 0) {
        std::fprintf(stderr,
            "TINYNPU_MATCHED_GEMM_FAIL shape_mnk=%d,%d,%d mismatches=%d\n",
            m, n, k, mismatches);
        return false;
    }
    std::printf(
        "TINYNPU_MATCHED_GEMM_PASS shape_mnk=%d,%d,%d physical_array=16x16 "
        "cycles_input_to_array_stable=%llu macs=%d mac_per_cycle=%.4f "
        "pe_utilization_pct=%.2f golden=%d/%d\n",
        m, n, k, static_cast<unsigned long long>(elapsed), useful_macs,
        mac_per_cycle, utilization, m * n, m * n);
    return true;
}

int main() {
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

    if (!run_gemm(16, 16, 16) ||
        !run_gemm(16, 16, 32) ||
        !run_gemm(32, 32, 64))
        return EXIT_FAILURE;
    return EXIT_SUCCESS;
}
