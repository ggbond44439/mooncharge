# MoonCharge 项目申报书

## 基本信息

- **项目名称：** MoonCharge：面向电动汽车充电设施的 MoonBit OCPP 1.6J 协议核心
- **参赛者：** 岑浩森（MoonCakes / GitHub：`ggbond44439`）
- **GitHub 仓库：** <https://github.com/ggbond44439/mooncharge>
- **项目方向：** Web、网络基础设施与能源设备互操作
- **项目类型：** 原创实现；依据公开 OCPP 1.6 规范，不移植现有代码
- **许可证：** Apache-2.0

## 痛点与生态位

OCPP 是充电桩与充电站管理系统之间的主流开放协议。MoonBit 已有通用
HTTP/WebSocket、JSON、MQTT、CAN/DBC 与工业协议基础，但截至 2026-11-18，
MoonCakes 检索 `ocpp`、`evse`、`csms`、`ocpp16` 均为 0 个模块。仅依赖通用
JSON 库无法处理 OCPP 的帧类型、消息方向、交易不变量和多个充电档位的优先级。

MoonCharge 填补的是“纯协议与业务语义”层，不重做网络栈：它接收已经解出的文本
帧，返回类型化消息或稳定错误；发送端再把结果交给任意 WebSocket 传输。

## 三个使用场景

1. **CSMS 后端接入：** 解析充电桩上报的启动、状态、计量和停止消息，维护每个
   连接器的交易状态，并在响应前校验字段。
2. **充电桩固件模拟：** 在没有任何硬件的情况下回放 OCPP 会话，验证重复启动、
   错误交易号、计量回退和停止原因。
3. **协议与充电策略测试：** 对一组 `TxProfile`、`TxDefaultProfile` 和
   `ChargePointMaxProfile` 计算指定时刻的有效功率上限，检查单位冲突和 stack
   level 选择。

## 核心交付

- 解析和编码 OCPP JSON-RPC `CALL`、`CALLRESULT`、`CALLERROR`；
- 识别消息 id、动作、请求/确认方向及 OCPP 错误码；
- 类型化处理 `BootNotification`、`Heartbeat`、`Authorize`、
  `StatusNotification`、`StartTransaction`、`StopTransaction`、`MeterValues`；
- 单连接器交易状态机，拒绝重复交易、交易号不匹配和电量回退；
- 解析充电档位与周期，验证周期顺序和持续时间；
- 以交易档位优先、最高 stack level 优先的规则计算有效充电上限；
- CLI、3 个可运行示例、跨后端测试和 CI。

## 技术路线

协议层保持 sans-I/O。JSON 使用 MoonBit 核心库并开启数字原文保留；所有公开
解码函数返回 `Result`，枚举字段 fail-closed，资源上限和 JSON 嵌套深度在入口
处限制。充电档位求值使用调用方提供的相对秒数，避免把时区和时钟藏进协议库。
状态机采用不可变值更新，错误类型区分重复交易、无活动交易、交易号不匹配和
计量回退，便于单元测试与审计。

## 边界与不重复说明

本项目不做 WebSocket/TLS、证书供应、持久化、计费结算和完整 OCPP 2.0.1。
MoonCharge 与本人已有的 MoonLoom（Multiformats）、MoonGeoCodec（空间几何）、
XBRLens（XBRL 财报）在标准、数据模型和用户场景上均不同；实时 MoonCakes
检索也未发现 OCPP 或 EVSE 协议包。

## 验收目标

- `moon fmt --check`、`moon check --target all`、`moon test --target all` 通过；
- 3 个示例可运行，CLI 可独立检查帧、方向和充电档位；
- README 给出安装、API、CLI、范围和限制；
- 发布到 MoonCakes 后版本接口与测试结果可复现。
