# iOSBluetooth-swift
Implementation of Bluetooth framework using swfit

一、如何使用？
1. LJBluetoothTransferInterface类是主要的对外接口类，玩家只需按照LJBluetoothTransferInterface中的方法规则进行使用，就可以轻松通过蓝牙传输数据
2. LJBLEManager类中的responseDataAnalyse方法，是判断设备返回来的数据是否完整，玩家需要自己根据自己的需求修改此方法的实现。（因为设备返回的数据可能是多包）
3. ResponseDataPack结构体是蓝牙传输的包结构，玩家需要根据自己的需求，修改包结构。

二、本框架的特点
1. 通过多线程与双队列，实现了发送数据与接收数据的异步操作。
2. 良好的接口设计满足发送数据操时后的重发机制。
3. 使用swift闭包替代了框架的代理回调机制，使代码更紧凑。


三、部分接口介绍
1. func sendData(data: NSData, timeout: NSTimeInterval=3, repeatCount: Int8=0, responseResult: ResponseResultCallBack?) -> Bool
通过蓝牙发送数据方法，这里主要说下responseResult参数与返回值。
responseResult：是一个闭包，为发送数据后的响应结果，其中闭包的ResponseResult参数是响应结果（详见代码注释），receiveData参数是接收到的数据；
返回值：当为true时，说明下发指令成功；为false时，说明下发指令失败。

注：如果我们并不关心某些指令的响应结果，那么我们只需关注返回值为true时，说明通信是成功的。这时responseResult参数传nil。

2. func scanDevice(timeout: NSTimeInterval=DefaultScanTimeout)
扫描方法的默认扫描时间是10秒，扫描结果通过协议代理方式返回。

