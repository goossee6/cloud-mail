/**
 * fork 自有文案注册（不改动上游 i18n 词条文件）
 *
 * 做法：模块加载时把通知系统的词条 merge 进 i18n 实例，
 * 这样 en.js / zh.js 可以始终保持与上游一致，合并上游时不会冲突。
 */
import i18n from '@/i18n/index.js';
import zh from './notify.zh.js';
import en from './notify.en.js';

const messages = { zh, en };

for (const [locale, msgs] of Object.entries(messages)) {
	i18n.global.mergeLocaleMessage(locale, msgs);
}

export default messages;
