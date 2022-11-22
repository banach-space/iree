!type = tensor<512x16xf32>

func.func @vecadd2d() -> (!type) {
  %cst0 = arith.constant 0.000000e+00 : f32
  %cst1 = arith.constant 2.000000e+00 : f32
  %0 = tensor.empty() : !type
  %x = linalg.fill ins(%cst1 : f32) outs(%0 : !type) ->   !type
  %1 = tensor.empty() : !type
  %y = linalg.fill ins(%cst0 : f32) outs(%1 : !type) ->   !type

  %2 = linalg.generic {
    indexing_maps = [affine_map<(d0, d1) -> (d0, d1)>,
                     affine_map<(d0, d1) -> (d0, d1)>],
    iterator_types = ["parallel", "parallel"]}
    ins(%x : !type) outs(%y : !type) {
      ^bb0(%arg3: f32, %arg4: f32):
        %3 = arith.addf %arg3, %arg4 : f32
        linalg.yield %3 : f32
      } -> !type

  return %2 : !type
}

// RUN: iree-opt %s --iree-hal-target-backends=cuda \
// RUN:     --iree-abi-transformation-pipeline \
// RUN:     --iree-flow-transformation-pipeline  \
// RUN:     --iree-stream-transformation-pipeline \
// RUN:     --iree-hal-configuration-pipeline | \
// RUN: iree-opt --pass-pipeline='builtin.module(hal.executable(hal.executable.variant(iree-llvmgpu-lower-executable-target)))' \
// RUN:     --iree-codegen-llvmgpu-use-transform-dialect=%p/vecadd2d_codegen_spec.mlir | \
// RUN: FileCheck %s --check-prefix=CHECK

// RUN: iree-compile %s --iree-hal-target-backends=cuda \
// RUN:     --iree-codegen-llvmgpu-use-transform-dialect=%p/vecadd2d_codegen_spec.mlir | \
// RUN: iree-run-module --entry_function=vecadd2d --device=cuda |\
// RUN: FileCheck %s --check-prefix=EXEC

//     CHECK:  hal.executable.export 
//     CHECK:  bb0(%[[DEV:.*]]: !hal.device, %[[A1:.*]]: index, %[[A2:.*]]: index):
//     CHECK:  %[[Dim2:.*]] = arith.constant 1 : index
//     CHECK:  %[[Dim3:.*]] = affine.apply #map()[%[[A1]]]                          
//     CHECK:  %[[Dim1:.*]] = affine.apply #map1()[%[[A2]]]
//     CHECK:  hal.return %[[Dim1]], %[[Dim2]], %[[Dim3]] : index, index, index

//     CHECK:  %[[BLKZ:.*]] = hal.interface.workgroup.id[2] : index
//     CHECK:  %[[BLKX:.*]] = hal.interface.workgroup.id[0] : index
//     CHECK:  memref.subview %0[%[[BLKZ:.*]], %[[BLKX:.*]]]


//      EXEC: EXEC @vecadd2d
//      EXEC: result[0]: hal.buffer_view
//      EXEC: 512x16xf32=[2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2][2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2]
