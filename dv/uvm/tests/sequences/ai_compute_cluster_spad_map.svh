typedef enum int unsigned {
    CL_SPAD_CMDQ = 0,
    CL_SPAD_CPLQ,
    CL_SPAD_SWEEP_CMDQ,
    CL_SPAD_SWEEP_CPLQ,
    CL_SPAD_CONTRACT_CMDQ,
    CL_SPAD_CONTRACT_CPLQ,
    CL_SPAD_MATRIX_A,
    CL_SPAD_MATRIX_B,
    CL_SPAD_MATRIX_Y,
    CL_SPAD_GELU_A,
    CL_SPAD_GELU_B,
    CL_SPAD_GELU_Y0,
    CL_SPAD_GELU_Y1,
    CL_SPAD_CNM_A,
    CL_SPAD_CNM_B,
    CL_SPAD_CNM_Y,
    CL_SPAD_CONTRACT_SHARED,
    CL_SPAD_CONTRACT_B,
    CL_SPAD_CONTRACT_Y0,
    CL_SPAD_CONTRACT_Y1,
    CL_SPAD_CONTRACT_MUTATED_Y,
    CL_SPAD_CONTRACT_SFU_Y,
    CL_SPAD_SCALAR_A,
    CL_SPAD_SCALAR_B,
    CL_SPAD_SCALAR_Y,
    CL_SPAD_FP_A,
    CL_SPAD_FP_B,
    CL_SPAD_FP_Y,
    CL_SPAD_CONV_A,
    CL_SPAD_CONV_W,
    CL_SPAD_CONV_Y,
    CL_SPAD_KV_VECTOR,
    CL_SPAD_KV_CACHE,
    CL_SPAD_KV_READ,
    CL_SPAD_SWEEP_MATRIX_Y,
    CL_SPAD_SWEEP_CNM_Y,
    CL_SPAD_SWEEP_SFU_Y,
    CL_SPAD_FAULT_Y,
    CL_SPAD_MATRIX_FAULT_A,
    CL_SPAD_MATRIX_FAULT_B,
    CL_SPAD_DMA_SOURCE,
    CL_SPAD_ABORT_MATRIX_DST,
    CL_SPAD_ABORT_SFU_DST,
    CL_SPAD_RESET_MATRIX_DST,
    CL_SPAD_RESET_SFU_DST,
    CL_SPAD_RESET_SWEEP_DST,
    CL_SPAD_REGION_COUNT
} ai_compute_cluster_spad_region_e;

// Compact, capacity-aware fixture allocator. Regions are packed in one
// relative SPAD address space and checked for bounds and pairwise overlap
// before the sequence performs its first data write. The same map therefore
// works with the product's 128/256/512 KiB geometries.
class ai_compute_cluster_spad_map extends uvm_object;
    `uvm_object_utils(ai_compute_cluster_spad_map)

    localparam int unsigned REGION_COUNT = CL_SPAD_REGION_COUNT;
    bit [31:0] capacity_bytes;
    bit [31:0] region_base[REGION_COUNT];
    bit [31:0] region_size[REGION_COUNT];
    int unsigned allocated_regions;

    function new(string name = "ai_compute_cluster_spad_map");
        super.new(name);
        capacity_bytes = '0;
        allocated_regions = 0;
        foreach (region_base[i]) begin
            region_base[i] = '0;
            region_size[i] = '0;
        end
    endfunction

    function automatic longint unsigned align_up(
        input longint unsigned value,
        input int unsigned alignment
    );
        if (alignment == 0) return value;
        return ((value + alignment - 1) / alignment) * alignment;
    endfunction

    function bit allocate_region(
        input ai_compute_cluster_spad_region_e region_id,
        input int unsigned bytes,
        input int unsigned alignment,
        ref longint unsigned cursor
    );
        longint unsigned first;
        longint unsigned limit;
        if (bytes == 0 || alignment == 0 || region_size[region_id] != 0)
            return 1'b0;
        first = align_up(cursor, alignment);
        limit = first + bytes;
        if (limit > capacity_bytes || limit > 64'hffff_ffff)
            return 1'b0;
        region_base[region_id] = first[31:0];
        region_size[region_id] = bytes;
        cursor = limit;
        allocated_regions++;
        return 1'b1;
    endfunction

    function bit build(input bit [31:0] bytes);
        longint unsigned cursor;
        longint unsigned first_i, limit_i, first_j, limit_j;
        bit ok;
        capacity_bytes = bytes;
        allocated_regions = 0;
        foreach (region_base[i]) begin
            region_base[i] = '0;
            region_size[i] = '0;
        end
        cursor = 32'h0000_1000;
        ok = 1'b1;

        // Queue windows reserve their maximum descriptor/completion offsets.
        ok &= allocate_region(CL_SPAD_CMDQ,          'h400, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_CPLQ,          'h400, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_SWEEP_CMDQ,    'h600, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_SWEEP_CPLQ,    'h300, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_CMDQ, 'h100, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_CPLQ, 'h300, 'h40, cursor);

        // Main Matrix/CNM/SFU workload. The long GELU source/output spans are
        // reserved because abort/reset scenarios can launch length=1024.
        ok &= allocate_region(CL_SPAD_MATRIX_A,       'h400, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_MATRIX_B,       'h800, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_MATRIX_Y,       'h800, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_GELU_A,        'h1000, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_GELU_B,         'h100, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_GELU_Y0,        'h100, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_GELU_Y1,        'h100, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_CNM_A,            'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CNM_B,           'h100, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CNM_Y,            'h40, 'h10, cursor);

        // Sequential contract and all-engine fixtures use disjoint regions.
        ok &= allocate_region(CL_SPAD_CONTRACT_SHARED, 'h100, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_B,      'h100, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_Y0,       'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_Y1,       'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_MUTATED_Y,'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_CONTRACT_SFU_Y,   'h100, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_SCALAR_A,           'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_SCALAR_B,           'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_SCALAR_Y,           'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_FP_A,               'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_FP_B,               'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_FP_Y,               'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_CONV_A,            'h24, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_CONV_W,            'h24, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_CONV_Y,             'h4, 'h4, cursor);
        ok &= allocate_region(CL_SPAD_KV_VECTOR,         'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_KV_CACHE,          'h60, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_KV_READ,           'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_SWEEP_MATRIX_Y,   'h800, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_SWEEP_CNM_Y,       'h40, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_SWEEP_SFU_Y,       'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_FAULT_Y,          'he00, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_MATRIX_FAULT_A,    'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_MATRIX_FAULT_B,    'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_DMA_SOURCE,        'h10, 'h10, cursor);
        ok &= allocate_region(CL_SPAD_ABORT_MATRIX_DST, 'h400, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_ABORT_SFU_DST,   'h1000, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_RESET_MATRIX_DST, 'h400, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_RESET_SFU_DST,   'h1000, 'h40, cursor);
        ok &= allocate_region(CL_SPAD_RESET_SWEEP_DST,  'h700, 'h40, cursor);

        if (!ok || allocated_regions != REGION_COUNT) return 1'b0;
        for (int i = 0; i < REGION_COUNT; i++) begin
            first_i = region_base[i];
            limit_i = first_i + region_size[i];
            if (region_size[i] == 0 || limit_i > capacity_bytes)
                return 1'b0;
            for (int j = i + 1; j < REGION_COUNT; j++) begin
                first_j = region_base[j];
                limit_j = first_j + region_size[j];
                if ((first_i < limit_j) && (first_j < limit_i))
                    return 1'b0;
            end
        end
        return 1'b1;
    endfunction

    function bit [31:0] addr(input ai_compute_cluster_spad_region_e region_id);
        return region_base[region_id];
    endfunction

    function bit [31:0] bytes(input ai_compute_cluster_spad_region_e region_id);
        return region_size[region_id];
    endfunction

    function bit [31:0] mapped_end();
        bit [31:0] last;
        last = '0;
        foreach (region_base[i])
            if ((region_base[i] + region_size[i]) > last)
                last = region_base[i] + region_size[i];
        return last;
    endfunction
endclass
