/**
 * 插件注册入口（fork 自有目录，不修改上游核心文件）
 *
 * 顺序要求：守卫必须最先注册，再注册插件路由
 * —— Hono 的 app.use 需先于 app.get/post 注册才会生效。
 */

// 权限守卫（/notify/*、/migration/* 仅管理员或 setting:set 权限可用）
import './guard.js'

// 通知系统（含 DB 懒建表 + API 路由）
import './notification/index.js'

// 迁移系统（含 API 路由）
import './migration/index.js'
