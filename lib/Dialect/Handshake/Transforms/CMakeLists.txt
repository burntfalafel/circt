add_circt_dialect_library(CIRCTHandshakeTransforms
  Analysis.cpp
  PassHelpers.cpp
  Materialization.cpp
  Buffers.cpp

  DEPENDS
  CIRCTHandshakeTransformsIncGen

  LINK_LIBS PUBLIC
  CIRCTHandshake
  MLIRIR
  MLIRPass
  MLIRTransformUtils
  MLIRMemRef
  MLIRAffine
  )
