/**
 * 通知系统入口
 * 职责：路由注册 + 统一分发入口（新规则 + 旧版 TG Bot 兼容）
 */

// 路由注册（Hono 路由在 import 时生效）
import './notify-api.js'

// 导出核心函数供外部调用
import { Notification } from './notification.js'
import { settingConst } from '../../const/entity-const';
import telegramService from '../../service/telegram-service';

/**
 * 发送通知的入口函数
 *
 * @param env        Worker 环境
 * @param emailRow   邮件记录
 * @param legacy     上游旧版配置（tgBotStatus / tgChatId），用于兼容 TG Bot
 */
export async function dispatchNotification(env, emailRow, legacy) {
	await sendLegacyTelegram(env, emailRow, legacy);
	return Notification.sendAll(env, emailRow);
}

/**
 * 兼容上游「TG Bot 转发」开关
 *
 * 若已经配置了 telegram 类型的通知规则，则交给新链路，避免同一条邮件推两次。
 */
async function sendLegacyTelegram(env, emailRow, legacy) {
	if (!legacy || legacy.tgBotStatus !== settingConst.tgBotStatus.OPEN || !legacy.tgChatId) {
		return;
	}

	try {
		const rules = await Notification.list(env);
		if (rules.some(rule => rule.type === 'telegram' && rule.enabled)) {
			return;
		}
		await telegramService.sendEmailToBot({ env }, emailRow);
	} catch (e) {
		console.error('[Notification] legacy telegram failed:', e.message);
	}
}
