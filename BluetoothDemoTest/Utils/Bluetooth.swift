//
//  Bluetooth.swift
//  BluetoothDemoTest
//
//  Created by RND on 2021/2/2.
//

import Foundation
import CoreBluetooth
import Combine


class Bluetooth: NSObject {
    
    static let shared = Bluetooth()
    
    // 温度处理数据
    private let CHARACTERISTIC_UUID_TEMP = "5f5f9010-0e0d-4bd4-b5dc-e4ff47a45984"
    // 单位显示数据
    private let CHARACTERISTIC_UUID_UNIT = "7633F5BB-D0C6-478B-B031-D3A0D70C2A7E"
    
    private let SERVICE_UUID =                "49535343-FE7D-4AE5-8FA9-9FAFD205E455"//seviceUUID
    private let CHARACTERISTIC_UUID_SEND =    "49535343-1E4D-4BD9-BA61-23C647249616"//device send to phone
    private let CHARACTERISTIC_UUID_RECEIVE = "49535343-8841-43F4-A8D4-ECBE34729BB3"//phone write to device
    private let CHARACTERISTIC_UUID_RENAME =  "00005343-0000-1000-8000-00805F9B34FB"//rename device
    private let CHARACTERISTIC_UUID_MAC =     "00005344-0000-1000-8000-00805F9B34FB"//read mac address
    
    
    
    private var mCentralManager: CBCentralManager?
    
    private var mPeripheral: CBPeripheral? {
        didSet{
            DispatchQueue.main.async {
                if let peripheral = self.mPeripheral {
                    Store.shared.home.mPeripheral = peripheral
                }else{
                    Store.shared.reset()
                }
            }
        }
    }
    
    private var mCharacteristic_send: CBCharacteristic?
    private var mCharacteristic_receive: CBCharacteristic?
    private var mCharacteristic_rename: CBCharacteristic?
    
    private var mPeripheralArray: [CBPeripheral] = []
    
    // 这是定时器用于减慢蓝牙刷新的频率
    private var timer: AnyCancellable?
    
    // 减速后蓝牙列表
    private var deviceArray = [CBPeripheral]() {
        didSet{
            DispatchQueue.main.async {
                Store.shared.device.deviceArray = self.deviceArray
            }
        }
    }
    
    //手机蓝牙状态
    private var mCentralState: CentralState = .poweredOn {
        didSet {
            DispatchQueue.main.async {
                Store.shared.home.mCentralState = self.mCentralState
            }
        }
    }
    
    //外设蓝牙状态
    private var mPeripheralSate: PeripheralState = .unconnected{
        didSet{
            DispatchQueue.main.async {
                Store.shared.home.mPeripheralState = self.mPeripheralSate
            }
        }
    }
    
    
    enum CentralState: Int {
        case unknow = 0
        case resetting = 1
        case unsupported = 2
        case unauthorized = 3
        case poweredOff = 4
        case poweredOn = 5
        case scaning = 6
        case stopScan = 7
    }
    
    enum PeripheralState: Int {
        case unknown = 0
        case unconnected = 1
        case connecting = 2
        case connected = 3
        case connectFail = 4
        case disconnected = 5
    }
    
    private let queue = DispatchQueue(label: "BluetoothQueue")
    
}

extension Bluetooth{
    
    func run(){
        mCentralManager = CBCentralManager(delegate: self, queue: queue)
    }
    
    func scan(){
        mCentralState = .scaning
        mPeripheralArray.removeAll(keepingCapacity: false)
        mCentralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
        
        // 每0.5秒更新一次，否则刷新速度太快，界面会卡住
        timer?.cancel()
        timer = Timer.publish(every: 0.5, on: .main, in: .default).autoconnect()
            .sink(receiveValue: { (_) in
                self.queue.async {
                    self.deviceArray = self.mPeripheralArray
                }
            })
    }
    
    func stopScan(){
        timer?.cancel()
        mCentralManager?.stopScan()
        mCentralState = .stopScan
    }
    
    func refresh(){
        scan()
    }
    
    func connect(_ peripheral: CBPeripheral){
        disconnect()
        
        mCentralManager?.connect(peripheral, options: nil)
        mPeripheralSate = .connecting
    }
    
    
    func disconnect(){
        if let peripheral = mPeripheral {
            mCentralManager?.cancelPeripheralConnection(peripheral)
            mPeripheral = nil
            mCharacteristic_send = nil
            mCharacteristic_receive = nil
            mCharacteristic_rename = nil
            mPeripheralSate = .unconnected
        }
    }
    
    func readData(_ data: Data){
        DataParser.shared.readData(data)
    }
    
    func setName(_ name: String){
        if let characteristic = mCharacteristic_rename, name.count > 0,
           let data = name.data(using: .utf8){
            var header = 0x00
            var length = data.count
            
            var newData = Data()
            newData.append(Data(bytes: &header, count: 1))
            newData.append(Data(bytes: &length, count: 1))
            newData.append(data)
            
            mPeripheral?.writeValue(newData, for: characteristic, type: .withoutResponse)
            
            if let peripheral = mPeripheral {
                self.queue.asyncAfter(deadline: .now() + 1){
                    self.connect(peripheral)
                }
            }
        }
    }
    
    
    func setFrequence(_ index: Int){
        var value = 0xF0 + index
        let data = Data(bytes: &value, count: 1)
        
        self.writeValue(data: data)
    }
    
    
    func setFilter(_ index: Int){
        var value = 0xF4 + index
        let data = Data(bytes: &value, count: 1)
        self.writeValue(data: data)
    }
    
    
    func getVersion(){
        getSoftwareVersion()
        getHardwareVersion()
        getBluetoothVersion()
    }
    
    
    func getSoftwareVersion(){
        var value = 0xFF
        let data = Data(bytes: &value, count: 1)
        self.writeValue(data: data)
    }
    
    func getHardwareVersion(){
        var value = 0xFE
        let data = Data(bytes: &value, count: 1)
        self.writeValue(data: data)
    }
    
    func getBluetoothVersion(){
        var value = 0xFD
        let data = Data(bytes: &value, count: 1)
        self.writeValue(data: data)
    }
    

    
    func writeValue(data: Data){
        queue.sync {
            if let characteristic = mCharacteristic_receive{
                mPeripheral?.writeValue(data, for: characteristic, type: .withoutResponse)
            }
        }
    }

}


extension Bluetooth: CBCentralManagerDelegate{
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if let state = CentralState(rawValue: central.state.rawValue){
            mCentralState = state
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let _ = peripheral.name {
            if let index = mPeripheralArray.map({$0.identifier}).firstIndex(of: peripheral.identifier){
                mPeripheralArray[index] = peripheral
            }else{
                mPeripheralArray.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScan()
        
        mPeripheralSate = .connected
        
        mPeripheral = peripheral
        mPeripheral?.delegate = self
        
        //此段代码可以更改为 读取所有的蓝牙服务
        //mPeripheral?.discoverServices([CBUUID(string: SERVICE_UUID)])
        
        mPeripheral?.discoverServices(nil)
        
        DataParser.shared.startTimer()
        
        DispatchQueue.main.async {
            Store.shared.device.isConnected.send(true)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        mPeripheralSate = .connectFail
        mPeripheral = nil
        
        DispatchQueue.main.async {
            Store.shared.device.error = .deviceConnectFail
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mPeripheralSate = .disconnected
        mPeripheral = nil
        
        DataParser.shared.StopTimer()
    }
    
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        switch event {
        case .peerConnected:
            mPeripheralSate = .connected
        case .peerDisconnected:
            mPeripheralSate = .disconnected
        default:
            mPeripheralSate = .unknown
        }
    }
    
    
}

extension Bluetooth: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("services = ", peripheral.services as Any)
        if let service = peripheral.services?.first{
            peripheral.discoverCharacteristics([
                CBUUID(string: CHARACTERISTIC_UUID_SEND),
                CBUUID(string: CHARACTERISTIC_UUID_RECEIVE),
                CBUUID(string: CHARACTERISTIC_UUID_RENAME)
            ], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let characteristicArray = service.characteristics{
            for characteristic in characteristicArray{
                switch characteristic.uuid.uuidString {
                case CHARACTERISTIC_UUID_RECEIVE:
                    mCharacteristic_receive = characteristic
                case CHARACTERISTIC_UUID_SEND:
                    mCharacteristic_send = characteristic
                    peripheral.readValue(for: characteristic)
                    peripheral.setNotifyValue(true, for: characteristic)
                case CHARACTERISTIC_UUID_RENAME:
                    mCharacteristic_rename = characteristic
                default:
                    break
                }
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            self.readData(data)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("didWriteVlaueFor = \(peripheral.name ?? "")")
    }
    
    
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        mPeripheral = peripheral
        print("peripheralDidUpdateName = \(peripheral.name ?? "")")
    }
    
    
}

