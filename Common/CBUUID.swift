import CoreBluetooth

extension CBUUID {
    static var DANAKIT_SERVICE: CBUUID { CBUUID(string: "FFF0") }
    static var DANAKIT_READ_CHAR: CBUUID { CBUUID(string: "FFF1") }
    static var DANAKIT_WRITE_CHAR: CBUUID { CBUUID(string: "FFF2") }
}
