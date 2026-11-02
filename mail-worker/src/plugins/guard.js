import app from '../hono/hono';
import BizError from '../error/biz-error';
import { t } from '../i18n/i18n';
import permService from '../service/perm-service';

/**
 * 插件区统一守卫
 *
 * /notify/* 与 /migration/* 属于系统级配置（含 Bot Token、Webhook 地址等），
 * 只允许管理员或拥有 setting:set 权限的角色访问。
 *
 * 注意：必须在插件路由文件之前被 import —— Hono 的 app.use 要先于 app.get/post 注册。
 */
async function requireAdminOrSettingPerm(c, next) {
	const user = c.get('user');
	if (!user) {
		throw new BizError(t('authExpired'), 401);
	}
	if (user.email === c.env.admin) {
		return next();
	}
	const keys = await permService.userPermKeys(c, user.userId);
	if (keys.includes('setting:set')) {
		return next();
	}
	throw new BizError(t('unauthorized'), 403);
}

app.use('/notify/*', requireAdminOrSettingPerm);
app.use('/migration/*', requireAdminOrSettingPerm);

export { requireAdminOrSettingPerm };
