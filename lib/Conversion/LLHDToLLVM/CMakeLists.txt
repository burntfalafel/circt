add_circt_conversion_library(CIRCTLLHDToLLVM
  LLHDToLLVM.cpp

  DEPENDS
  CIRCTConversionPassIncGen

  LINK_COMPONENTS
  Core

  LINK_LIBS PUBLIC
  CIRCTLLHD
  CIRCTComb
  CIRCTHW
  MLIRControlFlowToLLVM
  MLIRFuncToLLVM
  MLIRLLVMCommonConversion
  MLIRVector
  MLIRTransforms
  MLIRReconcileUnrealizedCasts
)
