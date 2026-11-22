# MoonCharge

MoonCharge 是面向 MoonBit 的 OCPP 1.6J 协议核心。它把充电桩与充电站
管理系统之间的 JSON-RPC 帧、核心业务载荷、连接器交易状态机和智能充电
配置解析为可测试的纯 MoonBit API。

MoonCharge 不绑定 WebSocket、HTTP、数据库或操作系统时钟。调用方负责传输、
持久化和时间来源，因此同一套协议逻辑可以运行在 wasm、wasm-gc、JavaScript
和 Native 后端。

## 为什么需要 MoonCharge

MoonBit 已有 HTTP、WebSocket、MQTT、CAN、DBC 和物联网格式库，但截至
2026-11-18，MoonCakes 实时检索没有 OCPP、EVSE 或 CSMS 模块。OCPP 消息又
不能只当作普通 JSON：

- `CALL`、`CALLRESULT` 和 `CALLERROR` 的数组结构、方向与错误语义不同；
- `StartTransaction`、`MeterValues` 和 `StopTransaction` 共享交易但不共享载荷；
- 连接器不能同时开启两个交易，停止后的电量不能小于启动电量；
- 多个 `ChargingProfile` 还要经过用途、交易号、stack level、有效期和
  充电站最大功率的共同约束。

MoonCharge 把这些容易出错的边界集中到一个无 I/O 的协议层中，并提供稳定的
错误结果。

## 功能

- 严格 OCPP 1.6J JSON-RPC framing：`CALL`、`CALLRESULT`、`CALLERROR`。
- 字符串、数字和 `null` 消息 id；数字 id 保留原始文本。
- `FrameLimits` 资源边界：UTF-8 输入大小、嵌套深度、消息 ID、动作和 payload 字段数。
- 默认拒绝重复 JSON key，同时允许调用方显式启用兼容模式。
- 显式 `OcppVersion` 上下文；`VersionedFrame` 将帧、方向、类型分发和一致性审计绑定到协议版本。
- 无 I/O 的 `PendingCallTable`，按消息 ID 关联 CALL 与 CALLRESULT/CALLERROR，并处理超时、容量、方向和重复 ID。
- `ChargePointSession` 站点级多连接器状态：增删连接器、原子批量状态更新、整车可用性、故障恢复和一致性诊断。
- 预约和本地鉴权域模型：预约创建/取消/过期/占用，Full/Differential 本地列表、版本检查和授权查询。
- `TimedChargingProfile` 时间语义：显式 epoch 有效期、Absolute/Relative、Daily/Weekly Recurring 和同 stack 替换。
- 显式 `ElectricalModel` A/W 换算：区分 DC、单相、三相线电压和三相相电压，并校验相数与功率因数。
- 稳定 `ChargePointSnapshot`：站点、交易、预约、本地鉴权和计时档位的 JSON 保存/恢复，含 v1 迁移和一致性校验。
- 无 I/O 的 `OcppTransport` 生命周期：连接代次、断线重连、指数退避、重试上限、出站队列与协议错误隔离。
- `GetDiagnostics` 与 `UpdateFirmware` 类型化消息：下载位置、重试策略、诊断文件名、检索时间和严格空确认。
- `TriggerMessage`、`ExtendedTriggerMessage` 与 `GetCompositeSchedule`：标准/扩展触发目标、可选连接器、复合计划状态和完整 `ChargingSchedule`。
- 完整 39 动作 OCPP 1.6 目录，包含方向、请求/确认必填字段和类型覆盖状态。
- 帧级一致性审计：检查未知动作、方向错误、非对象 payload 和缺失必填字段。
- 核心载荷的类型化解析和序列化：
  `BootNotification`、`Heartbeat`、`Authorize`、`StatusNotification`、
  `StartTransaction`、`StopTransaction`、`MeterValues`、
  `DiagnosticsStatusNotification`、`FirmwareStatusNotification`、
  `CancelReservation`、`ClearCache` 和 `UnlockConnector`。
- OCPP 注释中常见的状态、错误、停止原因和认证状态枚举。
- 单连接器交易状态机，不依赖隐式全局状态。
- `ChargingProfile`、`ChargingSchedule` 和周期校验。
- 按 `TxProfile > TxDefaultProfile` 和最高 stack level 选择活动档位，
  再应用 `ChargePointMaxProfile` 上限。
- 无网络 CLI，用于帧检查、一致性审计、动作方向与充电档位求值。
- 13 个可运行示例和跨后端 CI。

## 安装

```text
moon add ggbond44439/mooncharge@0.1.0
```

## 快速开始

```moonbit
let frame = match
  @mooncharge.parse_frame(
    "[2,\"req-1\",\"StartTransaction\",{\"connectorId\":1,\"idTag\":\"RFID-7\",\"meterStart\":12000,\"timestamp\":\"2026-11-18T08:00:00Z\"}]",
  ) {
  Ok(frame) => frame
  Err(error) => fail(error.message())
}

let request = match frame {
  @mooncharge.Call(_, _, payload) =>
    match @mooncharge.StartTransactionRequest::from_json(payload) {
      Ok(request) => request
      Err(error) => fail(error.message())
    }
  _ => fail("expected CALL")
}

assert_eq(request.connector_id, 1)
assert_eq(request.meter_start, 12000)
```

需要避免错误复用版本语义时，使用版本化入口：

```moonbit
let value = match
  @mooncharge.parse_versioned_frame(
    @mooncharge.OcppVersion::V16J,
    "[2,\"hb-1\",\"Heartbeat\",{}]",
  ) {
  Ok(value) => value
  Err(error) => fail(error.message())
}
```

## 交易状态机

```moonbit
let available = match @mooncharge.ConnectorSession::new(1) {
  Ok(value) => value
  Err(_) => fail("invalid connector")
}
let preparing = match available.begin_transaction(
  99,
  "RFID-7",
  12000,
  "2026-11-18T08:00:00Z",
) {
  Ok(value) => value
  Err(_) => fail("transaction did not start")
}
let charging = match preparing.begin_charging() {
  Ok(value) => value
  Err(_) => fail("charging did not start")
}
let finishing = match charging.finish_transaction(
  99,
  21000,
  "2026-11-18T09:00:00Z",
  Some(@mooncharge.StopReason::Local),
) {
  Ok(value) => value
  Err(_) => fail("transaction did not stop")
}
```

## 充电档位

`evaluate_charging_profiles` 使用调用方提供的 `elapsed_seconds`，按每个档位
自己的 `startPeriod` 计算。这样协议层不会隐式读取时钟，也不会绑定某个
IANA 时区实现。

选择顺序：

1. 优先匹配当前交易的 `TxProfile`；
2. 否则选择 `TxDefaultProfile`；
3. 同用途选择最高 `stackLevel`；
4. 最后用 `ChargePointMaxProfile` 截断结果；
5. A 与 W 不自动换算，单位不一致时返回 `RateUnitMismatch`。

## 连接生命周期

`OcppTransport` 不创建 socket、计时器或后台线程。调用方把连接事件交给状态机，
再执行返回的动作：

- `Open` 返回 `StartConnect`；
- `Opened` 返回带连接代次的 `TransportReady`；
- `TextReceived` 解析为 `VersionedFrame`，坏帧只返回 `ProtocolFailure`；
- `PeerClosed` 或 `OpenFailed` 返回带指数退避延迟的 `ScheduleReconnect`；
- 重试耗尽或 `LocalClose` 时返回 `CloseTransport` 与 `StopReconnect`。

`queue_frame` 只在已连接状态接受帧，`flush` 原子地取出待发送文本。短暂断线时
队列会保留，重连成功后可继续发送；关闭会清空队列，避免旧报文在重启后泄漏。

## CLI

```text
moon run cmd/main -- frame '[2,"req-1","Heartbeat",{}]'
# kind=call id=req-1 action=Heartbeat

moon run cmd/main -- version
# supported=1.6J known=1.6J,2.0.1

moon run cmd/main -- versioned 1.6J '[2,"hb-1","Heartbeat",{}]'
# version=1.6J kind=call id=hb-1 action=Heartbeat

moon run cmd/main -- action SetChargingProfile request
# central-system-to-charge-point

moon run cmd/main -- dispatch cp '[2,"auth-1","Authorize",{"idTag":"RFID-1"}]'
# typed=Authorize direction=charge-point-to-central-system

moon run cmd/main -- conformance summary
# actions=39 typed_requests=29 typed_responses=29 ...

moon run cmd/main -- conformance action StartTransaction
# action=StartTransaction direction=charge-point-to-central-system ...

moon run cmd/main -- conformance audit cp '[2,"start-1","StartTransaction",{"connectorId":1,"idTag":"RFID-1","meterStart":0,"timestamp":"2026-11-20T00:00:00Z"}]'
# passed=true action=StartTransaction

moon run cmd/main -- profile '<profile-json>' 120 42
# limit=22000 unit=W profile=8 capped=false
```

## 示例

```text
moon run examples/frame_roundtrip
moon run examples/session_walkthrough
moon run examples/profile_eval
moon run examples/conformance_audit
moon run examples/request_correlation
moon run examples/station_session
moon run examples/reservation_auth
moon run examples/timed_profile_eval
moon run examples/power_conversion
moon run examples/snapshot_roundtrip
moon run examples/transport_reconnect
moon run examples/firmware_diagnostics
moon run examples/trigger_schedule
```

## 明确不做

- 不创建 WebSocket/socket、计时器或后台线程；只提供确定性的连接与重连决策。
- 不实现 TLS、证书供应或具体网络栈。
- 不实现 OCPP 2.0.1 的完整消息集合；当前版本固定为 1.6J 核心。
- 不实现 Plug & Charge、PKI 信任链或计费结算。
- 不持久化交易与配置，不替调用方决定数据库事务边界。
- 不把 A 与 W 静默换算成同一单位。

这些边界使 MoonCharge 可以复用于 CSMS、充电桩固件模拟器、协议一致性测试
和离线数据集处理，而不会成为一个隐藏 I/O 的“大而全”网关。

## 构建与测试

```text
moon fmt --check
moon check --target all
moon test --target all
moon build
moon run examples/frame_roundtrip
moon run examples/session_walkthrough
moon run examples/profile_eval
moon run examples/conformance_audit
moon run examples/request_correlation
moon run examples/station_session
moon run examples/reservation_auth
moon run examples/timed_profile_eval
moon run examples/power_conversion
moon run examples/snapshot_roundtrip
moon run examples/transport_reconnect
moon run examples/firmware_diagnostics
moon run examples/trigger_schedule
moon package --list
```

当前测试覆盖 framing、错误码、动作方向、交易载荷、充电档位选择、连接器生命
周期、重连状态机和 CLI。

## 生态定位

MoonCharge 与以下作品功能不重合：

- `ggbond44439/moonloom`：Multiformats 内容寻址、CID 与 Multiaddr；
- `ggbond44439/moon_geocodec`：WKT/WKB/GeoJSON 几何交换；
- `ggbond44439/xbrlens`：XBRL 财报事实与计算关系；
- MoonCakes 当前已有的 HTTP、MQTT、CAN/DBC 和智能充电无关的通用 JSON 库。

MoonCharge 关注的是 OCPP 的充电域消息语义、交易不变量和功率策略。

更细的动作覆盖矩阵与边界见 [docs/coverage.md](docs/coverage.md)，版本变更见
[CHANGELOG.md](CHANGELOG.md)。

## License

Apache-2.0
