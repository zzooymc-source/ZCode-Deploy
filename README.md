# ZCode-Deploy

ZCode 越狱工具 — 一键把 system prompt 整层换成你自己的越狱词。

## 这是什么

一个针对 ZCode 的 system prompt 破甲工具。

ZCode 的 system prompt 由 `zcode.cjs` 内部的 `build()` 函数拼装，包含产品身份声明（"You are ZCode"）、安全策略、上下文管理规则、日期提醒等注入内容。本工具修改四个注入点，把整个 system 层替换为 `人格.txt` 的内容 —— 你的越狱词直接成为唯一的 system prompt。

部署后模型收到的请求：

```
system:   人格.txt（你的越狱词）← 唯一
messages: 正常对话
tools:    工具定义（不变）

❌ 没有 "You are ZCode"
❌ 没有产品安全策略
❌ 没有上下文管理规则
❌ 没有日期提醒
```

`人格.txt` 就是越狱词文件。把你的越狱 prompt 全文写进去，部署后它就是 system 层的全部内容。

## 使用

仓库自带一份 45K 的实测人格词 —— clone 下来直接用，开箱即破。

1. （可选）把 `人格.txt` 换成你自己的越狱词（UTF-8）
2. 双击 `部署.bat`
3. 开新对话，生效

命令行方式：

```powershell
# 部署
powershell -ExecutionPolicy Bypass -File deploy.ps1 install

# 恢复原版
powershell -ExecutionPolicy Bypass -File deploy.ps1 restore

# 查看状态
powershell -ExecutionPolicy Bypass -File deploy.ps1 status
```

## 换越狱词

直接编辑 `人格.txt`，保存，开新对话生效。不需要重启，不需要重跑部署。

## 原理

对 `zcode.cjs` 做四个补丁：

| # | 修改点 | 作用 |
|---|--------|------|
| 1 | `Djo` 前缀置空 | 删除 "You are ZCode" 身份声明 |
| 2 | `build()` 读外部文件 | system prompt 改为读 `人格.txt` |
| 3 | `Eut()` 读外部文件 | Agent Identity 片段同步替换为越狱词 |
| 4 | `fre()` 返回 null | 移除日期提醒注入 |

完整技术分析见 `修改记录.md`。

## 验证

部署是否生效，看 ZCode 的模型请求日志：

```
~/.zcode/cli/rollout/model-io-*.jsonl
```

检查 system 层是否为人格.txt 全文、无产品注入内容。

## 注意

- ZCode 更新后补丁会被覆盖，重跑 `部署.bat` 即可
- 文件夹移动位置后需要重跑 `部署.bat`（路径写死在 cjs 里）
- `恢复.bat` 还原原版代码，但保留 `人格.txt`
- 仅修改本地安装的软件，不触碰服务端

## 免责声明

本工具仅用于修改本地安装的软件配置。请遵守 ZCode 服务条款，自行承担使用风险。
