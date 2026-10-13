#ifndef CIMFORGE_REGS_H
#define CIMFORGE_REGS_H

#include <stdint.h>

/*
 * Public product name is NMAForge.  Keep the historical CIMForge spelling as
 * an ABI-compatible alias: register offsets, descriptor layout, and the
 * 0xA0000000 mapping do not change when software is migrated incrementally.
 */
#ifndef NMAFORGE_BASE_ADDR
#define NMAFORGE_BASE_ADDR 0xA0000000u
#endif
#ifndef NMA_BASE_ADDR
#define NMA_BASE_ADDR NMAFORGE_BASE_ADDR
#endif
#ifndef CIMFORGE_BASE_ADDR
#define CIMFORGE_BASE_ADDR NMAFORGE_BASE_ADDR
#endif

#define CIMFORGE_SPAD_WINDOW       0x00010000u
#define CIMFORGE_SPAD_BYTES_DEFAULT 0x00080000u
#define CIMFORGE_VERSION_A4        0x10000004u
#define CIMFORGE_VERSION_A5        0x10000005u
#define CIMFORGE_VERSION_A6        0x10000006u
#define CIMFORGE_VERSION_A7        0x10000007u
#define CIMFORGE_VERSION_A8        0x10000008u
#define CIMFORGE_VERSION_A9        0x10000009u
#define CIMFORGE_VERSION_A10       0x1000000au
#define CIMFORGE_VERSION_512K      CIMFORGE_VERSION_A10

#define CIMFORGE_OP_BF16_DOT_ACC_FP32 0x50u
#define CIMFORGE_OP_FP16_DOT_ACC_FP32 0x51u

#define CIMFORGE_REG_CTRL          0x000u
#define CIMFORGE_REG_STATUS        0x004u
#define CIMFORGE_REG_OP            0x008u
#define CIMFORGE_REG_SRC0          0x00cu
#define CIMFORGE_REG_SRC1          0x010u
#define CIMFORGE_REG_DST           0x014u
#define CIMFORGE_REG_LENGTH        0x018u
#define CIMFORGE_REG_M             0x01cu
#define CIMFORGE_REG_N             0x020u
#define CIMFORGE_REG_K             0x024u
#define CIMFORGE_REG_QUANT         0x028u
#define CIMFORGE_REG_RESULT        0x02cu
#define CIMFORGE_REG_ERROR         0x030u
#define CIMFORGE_REG_CYCLES        0x034u
#define CIMFORGE_REG_ELEMENTS      0x038u
#define CIMFORGE_REG_IRQ_STATUS    0x03cu
#define CIMFORGE_REG_IRQ_ENABLE    0x040u
#define CIMFORGE_REG_VERSION       0x044u
#define CIMFORGE_REG_CAP           0x048u
#define CIMFORGE_REG_CMD_BASE      0x080u
#define CIMFORGE_REG_CMD_HI        0x084u
#define CIMFORGE_REG_CMD_SIZE      0x088u
#define CIMFORGE_REG_CMD_HEAD      0x08cu
#define CIMFORGE_REG_CPL_BASE      0x090u
#define CIMFORGE_REG_CPL_HI        0x094u
#define CIMFORGE_REG_CPL_SIZE      0x098u
#define CIMFORGE_REG_CPL_TAIL      0x09cu
#define CIMFORGE_REG_DOORBELL      0x0a0u
#define CIMFORGE_REG_ABORT         0x0a4u
#define CIMFORGE_REG_WATCHDOG      0x0a8u
#define CIMFORGE_REG_CMD_CTRL      0x0acu
#define CIMFORGE_REG_DMA_CTRL      0x0b0u
#define CIMFORGE_REG_DMA_STATUS    0x0b4u
#define CIMFORGE_REG_DMA_EXT       0x0b8u
#define CIMFORGE_REG_DMA_SPAD      0x0bcu
#define CIMFORGE_REG_DMA_LEN       0x0c0u
#define CIMFORGE_REG_DMA_ERROR     0x0c4u
#define CIMFORGE_REG_CMD_TAIL      0x0c8u
#define CIMFORGE_REG_CPL_HEAD      0x0ccu
#define CIMFORGE_REG_QUEUE_STATUS  0x0d0u
#define CIMFORGE_REG_DMA_ROW_WORDS 0x104u
#define CIMFORGE_REG_DMA_ROW_COUNT 0x108u
#define CIMFORGE_REG_DMA_EXT_STRIDE 0x10cu
#define CIMFORGE_REG_DMA_SPAD_STRIDE 0x110u
#define CIMFORGE_REG_BIAS_BASE     0x114u
#define CIMFORGE_REG_POST_CTRL     0x118u
#define CIMFORGE_REG_TILE_CTRL     0x120u
#define CIMFORGE_REG_TILE_COUNT    0x124u
#define CIMFORGE_REG_TILE_EXT_IN   0x128u
#define CIMFORGE_REG_TILE_EXT_OUT  0x12cu
#define CIMFORGE_REG_TILE_EXT_IN_STRIDE 0x130u
#define CIMFORGE_REG_TILE_EXT_OUT_STRIDE 0x134u
#define CIMFORGE_REG_TILE_BUF0     0x138u
#define CIMFORGE_REG_TILE_BUF1     0x13cu
#define CIMFORGE_REG_TILE_IN_WORDS 0x140u
#define CIMFORGE_REG_TILE_OUT_WORDS 0x144u
#define CIMFORGE_REG_TILE_OUT_OFFSET 0x148u
#define CIMFORGE_REG_SPAD_INFO     0x164u
#define CIMFORGE_REG_EVENT_STATUS  0x168u
#define CIMFORGE_REG_DMA_CFG       0x16cu
#define CIMFORGE_REG_DMA_GATHER_INDEX 0x170u
#define CIMFORGE_REG_PERF_CTRL     0x174u
#define CIMFORGE_REG_PERF_MATRIX_CYCLES 0x178u
#define CIMFORGE_REG_PERF_MATRIX_MAC_CYCLES 0x17cu
#define CIMFORGE_REG_PERF_MATRIX_BANKED_STALL 0x180u
#define CIMFORGE_REG_PERF_DMA_READ_BYTES 0x184u
#define CIMFORGE_REG_PERF_DMA_WRITE_BYTES 0x188u
#define CIMFORGE_REG_PERF_DMA_AR_COUNT 0x18cu
#define CIMFORGE_REG_PERF_DMA_AW_COUNT 0x190u
#define CIMFORGE_REG_PERF_DMA_RD_STATE 0x194u
#define CIMFORGE_REG_PERF_DMA_R_STALL 0x198u
#define CIMFORGE_REG_DMA_EXT_HI     0x19cu
#define CIMFORGE_REG_ABI_INFO       0x1a0u
#define CIMFORGE_REG_ERROR_INFO     0x1a4u
#define CIMFORGE_REG_CAP2           0x1a8u
#define CIMFORGE_REG_TILE_EXT_IN_HI 0x1acu
#define CIMFORGE_REG_TILE_EXT_OUT_HI 0x1b0u

#define CIMFORGE_ABI_MAJOR          7u
#define CIMFORGE_ABI_MINOR          4u
#define CIMFORGE_DESC_BYTES         64u
#define CIMFORGE_COMPLETION_BYTES   16u

#define CIMFORGE_CAP2_UNIFIED_DMA   (1u << 0)
#define CIMFORGE_CAP2_SPAD_LINE128  (1u << 1)
#define CIMFORGE_CAP2_MATRIX_LINE_STORE (1u << 2)
#define CIMFORGE_CAP2_ADDR64        (1u << 3)
#define CIMFORGE_CAP2_DESC_V7       (1u << 4)
#define CIMFORGE_CAP2_PACK_I8       (1u << 5)
#define CIMFORGE_CAP2_BF16_DOT_ACC_FP32 (1u << 6)
#define CIMFORGE_CAP2_FP16_DOT_ACC_FP32 (1u << 7)

#define CIMFORGE_ERROR_SOURCE_NONE  0u
#define CIMFORGE_ERROR_SOURCE_COMMAND 1u
#define CIMFORGE_ERROR_SOURCE_DMA   2u

#define CIMFORGE_CAP_TENSOR_MATRIX (1u << 12)
#define CIMFORGE_CAP_TENSOR_SFU    (1u << 13)
#define CIMFORGE_CAP_DESC_V3       (1u << 14)
#define CIMFORGE_CAP_DMA_BURST64   (1u << 15)
#define CIMFORGE_CAP_LAYERNORM     (1u << 16)
#define CIMFORGE_CAP_MACRO_V4      (1u << 17)
#define CIMFORGE_CAP_DMA_GATHER    (1u << 18)
#define CIMFORGE_CAP_DMA_RD_OUTSTANDING (1u << 19)
#define CIMFORGE_CAP_A5_PERF_MONITOR (1u << 20)

#define CIMFORGE_STATUS_BUSY       (1u << 0)
#define CIMFORGE_STATUS_DONE       (1u << 1)
#define CIMFORGE_STATUS_ERROR      (1u << 2)
#define CIMFORGE_DMA_START         (1u << 0)
#define CIMFORGE_DMA_STORE         (1u << 1)
#define CIMFORGE_DMA_BUSY          (1u << 0)
#define CIMFORGE_DMA_DONE          (1u << 1)
#define CIMFORGE_DMA_ERROR         (1u << 2)
#define CIMFORGE_DMA_CFG_GATHER    (1u << 0)
#define CIMFORGE_DMA_CFG_UNIFIED128 (1u << 1) /* read-only capability */
#define CIMFORGE_DMA_CFG_WIDE128    CIMFORGE_DMA_CFG_UNIFIED128
#define CIMFORGE_DMA_CFG_RD_OUTSTANDING(n) (((uint32_t)(n) & 7u) << 8)
#define CIMFORGE_PERF_CLEAR         (1u << 0)

#define CIMFORGE_OP_VDOT_INT8      0x10u
#define CIMFORGE_OP_GEMV_INT8      0x11u
#define CIMFORGE_OP_GEMM_INT8      0x12u
#define CIMFORGE_OP_CONV1X1_INT8   0x13u
#define CIMFORGE_OP_CONV3X3_INT8   0x14u
#define CIMFORGE_OP_DWCONV3X3_INT8 0x15u
#define CIMFORGE_OP_CONV3X3_LINEBUF 0x16u
#define CIMFORGE_OP_DWCONV3X3_LINEBUF 0x17u
#define CIMFORGE_OP_BANKED_VDOT    0x20u
#define CIMFORGE_OP_BANKED_GEMV    0x21u
#define CIMFORGE_OP_TENSOR_GEMM    0x30u
#define CIMFORGE_OP_BATCH_GEMM     0x31u
#define CIMFORGE_OP_SOFTMAX_Q15    0x32u
#define CIMFORGE_OP_RMSNORM_Q15    0x33u
#define CIMFORGE_OP_RESIDUAL_I32   0x34u
#define CIMFORGE_OP_GELU_Q8_8      0x35u
#define CIMFORGE_OP_REQUANT_I8     0x36u
#define CIMFORGE_OP_SILU_Q8_8      0x37u
#define CIMFORGE_OP_LAYERNORM_Q15  0x38u
#define CIMFORGE_OP_CAUSAL_SOFTMAX_Q15 0x39u
#define CIMFORGE_OP_QKV_PROJ       0x40u
#define CIMFORGE_OP_MHA            0x41u
#define CIMFORGE_OP_FFN            0x42u
#define CIMFORGE_OP_KV_WRITE       0x43u
#define CIMFORGE_OP_KV_READ        0x44u

#define CIMFORGE_DESC_V3_VERSION   3u
#define CIMFORGE_DESC_F_BIAS       (1u << 0)
#define CIMFORGE_DESC_F_TRANSPOSE_A (1u << 1)
#define CIMFORGE_DESC_F_TRANSPOSE_B (1u << 2)
#define CIMFORGE_DESC_F_MACRO_EXTERNAL (1u << 3)
#define CIMFORGE_DESC_F_PACK_I8     (1u << 4)
#define CIMFORGE_DESC_V4_VERSION   4u
#define CIMFORGE_DESC_V5_VERSION   5u
#define CIMFORGE_DESC_V7_VERSION   7u

#define CIMFORGE_ACT_NONE          0u
#define CIMFORGE_ACT_RELU          1u
#define CIMFORGE_ACT_RELU6         2u

typedef struct __attribute__((aligned(64))) {
    uint32_t word[16];
} cimforge_desc_v2_t;

typedef struct __attribute__((aligned(64))) {
    uint32_t word[16];
} cimforge_desc_v3_t;

typedef struct __attribute__((aligned(64))) {
    uint32_t word[16];
} cimforge_desc_v4_t;

typedef struct __attribute__((aligned(64))) {
    uint32_t word[16];
} cimforge_desc_v7_t;

typedef struct {
    uint32_t task_id;
    uint32_t status_error;
    uint32_t result;
    uint32_t element_count;
} cimforge_completion_t;

static inline void cimforge_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(CIMFORGE_BASE_ADDR + offset) = value;
    __asm__ volatile("dmb sy" ::: "memory");
}

static inline uint32_t cimforge_read(uint32_t offset)
{
    uint32_t value = *(volatile uint32_t *)(uintptr_t)(CIMFORGE_BASE_ADDR + offset);
    __asm__ volatile("dmb sy" ::: "memory");
    return value;
}

static inline void cimforge_spad_write(uint32_t byte_addr, uint32_t value)
{
    cimforge_write(CIMFORGE_SPAD_WINDOW + byte_addr, value);
}

static inline uint32_t cimforge_spad_read(uint32_t byte_addr)
{
    return cimforge_read(CIMFORGE_SPAD_WINDOW + byte_addr);
}

static inline void cimforge_set_cmdq_external_base(uint64_t address)
{
    cimforge_write(CIMFORGE_REG_CMD_BASE, (uint32_t)address);
    cimforge_write(CIMFORGE_REG_CMD_HI, (uint32_t)(address >> 32));
}

static inline void cimforge_set_dma_external_address(uint64_t address)
{
    cimforge_write(CIMFORGE_REG_DMA_EXT, (uint32_t)address);
    cimforge_write(CIMFORGE_REG_DMA_EXT_HI, (uint32_t)(address >> 32));
}

static inline void cimforge_set_tile_external_addresses(uint64_t input,
                                                         uint64_t output)
{
    cimforge_write(CIMFORGE_REG_TILE_EXT_IN, (uint32_t)input);
    cimforge_write(CIMFORGE_REG_TILE_EXT_IN_HI, (uint32_t)(input >> 32));
    cimforge_write(CIMFORGE_REG_TILE_EXT_OUT, (uint32_t)output);
    cimforge_write(CIMFORGE_REG_TILE_EXT_OUT_HI, (uint32_t)(output >> 32));
}

static inline void cimforge_desc_init(cimforge_desc_v2_t *desc, uint8_t op,
                                      uint16_t task_id, uint32_t src0,
                                      uint32_t src1, uint32_t bias,
                                      uint32_t dst, uint16_t m, uint16_t n,
                                      uint16_t k_words, uint8_t shift,
                                      uint8_t activation, int bias_enable)
{
    unsigned i;
    for (i = 0; i < 16; ++i)
        desc->word[i] = 0;
    desc->word[0] = ((uint32_t)task_id << 16) | op;
    desc->word[1] = src0;
    desc->word[2] = src1;
    desc->word[3] = bias;
    desc->word[4] = dst;
    desc->word[5] = ((uint32_t)n << 16) | m;
    desc->word[6] = k_words;
    desc->word[7] = bias_enable ? 1u : 0u;
    desc->word[9] = ((uint32_t)(activation & 3u) << 5) | (shift & 31u);
}

static inline void cimforge_desc_v3_init(
    cimforge_desc_v3_t *desc, uint8_t op, uint16_t task_id,
    uint32_t src0, uint32_t src1, uint32_t bias_base, uint32_t dst,
    uint16_t m, uint16_t n, uint16_t k_or_length, uint8_t flags,
    uint8_t shift, uint8_t activation, uint32_t aux0, uint32_t src0_stride,
    uint32_t src1_stride, uint32_t dst_stride, uint16_t batch_count,
    uint16_t head_count, uint16_t wait_mask, uint16_t signal_mask,
    uint16_t clear_mask)
{
    unsigned i;
    for (i = 0; i < 16; ++i)
        desc->word[i] = 0;
    desc->word[0] = ((uint32_t)task_id << 16) | op;
    desc->word[1] = src0;
    desc->word[2] = src1;
    desc->word[3] = bias_base;
    desc->word[4] = dst;
    desc->word[5] = ((uint32_t)n << 16) | m;
    desc->word[6] = k_or_length;
    desc->word[7] = flags;
    desc->word[8] = aux0;
    desc->word[9] = ((uint32_t)(activation & 3u) << 5) | (shift & 31u);
    desc->word[10] = src0_stride;
    desc->word[11] = src1_stride;
    desc->word[12] = dst_stride;
    desc->word[13] = ((uint32_t)head_count << 16) | batch_count;
    desc->word[14] = ((uint32_t)signal_mask << 16) | wait_mask;
    desc->word[15] = ((uint32_t)clear_mask << 16) | CIMFORGE_DESC_V3_VERSION;
}

static inline void cimforge_desc_v7_init(
    cimforge_desc_v7_t *desc, uint8_t op, uint16_t task_id,
    uint32_t src0, uint32_t src1, uint32_t bias_base, uint32_t dst,
    uint16_t m, uint16_t n, uint16_t k_or_length, uint8_t flags,
    uint8_t shift, uint8_t activation, uint32_t aux0, uint32_t src0_stride,
    uint32_t src1_stride, uint32_t dst_stride, uint16_t batch_count,
    uint16_t head_count, uint16_t wait_mask, uint16_t signal_mask,
    uint16_t clear_mask)
{
    unsigned i;
    for (i = 0; i < 16; ++i)
        desc->word[i] = 0;
    desc->word[0] = ((uint32_t)task_id << 16) | op;
    desc->word[1] = src0;
    desc->word[2] = src1;
    desc->word[3] = bias_base;
    desc->word[4] = dst;
    desc->word[5] = ((uint32_t)n << 16) | m;
    desc->word[6] = k_or_length;
    desc->word[7] = flags;
    desc->word[8] = aux0;
    desc->word[9] = ((uint32_t)(activation & 3u) << 5) | (shift & 31u);
    desc->word[10] = src0_stride;
    desc->word[11] = src1_stride;
    desc->word[12] = dst_stride;
    desc->word[13] = ((uint32_t)head_count << 16) | batch_count;
    desc->word[14] = ((uint32_t)signal_mask << 16) | wait_mask;
    desc->word[15] = ((uint32_t)clear_mask << 16) | CIMFORGE_DESC_V7_VERSION;
}

static inline void cimforge_desc_v4_macro_init(
    cimforge_desc_v4_t *desc, uint8_t op, uint16_t task_id,
    uint32_t child_desc_base, uint16_t child_count, int child_external,
    uint16_t wait_mask, uint16_t signal_mask, uint16_t clear_mask)
{
    unsigned i;
    for (i = 0; i < 16; ++i)
        desc->word[i] = 0;
    desc->word[0] = ((uint32_t)task_id << 16) | op;
    desc->word[1] = child_desc_base;
    desc->word[6] = child_count;
    desc->word[7] = child_external ? CIMFORGE_DESC_F_MACRO_EXTERNAL : 0u;
    desc->word[14] = ((uint32_t)signal_mask << 16) | wait_mask;
    desc->word[15] = ((uint32_t)clear_mask << 16) | CIMFORGE_DESC_V4_VERSION;
}

static inline void cimforge_desc_v7_macro_init(
    cimforge_desc_v7_t *desc, uint8_t op, uint16_t task_id,
    uint64_t child_desc_base, uint16_t child_count, int child_external,
    uint16_t wait_mask, uint16_t signal_mask, uint16_t clear_mask)
{
    unsigned i;
    for (i = 0; i < 16; ++i)
        desc->word[i] = 0;
    desc->word[0] = ((uint32_t)task_id << 16) | op;
    desc->word[1] = (uint32_t)child_desc_base;
    desc->word[2] = (uint32_t)(child_desc_base >> 32);
    desc->word[6] = child_count;
    desc->word[7] = child_external ? CIMFORGE_DESC_F_MACRO_EXTERNAL : 0u;
    desc->word[14] = ((uint32_t)signal_mask << 16) | wait_mask;
    desc->word[15] = ((uint32_t)clear_mask << 16) | CIMFORGE_DESC_V7_VERSION;
}

#endif
