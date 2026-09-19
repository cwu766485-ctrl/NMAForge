class ai_accel_reference_model extends uvm_object;
    `uvm_object_utils(ai_accel_reference_model)
    function new(string name="ai_accel_reference_model"); super.new(name); endfunction
    function bit descriptor_is_structurally_valid(ai_descriptor d); return (d.version==8'd7)&&(d.opcode!=0)&&(d.dst[1:0]==0)&&(d.src0[1:0]==0); endfunction
    function ai_completion predict_rejected_completion(ai_descriptor d, bit [3:0] error_code);
        ai_completion c=ai_completion::type_id::create("rejected_completion"); c.task_id=d.task_id; c.status=4'hf; c.error_code=error_code; c.result='0; c.element_count='0; return c;
    endfunction
endclass
