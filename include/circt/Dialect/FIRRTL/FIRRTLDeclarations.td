//===- FIRRTLDeclarations.td - FIRRTL declaration ops ------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This describes the MLIR ops for FIRRTL declarations.
//
//===----------------------------------------------------------------------===//

def HasCustomSSAName : DeclareOpInterfaceMethods<OpAsmOpInterface,
                         ["getAsmResultNames"]>;

def InstanceOp : FIRRTLOp<"instance", [HasParent<"firrtl::FModuleOp, firrtl::WhenOp">,
    DeclareOpInterfaceMethods<SymbolUserOpInterface>, HasCustomSSAName,
    DeclareOpInterfaceMethods<HWInstanceLike, ["instanceName"]>]> {
  let summary = "Instantiate an instance of a module";
  let description = [{
    This represents an instance of a module.  The results are the modules inputs
    and outputs.  The inputs have flip type, the outputs do not.

    Examples:
    ```mlir
    %0 = firrtl.instance foo @Foo(in io: !firrtl.uint)
    ```
  }];

  let arguments = (ins FlatSymbolRefAttr:$moduleName, StrAttr:$name,
                       APIntAttr:$portDirections, StrArrayAttr:$portNames,
                       AnnotationArrayAttr:$annotations,
                       PortAnnotationsAttr:$portAnnotations,
                       BoolAttr:$lowerToBind,
                       OptionalAttr<SymbolNameAttr>:$inner_sym);

  let results = (outs Variadic<FIRRTLType>:$results);

  let hasCustomAssemblyFormat = 1;

  let builders = [
    OpBuilder<(ins "::mlir::TypeRange":$resultTypes,
                   "::mlir::StringRef":$moduleName,
                   "::mlir::StringRef":$name,
                   "::mlir::ArrayRef<Direction>":$portDirections,
                   "::mlir::ArrayRef<Attribute>":$portNames,
                   CArg<"ArrayRef<Attribute>", "{}">:$annotations,
                   CArg<"ArrayRef<Attribute>", "{}">:$portAnnotations,
                   CArg<"bool","false">:$lowerToBind,
                   CArg<"StringAttr", "StringAttr()">:$inner_sym)>,

    /// Constructor when you have the target module in hand.
    OpBuilder<(ins "FModuleLike":$module,
                   "mlir::StringRef":$name,
                   CArg<"ArrayRef<Attribute>", "{}">:$annotations,
                   CArg<"ArrayRef<Attribute>", "{}">:$portAnnotations,
                   CArg<"bool","false">:$lowerToBind,
                   CArg<"StringAttr", "StringAttr()">:$inner_sym)>
  ];

  let extraClassDeclaration = [{
    /// Lookup the module or extmodule for the symbol.  This returns null on
    /// invalid IR.
    FModuleLike getReferencedModule();
    FModuleLike getReferencedModule(SymbolTable& symtbl);

    /// Return the port direction for the specified result number.
    Direction getPortDirection(size_t resultNo) {
      return direction::get(portDirections()[resultNo]);
    }

    /// Return the port name for the specified result number.
    StringAttr getPortName(size_t resultNo) {
      return portNames()[resultNo].cast<StringAttr>();
    }
    StringRef getPortNameStr(size_t resultNo) {
      return getPortName(resultNo).getValue();
    }

    /// Hooks for port annotations.
    ArrayAttr getPortAnnotation(unsigned portIdx);
    void setAllPortAnnotations(ArrayRef<Attribute> annotations);

    /// Builds a new `InstanceOp` with the ports listed in `portIndices` erased,
    /// and updates any users of the remaining ports to point at the new
    /// instance.
    InstanceOp erasePorts(OpBuilder &builder, ArrayRef<unsigned> portIndices);

    /// Clone the instance op and add ports.  This is usually used in
    /// conjuction with adding ports to the referenced module. This will emit
    /// the new InstanceOp to the same location.
    InstanceOp cloneAndInsertPorts(ArrayRef<std::pair<unsigned, PortInfo>> ports);
  }];
}

def MemOp : FIRRTLOp<"mem", [HasCustomSSAName]> {
  let summary = "Define a new mem";
  let arguments =
    (ins Confined<I32Attr, [IntMinValue<0>]>:$readLatency,
         Confined<I32Attr, [IntMinValue<1>]>:$writeLatency,
         Confined<I64Attr, [IntMinValue<1>]>:$depth, RUWAttr:$ruw,
         StrArrayAttr:$portNames, StrAttr:$name,
         AnnotationArrayAttr:$annotations,
         PortAnnotationsAttr:$portAnnotations,
         OptionalAttr<SymbolNameAttr>:$inner_sym,
         OptionalAttr<I32Attr>:$groupID);
  let results = (outs Variadic<FIRRTLType>:$results);

  let assemblyFormat = [{
    (`sym` $inner_sym^)?
    $ruw custom<MemOp>(attr-dict) `:` qualified(type($results))
  }];

  let builders = [
    OpBuilder<(ins "::mlir::TypeRange":$resultTypes,
                   "uint32_t":$readLatency, "uint32_t":$writeLatency,
                   "uint64_t":$depth, "RUWAttr":$ruw,
                   "ArrayRef<Attribute>":$portNames,
                   CArg<"StringRef", "{}">:$name,
                   CArg<"ArrayRef<Attribute>", "{}">:$annotations,
                   CArg<"ArrayRef<Attribute>", "{}">:$portAnnotations,
                   CArg<"StringAttr", "StringAttr()">:$inner_sym)>
  ];

  let hasVerifier = 1;

  let hasCanonicalizeMethod = true;

  let extraClassDeclaration = [{
    enum class PortKind { Read, Write, ReadWrite };

    using NamedPort = std::pair<StringAttr, MemOp::PortKind>;

    /// Return the type of a port given the memory depth, type, and kind
    static BundleType getTypeForPort(uint64_t depth, FIRRTLType dataType,
                                     PortKind portKind, size_t maskBits = 0);

    /// Return the name and kind of ports supported by this memory.
    SmallVector<NamedPort> getPorts();

    /// Return the kind of the specified port.
    PortKind getPortKind(StringRef portName);

    /// Return the kind of the specified port number.
    PortKind getPortKind(size_t resultNo);

    /// Return the data-type field of the memory, the type of each element.
    FIRRTLType getDataType();

    /// Return the number of mask bits.
    size_t getMaskBits();

    /// Return the port name for the specified result number.
    StringAttr getPortName(size_t resultNo);
    StringRef getPortNameStr(size_t resultNo) {
      return getPortName(resultNo).getValue();
    }

    /// Return the port type for the specified result number.
    FIRRTLType getPortType(size_t resultNo);

    // Return the result for this instance that corresponds to the specified
    // port name.
    Value getPortNamed(StringRef name) {
      return getPortNamed(StringAttr::get(getContext(), name));
    }
    Value getPortNamed(StringAttr name);

    /// Hooks for port annotations.
    ArrayAttr getPortAnnotation(unsigned portIdx);
    void setAllPortAnnotations(ArrayRef<Attribute> annotations);

    /// Get the number of read ports, write ports and read write ports.
    void getNumPorts(size_t &numReadPorts, size_t &numWritePorts, size_t &numReadWritePorts);

    // Extract the relevant attributes from the MemOp and return a FirMemory object.
    FirMemory getSummary();
  }];
}

def NodeOp : FIRRTLOp<"node",
      [SameOperandsAndResultType, InferTypeOpInterface, HasCustomSSAName]> {
  let summary = "No-op to name a value";
  let description = [{
    A node is simply a named intermediate value in a circuit. The node must
    be initialized to a value with a passive type and cannot be connected to.
    Nodes are often used to split a complicated compound expression into named
    subexpressions.

    ```
      %result = firrtl.node %input : t1
    ```
    }];

  let arguments = (ins PassiveType:$input, StrAttr:$name,
                       AnnotationArrayAttr:$annotations,
                       OptionalAttr<SymbolNameAttr>:$inner_sym);
  let results = (outs FIRRTLType:$result);

  let builders = [
    OpBuilder<(ins "::mlir::Type":$elementType,
                   "::mlir::Value":$input,
                   CArg<"StringRef", "{}">:$name,
                   CArg<"ArrayRef<Attribute>","{}">:$annotations,
                   CArg<"StringAttr", "StringAttr()">:$inner_sym), [{
      return build($_builder, $_state, elementType, input, name,
                   $_builder.getArrayAttr(annotations), inner_sym);
    }]>
  ];

  let assemblyFormat = [{
    (`sym` $inner_sym^)?
    $input custom<ImplicitSSAName>(attr-dict) `:` qualified(type($input))
  }];

  let hasCanonicalizer = true;

  let extraClassDeclaration = [{
    /// Infer the return types of this operation.
    static LogicalResult inferReturnTypes(MLIRContext *context,
                                          Optional<Location> loc,
                                          ValueRange operands,
                                          DictionaryAttr attrs,
                                          mlir::RegionRange regions,
                                          SmallVectorImpl<Type> &results);
  }];
}

def RegOp : FIRRTLOp<"reg", [HasCustomSSAName/*MemAlloc*/]> {
  let summary = "Define a new register";
  let description = [{
    Declare a new register:

    ```
    %name = firrtl.reg %clockVal : t1
    ```
    }];

  let arguments = (
    ins ClockType:$clockVal, StrAttr:$name,
        AnnotationArrayAttr:$annotations,
        OptionalAttr<SymbolNameAttr>:$inner_sym);
  let results = (outs AnyRegisterType:$result);

  let builders = [
    OpBuilder<(ins "::mlir::Type":$elementType, "::mlir::Value":$clockVal,
                   CArg<"StringRef", "{}">:$name,
                   CArg<"ArrayRef<Attribute>","{}">:$annotations,
                   CArg<"StringAttr", "StringAttr()">:$inner_sym), [{
      return build($_builder, $_state, elementType, clockVal, name,
                   $_builder.getArrayAttr(annotations), inner_sym);
    }]>
  ];

  let assemblyFormat = [{
    (`sym` $inner_sym^)?
    operands custom<ImplicitSSAName>(attr-dict) `:` qualified(type($result))
  }];
  let hasCanonicalizeMethod = true;
}

def RegResetOp : FIRRTLOp<"regreset", [HasCustomSSAName/*MemAlloc*/]> {
  let summary = "Define a new register with a reset";
  let description = [{
    Declare a new register:
    ```
      %name = firrtl.regreset %clockVal, %resetSignal, %resetValue : t1
    ```
    }];

  let arguments = (
    ins ClockType:$clockVal, AnyResetType:$resetSignal,
        AnyRegisterType:$resetValue,
        StrAttr:$name, AnnotationArrayAttr:$annotations,
        OptionalAttr<SymbolNameAttr>:$inner_sym);
  let results = (outs AnyRegisterType:$result);

  let builders = [
    OpBuilder<(ins "::mlir::Type":$elementType, "::mlir::Value":$clockVal,
                   "::mlir::Value":$resetSignal, "::mlir::Value":$resetValue,
                   CArg<"StringRef", "{}">:$name,
                   CArg<"ArrayRef<Attribute>","{}">:$annotations,
                   CArg<"StringAttr", "StringAttr()">:$inner_sym), [{
      return build($_builder, $_state, elementType, clockVal, resetSignal,
                   resetValue, name, $_builder.getArrayAttr(annotations),
                   inner_sym);
    }]>
  ];

  let assemblyFormat = [{
    (`sym` $inner_sym^)?
    operands custom<ImplicitSSAName>(attr-dict)
    `:` qualified(type($resetSignal)) `,` qualified(type($resetValue)) `,` qualified(type($result))
  }];

  let hasCanonicalizer = true;
  let hasVerifier = 1;
}

def WireOp : FIRRTLOp<"wire", [HasCustomSSAName]> {
  let summary = "Define a new wire";
  let description = [{
    Declare a new wire:
    ```
      %name = firrtl.wire : t1
    ```
    }];

  let arguments = (
    ins StrAttr:$name, AnnotationArrayAttr:$annotations,
        OptionalAttr<SymbolNameAttr>:$inner_sym);
  let results = (outs FIRRTLType:$result);

  let builders = [
    OpBuilder<(ins "::mlir::Type":$elementType,
                      CArg<"StringRef", "{}">:$name,
                      CArg<"ArrayRef<Attribute>","{}">:$annotations,
                      CArg<"StringAttr", "StringAttr()">:$inner_sym), [{
      return build($_builder, $_state, elementType, name,
                   $_builder.getArrayAttr(annotations), inner_sym);
    }]>
  ];

  let assemblyFormat = [{
    (`sym` $inner_sym^)?
    custom<ImplicitSSAName>(attr-dict) `:` qualified(type($result))
  }];
  let hasCanonicalizer = true;
}
