import DDC
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
let names = VCP.allCases.map { "\($0)" }

guard args.count == 2,
      let vcp = VCP.allCases.first(where: { "\($0)" == args[0] }) ?? UInt8(args[0], radix: 16).flatMap(VCP.init),
      let value = UInt16(args[1])
else {
    print("usage: lgbar <setting> <value>\nsettings: \(names.joined(separator: ", "))")
    exit(2)
}

guard DDC.set(vcp, value) else {
    print("no external display answered")
    exit(1)
}
