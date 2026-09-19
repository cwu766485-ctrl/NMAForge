class ai_descriptor extends uvm_sequence_item;
    rand bit [15:0] task_id;
    rand bit [7:0] opcode;
    rand bit [31:0] src0, src1, bias, dst;
    rand bit [15:0] m_size, n_size, k_or_length;
    rand bit [7:0] flags;
    rand bit [31:0] aux0, src0_stride, src1_stride, dst_stride;
    rand bit [15:0] batch_count, head_count, wait_mask, signal_mask, clear_mask;
    rand bit [7:0] version;
    `uvm_object_utils_begin(ai_descriptor)
        `uvm_field_int(task_id, UVM_DEFAULT) `uvm_field_int(opcode, UVM_DEFAULT)
        `uvm_field_int(src0, UVM_DEFAULT) `uvm_field_int(src1, UVM_DEFAULT)
        `uvm_field_int(bias, UVM_DEFAULT) `uvm_field_int(dst, UVM_DEFAULT)
        `uvm_field_int(m_size, UVM_DEFAULT) `uvm_field_int(n_size, UVM_DEFAULT)
        `uvm_field_int(k_or_length, UVM_DEFAULT) `uvm_field_int(flags, UVM_DEFAULT)
        `uvm_field_int(aux0, UVM_DEFAULT) `uvm_field_int(src0_stride, UVM_DEFAULT)
        `uvm_field_int(src1_stride, UVM_DEFAULT) `uvm_field_int(dst_stride, UVM_DEFAULT)
        `uvm_field_int(batch_count, UVM_DEFAULT) `uvm_field_int(head_count, UVM_DEFAULT)
        `uvm_field_int(wait_mask, UVM_DEFAULT) `uvm_field_int(signal_mask, UVM_DEFAULT)
        `uvm_field_int(clear_mask, UVM_DEFAULT) `uvm_field_int(version, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "ai_descriptor"); super.new(name); endfunction
    function void unpack_words(input bit [31:0] words [16]);
        task_id=words[0][31:16]; opcode=words[0][7:0]; src0=words[1]; src1=words[2]; bias=words[3]; dst=words[4];
        m_size=words[5][15:0]; n_size=words[5][31:16]; k_or_length=words[6][15:0]; flags=words[7][7:0]; aux0=words[8];
        src0_stride=words[10]; src1_stride=words[11]; dst_stride=words[12]; batch_count=words[13][15:0]; head_count=words[13][31:16];
        wait_mask=words[14][15:0]; signal_mask=words[14][31:16]; version=words[15][7:0]; clear_mask=words[15][31:16];
    endfunction
endclass
