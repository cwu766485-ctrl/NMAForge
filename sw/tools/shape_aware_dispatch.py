"""Explicit offline INT8 mapping into existing legacy descriptors.

This does not rewrite published commands. Caller supplies dense operands before
publication and chooses an isolated execution contract. Dynamic operands retain
0x52. No hardware lease or access-order equivalence is implied.
"""
from cimforge_mapper import Descriptor, pack_i8, _pack_matrix_a_physical, _pack_matrix_b_physical


def map_matmul(a, b, *, policy='legacy', isolated=False):
    m, k, n = len(a), len(b), len(b[0])
    if not (1 <= m <= 16 and 1 <= n <= 16 and 1 <= k <= 1024):
        raise ValueError('unsupported bounded shape')
    if any(len(row) != k for row in a) or any(len(row) != n for row in b):
        raise ValueError('nonrectangular operands')
    if any(not isinstance(x, int) or not -128 <= x <= 127 for row in a+b for x in row):
        raise ValueError('signed INT8 operands required')
    if policy not in ('legacy', 'shape-aware', 'gemm'):
        raise ValueError('unknown policy')
    if policy != 'legacy' and not isolated:
        raise ValueError('mapping selection requires explicit isolated execution')
    eligible = m in (4,8,16) and n == 16 and k in (16,32,64,128)
    # Only shapes supported by paired product Top evidence may auto-select.
    use_gemm = eligible and (policy == 'gemm' or (policy == 'shape-aware' and m >= 8))
    if policy == 'gemm' and not eligible:
        raise ValueError('GEMM shape outside measured dispatch domain')
    if use_gemm:
        av = _pack_matrix_a_physical(a,16)
        bv = _pack_matrix_b_physical(b)
    else:
        av = [pack_i8((row+[0]*((-k)%16))[i:i+4]) for row in a for i in range(0,(k+15)//16*16,4)]
        bv = [pack_i8((row+[0]*(16-n))[i:i+4]) for row in b for i in range(0,16,4)]
    desc = Descriptor('shape-dispatch',0x7100,0x30 if use_gemm else 0x52,
                      0x1000,0x4000,0x9000,m=m,n=n,
                      k_or_length=k//4 if use_gemm else k,
                      aux0=1 if use_gemm else 0,
                      batch_count=1 if use_gemm else 0,head_count=1 if use_gemm else 0)
    return desc, av, bv
