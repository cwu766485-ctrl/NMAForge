#include "cimforge_regs.h"
#include "xil_cache.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xscugic.h"
#include "xstatus.h"

#define TIMEOUT_POLLS 10000000u
#define SPAD_A        0x0000u
#define SPAD_B        0x0040u
#define SPAD_OUT      0x0080u
#define SPAD_CPL      0x2000u
#define SPAD_MATRIX_A 0x4000u
#define SPAD_MATRIX_B 0x4100u
#define SPAD_MATRIX_C 0x4200u
#define SPAD_DMA_BENCH 0x6000u
#define DMA_BENCH_WORDS 256u

static uint32_t ext_a[1] __attribute__((aligned(64))) = {0x04030201u};
static uint32_t ext_b[1] __attribute__((aligned(64))) = {0x08070605u};
static uint32_t ext_out[1] __attribute__((aligned(64)));
static uint32_t ext_dma_src[DMA_BENCH_WORDS] __attribute__((aligned(64)));
static uint32_t ext_dma_dst[DMA_BENCH_WORDS] __attribute__((aligned(64)));
static cimforge_desc_v2_t desc_ring[2] __attribute__((aligned(64)));
static XScuGic gic;
static volatile uint32_t irq_seen;
volatile uint32_t cimforge_validation_result = 0xffffffffu;

static int finish_validation(int result)
{
    cimforge_validation_result = (uint32_t)result;
    Xil_DCacheFlushRange((INTPTR)&cimforge_validation_result,
                         sizeof(cimforge_validation_result));
    return result;
}

static void accel_irq_handler(void *reference)
{
    (void)reference;
    if (cimforge_read(CIMFORGE_REG_IRQ_STATUS) & 1u) {
        irq_seen = 1u;
        cimforge_write(CIMFORGE_REG_IRQ_STATUS, 1u);
    }
}

static int setup_accel_irq(void)
{
    XScuGic_Config *config;

    config = XScuGic_LookupConfig(XPAR_SCUGIC_0_DEVICE_ID);
    if (config == NULL)
        return -1;
    if (XScuGic_CfgInitialize(&gic, config, config->CpuBaseAddress) != XST_SUCCESS)
        return -2;
    if (XScuGic_Connect(&gic, XPAR_FABRIC_ACCEL_0_IRQ_INTR,
                        (Xil_InterruptHandler)accel_irq_handler,
                        NULL) != XST_SUCCESS)
        return -3;

    /* The accelerator IRQ remains asserted until IRQ_STATUS is cleared. */
    XScuGic_SetPriorityTriggerType(&gic, XPAR_FABRIC_ACCEL_0_IRQ_INTR,
                                   0xa0u, 0x1u);
    XScuGic_Enable(&gic, XPAR_FABRIC_ACCEL_0_IRQ_INTR);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 &gic);
    Xil_ExceptionEnable();
    return 0;
}

static int wait_bits(uint32_t reg, uint32_t mask, uint32_t expected)
{
    uint32_t polls;
    for (polls = 0; polls < TIMEOUT_POLLS; ++polls) {
        if ((cimforge_read(reg) & mask) == expected)
            return 0;
    }
    return -1;
}

static int dma_transfer(uint32_t ext, uint32_t spad, uint16_t words, int store)
{
    cimforge_write(CIMFORGE_REG_DMA_STATUS, CIMFORGE_DMA_DONE | CIMFORGE_DMA_ERROR);
    cimforge_write(CIMFORGE_REG_DMA_EXT, ext);
    cimforge_write(CIMFORGE_REG_DMA_SPAD, spad);
    cimforge_write(CIMFORGE_REG_DMA_LEN, words);
    cimforge_write(CIMFORGE_REG_DMA_ROW_COUNT, 0);
    cimforge_write(CIMFORGE_REG_DMA_CTRL,
                   CIMFORGE_DMA_START | (store ? CIMFORGE_DMA_STORE : 0));
    if (wait_bits(CIMFORGE_REG_DMA_STATUS, CIMFORGE_DMA_DONE,
                  CIMFORGE_DMA_DONE) != 0)
        return -1;
    if (cimforge_read(CIMFORGE_REG_DMA_STATUS) & CIMFORGE_DMA_ERROR)
        return -(int)(16u + cimforge_read(CIMFORGE_REG_DMA_ERROR));
    return 0;
}

static void report_a5_perf(const char *tag)
{
    uint32_t matrix_cycles = cimforge_read(CIMFORGE_REG_PERF_MATRIX_CYCLES);
    uint32_t matrix_mac = cimforge_read(CIMFORGE_REG_PERF_MATRIX_MAC_CYCLES);
    uint32_t matrix_wait = cimforge_read(CIMFORGE_REG_PERF_MATRIX_BANKED_STALL);
    uint32_t dma_read = cimforge_read(CIMFORGE_REG_PERF_DMA_READ_BYTES);
    uint32_t dma_write = cimforge_read(CIMFORGE_REG_PERF_DMA_WRITE_BYTES);
    uint32_t dma_ar = cimforge_read(CIMFORGE_REG_PERF_DMA_AR_COUNT);
    uint32_t dma_aw = cimforge_read(CIMFORGE_REG_PERF_DMA_AW_COUNT);
    uint32_t dma_rd_state = cimforge_read(CIMFORGE_REG_PERF_DMA_RD_STATE);
    uint32_t dma_r_stall = cimforge_read(CIMFORGE_REG_PERF_DMA_R_STALL);

    xil_printf("A5 PERF %s: matrix cycles=%lu mac=%lu bank_wait=%lu\\r\\n",
               tag, (unsigned long)matrix_cycles, (unsigned long)matrix_mac,
               (unsigned long)matrix_wait);
    xil_printf("A5 PERF %s: dma rdB=%lu wrB=%lu AR=%lu AW=%lu rd_state=%08lx r_stall=%lu\\r\\n",
               tag, (unsigned long)dma_read, (unsigned long)dma_write,
               (unsigned long)dma_ar, (unsigned long)dma_aw,
               (unsigned long)dma_rd_state, (unsigned long)dma_r_stall);
}

static int run_dma_perf_bench(void)
{
    uint32_t i;
    int rc;

    for (i = 0; i < DMA_BENCH_WORDS; ++i) {
        ext_dma_src[i] = 0xa5000000u ^ (i * 0x01010101u);
        ext_dma_dst[i] = 0u;
    }
    Xil_DCacheFlushRange((INTPTR)ext_dma_src, sizeof(ext_dma_src));
    Xil_DCacheFlushRange((INTPTR)ext_dma_dst, sizeof(ext_dma_dst));
    cimforge_write(CIMFORGE_REG_DMA_CFG,
                   CIMFORGE_DMA_CFG_RD_OUTSTANDING(4));
    cimforge_write(CIMFORGE_REG_PERF_CTRL, CIMFORGE_PERF_CLEAR);

    rc = dma_transfer((uint32_t)(uintptr_t)ext_dma_src, SPAD_DMA_BENCH,
                      DMA_BENCH_WORDS, 0);
    if (rc == 0)
        rc = dma_transfer((uint32_t)(uintptr_t)ext_dma_dst, SPAD_DMA_BENCH,
                          DMA_BENCH_WORDS, 1);
    Xil_DCacheInvalidateRange((INTPTR)ext_dma_dst, sizeof(ext_dma_dst));
    if (rc != 0 || ext_dma_dst[0] != ext_dma_src[0] ||
        ext_dma_dst[DMA_BENCH_WORDS - 1u] != ext_dma_src[DMA_BENCH_WORDS - 1u])
        return -1;
    if (cimforge_read(CIMFORGE_REG_PERF_DMA_READ_BYTES) !=
            (DMA_BENCH_WORDS * sizeof(uint32_t)) ||
        cimforge_read(CIMFORGE_REG_PERF_DMA_WRITE_BYTES) !=
            (DMA_BENCH_WORDS * sizeof(uint32_t)))
        return -2;
    report_a5_perf("dma256");
    return 0;
}

static int run_tensor_matrix_perf_bench(void)
{
    static const uint32_t a_tile[8] = {
        0x04030201u, 0x08070605u, 0x0c0b0a09u, 0x100f0e0du,
        0u, 0u, 0u, 0u
    };
    static const uint32_t b_tile[8] = {
        0x00000001u, 0x00000100u, 0x00010000u, 0x01000000u,
        0u, 0u, 0u, 0u
    };
    uint32_t i;

    for (i = 0; i < 8u; ++i) {
        cimforge_spad_write(SPAD_MATRIX_A + i * sizeof(uint32_t), a_tile[i]);
        cimforge_spad_write(SPAD_MATRIX_B + i * sizeof(uint32_t), b_tile[i]);
    }
    cimforge_write(CIMFORGE_REG_POST_CTRL, 0u);
    cimforge_write(CIMFORGE_REG_QUANT, 0u);
    cimforge_write(CIMFORGE_REG_PERF_CTRL, CIMFORGE_PERF_CLEAR);
    cimforge_write(CIMFORGE_REG_OP, CIMFORGE_OP_TENSOR_GEMM);
    cimforge_write(CIMFORGE_REG_SRC0, SPAD_MATRIX_A);
    cimforge_write(CIMFORGE_REG_SRC1, SPAD_MATRIX_B);
    cimforge_write(CIMFORGE_REG_DST, SPAD_MATRIX_C);
    cimforge_write(CIMFORGE_REG_M, 4u);
    cimforge_write(CIMFORGE_REG_N, 4u);
    cimforge_write(CIMFORGE_REG_K, 2u); /* K=8 INT8 elements; forces prefetch. */
    irq_seen = 0u;
    cimforge_write(CIMFORGE_REG_CTRL, 3u);
    if (wait_bits(CIMFORGE_REG_STATUS, CIMFORGE_STATUS_DONE,
                  CIMFORGE_STATUS_DONE) != 0)
        return -1;
    if ((cimforge_read(CIMFORGE_REG_STATUS) & CIMFORGE_STATUS_ERROR) ||
        cimforge_spad_read(SPAD_MATRIX_C + 0u) != 1u ||
        cimforge_spad_read(SPAD_MATRIX_C + 12u) != 4u ||
        cimforge_spad_read(SPAD_MATRIX_C + 16u) != 5u ||
        cimforge_spad_read(SPAD_MATRIX_C + 60u) != 16u)
        return -2;
    if (cimforge_read(CIMFORGE_REG_PERF_MATRIX_CYCLES) == 0u ||
        cimforge_read(CIMFORGE_REG_PERF_MATRIX_MAC_CYCLES) == 0u)
        return -3;
    report_a5_perf("gemm4x4x8");
    cimforge_write(CIMFORGE_REG_IRQ_STATUS, 1u);
    return 0;
}

int main(void)
{
    cimforge_completion_t cpl;
    uintptr_t desc_addr = (uintptr_t)&desc_ring[0];
    uintptr_t out_addr = (uintptr_t)&ext_out[0];
    uintptr_t a_addr = (uintptr_t)&ext_a[0];
    uintptr_t b_addr = (uintptr_t)&ext_b[0];
    uintptr_t dma_src_addr = (uintptr_t)&ext_dma_src[0];
    uintptr_t dma_dst_addr = (uintptr_t)&ext_dma_dst[0];
    uint32_t desc_phys;
    uint32_t out_phys;
    int rc;

    xil_printf("CIMForge XCZU15EG bring-up\r\n");
    if (cimforge_read(CIMFORGE_REG_VERSION) != CIMFORGE_VERSION_512K) {
        xil_printf("FAIL: VERSION=%08lx\r\n",
                   (unsigned long)cimforge_read(CIMFORGE_REG_VERSION));
        return finish_validation(1);
    }
    if (cimforge_read(CIMFORGE_REG_SPAD_INFO) != CIMFORGE_SPAD_BYTES_DEFAULT) {
        xil_printf("FAIL: SPAD_INFO=%08lx\r\n",
                   (unsigned long)cimforge_read(CIMFORGE_REG_SPAD_INFO));
        return finish_validation(8);
    }
    rc = setup_accel_irq();
    if (rc != 0) {
        xil_printf("FAIL: GIC setup rc=%d\r\n", rc);
        return finish_validation(9);
    }

    if ((desc_addr >> 32) || (out_addr >> 32) ||
        (a_addr >> 32) || (b_addr >> 32) ||
        (dma_src_addr >> 32) || (dma_dst_addr >> 32)) {
        xil_printf("FAIL: A2 DMA/descriptor buffers must be below 4 GiB\r\n");
        return finish_validation(7);
    }
    desc_phys = (uint32_t)desc_addr;
    out_phys = (uint32_t)out_addr;

    Xil_DCacheFlushRange((INTPTR)ext_a, sizeof(ext_a));
    Xil_DCacheFlushRange((INTPTR)ext_b, sizeof(ext_b));
    rc = dma_transfer((uint32_t)a_addr, SPAD_A, 1, 0);
    if (rc == 0)
        rc = dma_transfer((uint32_t)b_addr, SPAD_B, 1, 0);
    if (rc != 0) {
        xil_printf("FAIL: DMA load rc=%d status=%08lx error=%08lx\r\n", rc,
                   (unsigned long)cimforge_read(CIMFORGE_REG_DMA_STATUS),
                   (unsigned long)cimforge_read(CIMFORGE_REG_DMA_ERROR));
        return finish_validation(2);
    }

    cimforge_desc_init(&desc_ring[0], CIMFORGE_OP_VDOT_INT8, 0x1234u,
                       SPAD_A, SPAD_B, 0, SPAD_OUT, 1, 1, 1,
                       0, CIMFORGE_ACT_NONE, 0);
    Xil_DCacheFlushRange((INTPTR)desc_ring, sizeof(desc_ring));

    cimforge_write(CIMFORGE_REG_CMD_BASE, desc_phys);
    cimforge_write(CIMFORGE_REG_CMD_HI, 0);
    cimforge_write(CIMFORGE_REG_CMD_SIZE, 2);
    cimforge_write(CIMFORGE_REG_CMD_HEAD, 0);
    cimforge_write(CIMFORGE_REG_CMD_TAIL, 1);
    cimforge_write(CIMFORGE_REG_CMD_CTRL, 1); /* descriptor in PS DDR */
    cimforge_write(CIMFORGE_REG_CPL_BASE, SPAD_CPL);
    cimforge_write(CIMFORGE_REG_CPL_SIZE, 2);
    cimforge_write(CIMFORGE_REG_CPL_TAIL, 0);
    cimforge_write(CIMFORGE_REG_CPL_HEAD, 0);
    cimforge_write(CIMFORGE_REG_WATCHDOG, 1000000u);
    irq_seen = 0u;
    cimforge_write(CIMFORGE_REG_IRQ_STATUS, 1u);
    cimforge_write(CIMFORGE_REG_IRQ_ENABLE, 1u);
    cimforge_write(CIMFORGE_REG_DOORBELL, 1);

    if (wait_bits(CIMFORGE_REG_STATUS, CIMFORGE_STATUS_DONE,
                  CIMFORGE_STATUS_DONE) != 0) {
        cimforge_write(CIMFORGE_REG_ABORT, 1);
        xil_printf("FAIL: command timeout status=%08lx\r\n",
                   (unsigned long)cimforge_read(CIMFORGE_REG_STATUS));
        return finish_validation(3);
    }
    if (irq_seen == 0u || (cimforge_read(CIMFORGE_REG_IRQ_STATUS) & 1u)) {
        xil_printf("FAIL: PL-to-PS IRQ seen=%lu sticky=%08lx\r\n",
                   (unsigned long)irq_seen,
                   (unsigned long)cimforge_read(CIMFORGE_REG_IRQ_STATUS));
        return finish_validation(10);
    }
    if ((cimforge_read(CIMFORGE_REG_STATUS) & CIMFORGE_STATUS_ERROR) ||
        cimforge_spad_read(SPAD_OUT) != 70u) {
        xil_printf("FAIL: compute status=%08lx error=%08lx out=%08lx\r\n",
                   (unsigned long)cimforge_read(CIMFORGE_REG_STATUS),
                   (unsigned long)cimforge_read(CIMFORGE_REG_ERROR),
                   (unsigned long)cimforge_spad_read(SPAD_OUT));
        return finish_validation(4);
    }

    cpl.task_id = cimforge_spad_read(SPAD_CPL + 0);
    cpl.status_error = cimforge_spad_read(SPAD_CPL + 4);
    cpl.result = cimforge_spad_read(SPAD_CPL + 8);
    cpl.element_count = cimforge_spad_read(SPAD_CPL + 12);
    if (cpl.task_id != 0x1234u || cpl.status_error != 1u ||
        cpl.result != 70u || cpl.element_count != 1u) {
        xil_printf("FAIL: completion %08lx %08lx %08lx %08lx\r\n",
                   (unsigned long)cpl.task_id, (unsigned long)cpl.status_error,
                   (unsigned long)cpl.result, (unsigned long)cpl.element_count);
        return finish_validation(5);
    }

    ext_out[0] = 0;
    Xil_DCacheFlushRange((INTPTR)ext_out, sizeof(ext_out));
    rc = dma_transfer(out_phys, SPAD_OUT, 1, 1);
    Xil_DCacheInvalidateRange((INTPTR)ext_out, sizeof(ext_out));
    if (rc != 0 || ext_out[0] != 70u) {
        xil_printf("FAIL: DMA store rc=%d out=%08lx\r\n", rc,
                   (unsigned long)ext_out[0]);
        return finish_validation(6);
    }

    rc = run_dma_perf_bench();
    if (rc != 0) {
        xil_printf("FAIL: A5 DMA benchmark rc=%d\\r\\n", rc);
        return finish_validation(11);
    }
    rc = run_tensor_matrix_perf_bench();
    if (rc != 0) {
        xil_printf("FAIL: A5 tensor matrix benchmark rc=%d\\r\\n", rc);
        return finish_validation(12);
    }

    xil_printf("PASS: version/DDR DMA/CMDQ/VDOT/completion/IRQ/A5 performance all verified\r\n");
    return finish_validation(0);
}
