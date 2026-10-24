`timescale 1ns/1ps

module tb_ai_tensor_matrix_datapath_random;
  reg [31:0] a0,a1,a2,a3,b0,b1,b2,b3;
  reg [1:0] lane;
  reg transpose_a,transpose_b,mac_enable,bias_enable;
  reg [4:0] scale_shift;
  reg [1:0] activation;
  reg signed [63:0] acc0,acc1,acc2,acc3,scalar_acc;
  reg signed [31:0] bias0,bias1,bias2,bias3,scalar_bias;
  wire signed [15:0] p0,p1,p2,p3,p4,p5,p6,p7;
  wire signed [15:0] p8,p9,p10,p11,p12,p13,p14,p15;
  wire [31:0] post_scalar,post0,post1,post2,post3;
  wire signed [7:0] a_lane0,a_lane1,a_lane2,a_lane3;
  wire signed [7:0] b_lane0,b_lane1,b_lane2,b_lane3;
  wire [255:0] products={p15,p14,p13,p12,p11,p10,p9,p8,
                          p7,p6,p5,p4,p3,p2,p1,p0};
  reg [255:0] expected_products;
  reg [31:0] expected_post[0:4];
  integer seed=20261021,initial_seed,cycles,row,col;
  reg signed [7:0] av,bv;
  reg signed [15:0] product_ref;

  ai_tensor_matrix_datapath dut(
    .a0(a0),.a1(a1),.a2(a2),.a3(a3),.b0(b0),.b1(b1),.b2(b2),.b3(b3),
    .lane(lane),.transpose_a(transpose_a),.transpose_b(transpose_b),
    .mac_enable(mac_enable),.a_lane0(a_lane0),.a_lane1(a_lane1),
    .a_lane2(a_lane2),.a_lane3(a_lane3),.b_lane0(b_lane0),
    .b_lane1(b_lane1),.b_lane2(b_lane2),.b_lane3(b_lane3),
    .product0(p0),.product1(p1),.product2(p2),.product3(p3),
    .product4(p4),.product5(p5),.product6(p6),.product7(p7),
    .product8(p8),.product9(p9),.product10(p10),.product11(p11),
    .product12(p12),.product13(p13),.product14(p14),.product15(p15),
    .acc0(acc0),.acc1(acc1),.acc2(acc2),.acc3(acc3),
    .bias0(bias0),.bias1(bias1),.bias2(bias2),.bias3(bias3),
    .bias_enable(bias_enable),.scale_shift(scale_shift),.activation(activation),
    .scalar_acc(scalar_acc),.scalar_bias(bias_enable?scalar_bias:32'sd0),
    .post_scalar(post_scalar),.post0(post0),.post1(post1),.post2(post2),.post3(post3));

  function automatic signed [7:0] byte_at(input [31:0] word,input [1:0] byte_index);
    case (byte_index)
      0: byte_at=$signed(word[7:0]);
      1: byte_at=$signed(word[15:8]);
      2: byte_at=$signed(word[23:16]);
      default: byte_at=$signed(word[31:24]);
    endcase
  endfunction

  function automatic signed [7:0] matrix_element(
    input [31:0] w0,w1,w2,w3,
    input [1:0] major,lane_index,input transpose);
    reg [1:0] word_index,byte_index;
    reg [31:0] selected;
    begin
      word_index=transpose?lane_index:major;
      byte_index=transpose?major:lane_index;
      case(word_index)
        0:selected=w0; 1:selected=w1; 2:selected=w2; default:selected=w3;
      endcase
      matrix_element=byte_at(selected,byte_index);
    end
  endfunction

  function automatic [31:0] post_reference(
    input signed [63:0] accumulated,input signed [31:0] bias_value,
    input enable_bias,input [4:0] shift,input [1:0] act);
    reg signed [63:0] value;
    begin
      value=accumulated+(enable_bias?{{32{bias_value[31]}},bias_value}:64'sd0);
      value=value>>>shift;
      if(act==1 && value<0) value=0;
      else if(act==2) begin
        if(value<0) value=0;
        else if(value>6) value=6;
      end
      if(value>64'sh000000007fffffff) post_reference=32'h7fffffff;
      else if(value< -64'sd2147483648) post_reference=32'h80000000;
      else post_reference=value[31:0];
    end
  endfunction

  task automatic check_case(input integer case_id);
    begin
      expected_products=0;
      for(row=0;row<4;row=row+1) begin
        av=matrix_element(a0,a1,a2,a3,row[1:0],lane,transpose_a);
        for(col=0;col<4;col=col+1) begin
          bv=matrix_element(b0,b1,b2,b3,col[1:0],lane,transpose_b);
          product_ref=mac_enable ? ($signed(av)*$signed(bv)) : 0;
          expected_products[((row*4+col)*16)+:16]=product_ref;
        end
      end
      expected_post[0]=post_reference(acc0,bias0,bias_enable,scale_shift,activation);
      expected_post[1]=post_reference(acc1,bias1,bias_enable,scale_shift,activation);
      expected_post[2]=post_reference(acc2,bias2,bias_enable,scale_shift,activation);
      expected_post[3]=post_reference(acc3,bias3,bias_enable,scale_shift,activation);
      expected_post[4]=post_reference(scalar_acc,scalar_bias,bias_enable,scale_shift,activation);
      #1;
      if(products!==expected_products ||
         {post3,post2,post1,post0,post_scalar}!==
         {expected_post[3],expected_post[2],expected_post[1],expected_post[0],expected_post[4]}) begin
        $display("MATRIX_DATAPATH_MISMATCH case=%0d lane=%0d transpose=%b%b mac=%b shift=%0d act=%0d",
                 case_id,lane,transpose_a,transpose_b,mac_enable,scale_shift,activation);
        $display("products got=%h expected=%h",products,expected_products);
        $display("post got=%h expected=%h",{post3,post2,post1,post0,post_scalar},
                 {expected_post[3],expected_post[2],expected_post[1],expected_post[0],expected_post[4]});
        $fatal(1,"matrix datapath oracle mismatch");
      end
    end
  endtask

  initial begin
    if($value$plusargs("SEED=%d",seed)) begin end
    initial_seed=seed;
    // Exhaust every lane/transpose/gating combination before random stress.
    for(cycles=0;cycles<64;cycles=cycles+1) begin
      a0=$random(seed);a1=$random(seed);a2=$random(seed);a3=$random(seed);
      b0=$random(seed);b1=$random(seed);b2=$random(seed);b3=$random(seed);
      lane=cycles[1:0];transpose_a=cycles[2];transpose_b=cycles[3];
      mac_enable=cycles[4];bias_enable=cycles[5];
      acc0=$random(seed);acc1=$random(seed);acc2=$random(seed);acc3=$random(seed);
      scalar_acc=$random(seed);bias0=$random(seed);bias1=$random(seed);
      bias2=$random(seed);bias3=$random(seed);scalar_bias=$random(seed);
      scale_shift=cycles%32;activation=(cycles/7)%4;
      check_case(cycles);
    end
    // Include explicit 64-bit saturation boundaries and activation clamps.
    for(cycles=64;cycles<72;cycles=cycles+1) begin
      a0=$random(seed);a1=$random(seed);a2=$random(seed);a3=$random(seed);
      b0=$random(seed);b1=$random(seed);b2=$random(seed);b3=$random(seed);
      lane=cycles[1:0];transpose_a=cycles[2];transpose_b=cycles[3];
      mac_enable=1;bias_enable=1;scale_shift=cycles%8;activation=cycles%3;
      acc0=(cycles[0]?64'sh00000001_80000000:64'shffff_fffe_7fffffff);
      acc1=(cycles[0]?64'sh7fff_ffff_ffff_ffff: -64'sh7fff_ffff_ffff_ffff);
      acc2=-64'sd100;acc3=64'sd100;scalar_acc=acc1;
      bias0=-32'sd10;bias1=32'sd10;bias2=32'sd8;bias3=-32'sd8;scalar_bias=32'sd1;
      check_case(cycles);
    end
    for(cycles=72;cycles<10072;cycles=cycles+1) begin
      a0=$random(seed);a1=$random(seed);a2=$random(seed);a3=$random(seed);
      b0=$random(seed);b1=$random(seed);b2=$random(seed);b3=$random(seed);
      lane=$random(seed);transpose_a=$random(seed);transpose_b=$random(seed);
      mac_enable=$random(seed);bias_enable=$random(seed);
      acc0=$random(seed);acc1=$random(seed);acc2=$random(seed);acc3=$random(seed);
      scalar_acc=$random(seed);bias0=$random(seed);bias1=$random(seed);
      bias2=$random(seed);bias3=$random(seed);scalar_bias=$random(seed);
      scale_shift=$random(seed);activation=$random(seed);
      check_case(cycles);
    end
    $display("MATRIX_DATAPATH_RANDOM_PASS cases=10072 seed=%0d",initial_seed);
    $finish;
  end
endmodule
