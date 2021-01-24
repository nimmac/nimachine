import macros

type
  Mem = array[16, uint16]
  AddrMode = enum
    NilMode,
    ImedMode,
    Imed8Mode,
    AbsMode,
    RelXMode,
    RelYMode,
    RegMode,
  
  VM = object
    pc: uint16
    mem: Mem
    a, x, y: uint16

proc read8(vm: VM, idx: uint16): uint16 =
  let 
    val16 = vm.mem[idx div 2]
    evenIdx = (idx+1) mod 2

  return uint8(val16 shr (8*evenIdx) and 0xFF)

proc read16(vm: VM, idx: uint16): uint16 =
  vm.read8(idx) shl 8 or vm.read8(idx+1)

macro ops(body: untyped): untyped =
  var
    instrData = newNimNode(nnkBracket)
    sizeData = newNimNode(nnkBracket)
    modeData = newNimNode(nnkBracket)
  
  for def in body:
    def.expectLen 2
    def[0].expectKind nnkPar
    def[1].expectKind nnkStmtList
    for i in 0..<def[0].len:
      case $def[0][i]
      of "NilMode", "RegMode": sizeData.add newLit(1)
      of "ImedMode", "AbsMode": sizeData.add newLit(3)
      of "Imed8Mode", "RelXMode", "RelYMode": sizeData.add newLit(2)
      
      modeData.add def[0][i]
      instrData.add newProc(params = [newEmptyNode(),
                                      newIdentDefs(ident"vm", newTree(nnkVarTy, ident"VM")),
                                      newIdentDefs(ident"arg", ident"uint16")],
                            body = def[1])

  result = newTree(nnkConstSection,
                   newTree(nnkConstDef, ident"opInstr", newEmptyNode(), instrData),
                   newTree(nnkConstDef, ident"opSize", newEmptyNode(), sizeData),
                   newTree(nnkConstDef, ident"opMode", newEmptyNode(), modeData))

ops:
  (NilMode): discard
  
  (ImedMode, Imed8Mode): vm.a = arg
  (AbsMode, RelXMode, RelYMode): vm.a = vm.mem[arg]
  (AbsMode, RelXMode, RelYMode): vm.mem[arg] = vm.a
  (ImedMode, Imed8Mode): vm.a += arg
  (AbsMode, RelXMode, RelYMode): vm.a += vm.mem[arg]
  (ImedMode, Imed8Mode): vm.a -= arg
  (AbsMode, RelXMode, RelYMode): vm.a -= vm.mem[arg]
  (ImedMode, Imed8Mode): vm.a *= arg
  (AbsMode, RelXMode, RelYMode): vm.a *= vm.mem[arg]
  (ImedMode, Imed8Mode): vm.a /= arg
  (AbsMode, RelXMode, RelYMode): vm.a /= vm.mem[arg]
  (RegMode): inc vm.a
  (RegMode): dec vm.a
  
  (ImedMode, Imed8Mode): vm.x = arg
  (AbsMode, RelYMode): vm.x = vm.mem[arg]
  (AbsMode, RelYMode): vm.mem[arg] = vm.x
  
  (ImedMode, Imed8Mode): vm.y = arg
  (AbsMode, RelXMode): vm.y = vm.mem[arg]
  (AbsMode, RelXMode): vm.mem[arg] = vm.y
  
  (AbsMode, RelXMode, RelYMode): inc vm.mem[arg]
  (AbsMode, RelXMode, RelYMode): dec vm.mem[arg]

proc step(vm: var VM) =
  let
    opcode = vm.read8(vm.pc)
    arg =
      case opMode[opcode]
      of NilMode, RegMode: 0'u16
      of ImedMode, AbsMode: vm.read16(vm.pc+1)
      of Imed8Mode: vm.read8(vm.pc+1)
      of RelXMode: vm.x + vm.read8(vm.pc+1)
      of RelYMode: vm.y + vm.read8(vm.pc+1)
    
  opInstr[opcode](vm, arg)
  vm.pc += opSize[opcode].uint16
