// Direct TinyNPU tiled 16x16 systolic-array runs for common INT8 GEMM vectors.
// This drives the pinned upstream engine_tb_top wrapper without modifying
// TinyNPU RTL. Inputs and integer Golden match NMAForge cases 105-107.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <fstream>
#include <string>

#include "Vengine_tb_top.h"

static Vengine_tb_top dut;
static uint64_t cycles = 0;
static std::vector<int8_t> shared_a, shared_b;

static void tick() {
    dut.clk = 0;
    dut.eval();
    dut.clk = 1;
    dut.eval();
    ++cycles;
}

static int8_t operand_a(int row, int k, int workload) {
    if (workload == 3) return shared_a[row * 16 + k];
    if (workload == 1)  // Same padded M=1, K=17 product-GEMV fixture as NMAForge.
        return static_cast<int8_t>(((k * 5 + 1) % 19) - 9);
    if (workload == 2)  // Same M=8, K=19 product-GEMV fixture as NMAForge.
        return static_cast<int8_t>(((row * 7 + k * 5 + 1) % 23) - 11);
    return static_cast<int8_t>(((row * 3 + k * 2 + 1) % 9) - 4);
}

static int8_t operand_b(int k, int col, int workload) {
    if (workload == 3) return shared_b[k * 16 + col];
    if (workload == 1 || workload == 2)
        return static_cast<int8_t>(((k * 3 - col * 2 + 5) % 17) - 8);
    // Preserve SystemVerilog signed remainder semantics for negative values.
    return static_cast<int8_t>(((k * 2 - col * 3 + 5) % 9) - 4);
}

static void clear_words() {
    for (int i = 0; i < 4; ++i) {
        dut.sa_a_col_flat[i] = 0;
        dut.sa_b_row_flat[i] = 0;
    }
}

static bool run_gemm(int m, int n, int k, int workload = 0) {
    constexpr int TILE = 16;
    std::vector<int32_t> golden(m * n, 0);
    std::vector<int32_t> actual(m * n, 0);

    for (int row = 0; row < m; ++row)
        for (int col = 0; col < n; ++col)
            for (int kk = 0; kk < k; ++kk)
                golden[row * n + col] +=
                    static_cast<int32_t>(operand_a(row, kk, workload)) *
                    static_cast<int32_t>(operand_b(kk, col, workload));

    const uint64_t inclusive_start = cycles;
    uint64_t clear_cycles = 0, feed_cycles = 0, drain_cycles = 0;
    uint64_t start_cycle = 0;
    for (int tile_row = 0; tile_row < m; tile_row += TILE) {
        for (int tile_col = 0; tile_col < n; tile_col += TILE) {
            // One accumulator clear per output tile; K tiles accumulate into
            // the same 16x16 array before its values are read back.
            clear_cycles += 2;
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
                feed_cycles += 3 * TILE;
                for (int c = 0; c < 3 * TILE; ++c) {
                    uint32_t a_flat[4] = {0, 0, 0, 0};
                    uint32_t b_flat[4] = {0, 0, 0, 0};
                    for (int row = 0; row < TILE; ++row) {
                        const int local_k = c - row;
                        if (local_k >= 0 && local_k < TILE &&
                            tile_row + row < m && k_base + local_k < k) {
                            const uint32_t byte = static_cast<uint8_t>(
                                operand_a(tile_row + row, k_base + local_k, workload));
                            a_flat[row / 4] |= byte << ((row % 4) * 8);
                        }
                    }
                    for (int col = 0; col < TILE; ++col) {
                        const int local_k = c - col;
                        if (local_k >= 0 && local_k < TILE &&
                            tile_col + col < n && k_base + local_k < k) {
                            const uint32_t byte = static_cast<uint8_t>(
                                operand_b(k_base + local_k, tile_col + col, workload));
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
            drain_cycles += 4;
            for (int i = 0; i < 4; ++i) tick();
            for (int row = 0; row < TILE; ++row) {
                for (int col = 0; col < TILE; ++col) {
                    dut.sa_acc_rd_row = row;
                    dut.sa_acc_rd_col = col;
                    dut.eval();
                    if (tile_row + row < m && tile_col + col < n)
                        actual[(tile_row + row) * n + tile_col + col] =
                            static_cast<int32_t>(dut.sa_acc_rd_data);
                }
            }
        }
    }

    const uint64_t elapsed = cycles - start_cycle;
    const uint64_t inclusive_cycles = cycles - inclusive_start;
    if (inclusive_cycles != clear_cycles + feed_cycles + drain_cycles)
        return false;
    // Host input access and combinational accumulator inspection have no
    // modeled transfer/commit clocks. Report them as unmeasured, never zero.
    std::printf("TINYNPU_ARRAY_PHASES shape_mnk=%d,%d,%d clear=%llu feed_wavefront=%llu drain=%llu inclusive=%llu transfer=NA dispatch=NA writeback=NA boundary=array_only\n",
        m,n,k,static_cast<unsigned long long>(clear_cycles),
        static_cast<unsigned long long>(feed_cycles),
        static_cast<unsigned long long>(drain_cycles),
        static_cast<unsigned long long>(inclusive_cycles));
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
    if (workload == 3) {
        const char *path = std::getenv("SHARED_OUTPUT");
        if (!path) return false;
        std::ofstream stream(path);
        if (!stream) return false;
        for (auto word : actual) {
            char buf[16]; std::snprintf(buf, sizeof(buf), "%08x", static_cast<uint32_t>(word));
            stream << buf << "\n";
        }
    }
    const char *marker = workload == 3 ? "TINYNPU_TRAINED_QKV_PASS" :
                         workload == 0 ? "TINYNPU_MATCHED_GEMM_PASS" :
                         "TINYNPU_MATCHED_GEMV_PASS";
    std::printf(
        "%s shape_mnk=%d,%d,%d physical_array=16x16 workload=%s "
        "cycles_input_to_array_stable=%llu macs=%d mac_per_cycle=%.4f "
        "pe_utilization_pct=%.2f golden=%d/%d\n",
        marker, m, n, k, workload == 3 ? "trained_h16_projection" :
        workload == 0 ? "gemm" : "product_gemv_padded_array",
        static_cast<unsigned long long>(elapsed), useful_macs,
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

    if (const char *path = std::getenv("SHARED_OPERANDS")) {
        std::ifstream stream(path);
        unsigned value;
        if (!stream) return EXIT_FAILURE;
        for (int i=0; i<320; ++i) {
            if (!(stream >> std::hex >> value) || value>255) return EXIT_FAILURE;
            if (i<64) shared_a.push_back(static_cast<int8_t>(value));
            else shared_b.push_back(static_cast<int8_t>(value));
        }
        return run_gemm(4,16,16,3) ? EXIT_SUCCESS : EXIT_FAILURE;
    }
    if (!run_gemm(16, 16, 16) ||
        !run_gemm(16, 16, 32) ||
        !run_gemm(32, 32, 64))
        return EXIT_FAILURE;
    if (!run_gemm(1, 13, 17, 1) ||
        !run_gemm(8, 16, 19, 2) ||
        !run_gemm(16, 16, 19, 2) ||
        !run_gemm(16, 16, 65, 2))
        return EXIT_FAILURE;
    return EXIT_SUCCESS;
}
