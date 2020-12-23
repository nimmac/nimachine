import macros

type
  Mem = array[16384, uint16]
  AddrMode = enum
    NilMode,
    AbsMode,
    MemMode
  
  VM = object
    pc: uint16
    mem: Mem
    a, x, y, i: uint16

macro ops(body: untyped): untyped =
  var
    instrData = newNimNode(nnkBracket)
    sizeData = newNimNode(nnkBracket)
    modeData = newNimNode(nnkBracket)
  
  for def in body:
    def.expectLen 2
    def[0].expectKind nnkPar
    def[1].expectKind nnkStmtList
    sizeData.add def[0][0]
    for i in 1..<def[0].len:
      modeData.add def[0][i]
      instrData.add newProc(params = [newEmptyNode(),
                                      newIdentDefs(ident"vm", newTree(nnkVarTy, ident"VM")),
                                      newIdentDefs(ident"arg", ident"uint16")],
                            body = def[1])

  result = newTree(nnkConstSection,
                   newTree(nnkConstDef, ident"opInstr", newEmptyNode(), instrData),
                   newTree(nnkConstDef, ident"opSize", newEmptyNode(), sizeData),
                   newTree(nnkConstDef, ident"opMode", newEmptyNode(), modeData))

# (the size(in bytes) of each opcode, list of possible addressing modes)
ops:
  (0, NilMode): return
  (3, AbsMode, MemMode): vm.a = arg
  (3, AbsMode, MemMode): vm.x = arg
  (3, AbsMode, MemMode): vm.y = arg
  (3, AbsMode, MemMode): vm.i = arg
  (3, AbsMode, MemMode): vm.mem[arg] = vm.a
  (3, AbsMode, MemMode): vm.mem[arg] = vm.x
  (3, AbsMode, MemMode): vm.mem[arg] = vm.y
  (3, AbsMode, MemMode): vm.mem[arg] = vm.i

proc step(vm: var VM) =
  let
    opcode = vm.mem[vm.pc]
    arg =
      case opMode[opcode]
      of NilMode: 0
      of AbsMode: vm.mem[vm.pc+1]
      of MemMode: vm.mem[vm.mem[pc+1]]

  opInstr[opcde](vm, arg)
  vm.pc += opSize[opcode]
