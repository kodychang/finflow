# GomiKit

日本垃圾分类助手 App 的 Web MVP 原型，基于 PRD v1.1 搭建。

## 已覆盖的 MVP 功能

- 东京 23 区示例地区切换：涩谷区、新宿区、港区
- 今日垃圾显示与收集日信息
- 垃圾分类搜索与别名匹配
- 垃圾处理步骤：清洗、标签、瓶盖、指定袋、时间、地点、危险提示
- 前一天 21:00 多语言提醒的界面状态
- 官方来源与更新时间展示
- 房东 / 店家 QR 页面预览
- 资料管理列表与「使用」后的加入提示
- A4 海报与照片上传入口的产品占位
- AI 官方资料获取流程与垃圾文化小知识

## 技术栈

- React
- Vite
- lucide-react
- qrcode.react

## 本地运行

```bash
npm install
npm run dev
```

公开 QR 页面示例：

- `/q/shibuya-guest`
- `/q/shibuya-shop`
- `/q/shibuya-multi`

## 后续实现建议

1. 增加 Node.js 后端、PostgreSQL 表结构和官方来源抓取任务。
2. 接入 Firebase Cloud Messaging 做真实提醒。
3. 将 A4 海报 PDF 生成功能接到 QR 页面。
4. 在第二阶段加入图片识别与大型垃圾预约说明。

## 开发文档

- [API contract](docs/api-contract.md)
- [PostgreSQL schema](docs/schema.sql)
