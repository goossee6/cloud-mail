> [!IMPORTANT]
> This project is a fork of [maillab/cloud-mail](https://github.com/maillab/cloud-mail) with the following changes:
>
> - **Plugin-based Notification System**: Added support for WeCom, DingTalk, Feishu, OneBot, Telegram, and Webhook notifications with custom Headers, Body template variables, and Content-Type
> - **Email Auto-Matching**: One-click email matching to corresponding mailboxes
> - **Plugin Architecture**: Notification and migration systems use plugin-based design, with only 4 lines of changes to core files for easy upstream sync

<p align="center">
    <img src="doc/demo/logo.png" width="80px" />
    <h1 align="center">Cloud Mail</h1>
    <p align="center">An all-in-one email service platform powered by Cloudflare</p>
    <p align="center">
        <a href="https://www.cloudflare.com/" target="_blank">
            <img src="https://img.shields.io/badge/Cloudflare-F38020?labelColor=F38020&amp;color=F38020&amp;logo=cloudflare&amp;logoColor=white" alt="Cloudflare" />
        </a>
        <a href="https://github.com/maillab/cloud-mail/releases" target="_blank" >
            <img src="https://img.shields.io/github/v/release/maillab/cloud-mail?logo=github&amp;logoColor=white" alt="releases" />
        </a>
        <a href="https://github.com/maillab/cloud-mail/tree/main?tab=MIT-1-ov-file" target="_blank" >
            <img src="https://img.shields.io/badge/license-MIT-green" />
        </a>
    </p>
    <p align="center">
        <a href="https://skymail.ink">Live Demo</a> · <a href="https://docs.skymail.ink/en/">Deployment Guide</a> ·
        <a href="/README.md">简体中文</a> | English
    </p>
    <p align="center">
        <a href="https://trendshift.io/repositories/20459" target="_blank" >
            <img src="https://trendshift.io/api/badge/repositories/20459" alt="trendshift" >
        </a>
        <a href="https://hellogithub.com/repository/1b1da1f9ae4c4175baa3d762b4e0ba41" target="_blank">
            <img src="https://api.hellogithub.com/v1/widgets/recommend.svg?rid=1b1da1f9ae4c4175baa3d762b4e0ba41" alt="HelloGitHub" />
        </a>
    </p>
</p>

## Description
With only one domain, you can create multiple different email addresses, similar to major email platforms. This project can be deployed on Cloudflare Workers to reduce server costs and build your own email service.
## Project Showcase

| ![](/doc/demo/en/demo.jpg)  | ![](/doc/demo/en/demo1.jpg) |
|-----------------------------|-----------------------------|
| ![](/doc/demo/en/demo2.jpg) | ![](/doc/demo/en/demo3.jpg) |

## Recommended Project

<table>
  <tr>
    <td valign="middle">
      <a href="https://github.com/pixtalelab/pixtale">
        <img width="30" src="https://img.022335.xyz/logo.png" alt="Pixtale" align="middle">
      </a>
    </td>
    <td valign="middle">
      <a href="https://github.com/pixtalelab/pixtale">Pixtale</a>
    </td>
    <td valign="middle">
      A self-hosted cloud storage photo album app
    </td>
  </tr>
</table>

## Features

- **💰 Low-Cost Usage**: No server required — deploy to Cloudflare Workers to reduce costs.

- **💻 Responsive Design**: Automatically adapts to both desktop and most mobile browsers.

- **📧 Email Sending**: Integrated with Cloudflare Email and Resend for sending email.

- **🛡️ Admin Features**: Admin controls for user and email management with RBAC-based access control.

- **📦 Attachment Support**: Send and receive attachments, stored and downloaded via R2 object storage.

- **🔔 Email Push**: Forward received emails to Telegram bots or other email providers.

- **🎯 Email Auto-Matching**: One-click matching of historical emails to the corresponding mailbox.

- **📡 Open API**: Supports batch user creation via API and multi-condition email queries

- **🔢 Verification Code Recognition**: Auto-detect codes via Workers AI

- **📈 Data Visualization**: Use ECharts to visualize system data, including user email growth.

- **🎨 Personalization**: Customize website title, login background, and transparency.

- **🤖 CAPTCHA**: Integrated with Turnstile CAPTCHA to prevent automated registration.

- **📜 More Features**: Under development...

## Recent Updates

### Bug Fixes (2026-08)

- **Notification System**: Fixed `this.renderTemplate is not a function` error for WeCom/DingTalk/Feishu, moved `renderTemplate` method to base class
- **Notification UI**: Removed delete and edit buttons from instance list, click instance name to enter edit interface
- **Webhook**: Fixed `config.body` field name mismatch, unified to `config.bodyTemplate`
- **Webhook**: Fixed form-data condition check error
- **Webhook**: Fixed `{{message}}` template variable rendering undefined issue
- **Webhook**: GET request now sends simple fields only, prevents URL truncation
- **Telegram**: HTML mode now properly escapes user content
- **Telegram**: `messageThreadId` now correctly converted to integer
- **Notification System**: `maxContentLength` now correctly converted to number
- **Notification System**: Optimized recipient parsing logic to avoid duplicate JSON.parse
- **Email Receiving**: Fixed `email.attachments` null TypeError
- **API**: Fixed `JSON.parse(rule.config)` missing try/catch causing 500 error
- **API**: Added JSON parse error handling to DELETE endpoint

### New Features

- **Unit Tests**: Added `buildMessage` and `formatMessage` core logic tests (12 test cases)
- **Plugin Architecture**: Notification and migration systems use plugin-based design, only 4 lines of changes to core files

## New Features in This Fork

### Notification System

Plugin-based architecture supporting 6 notification channels:

- [x] WeCom (Enterprise WeChat) - [How to get Webhook URL](https://cloud.tencent.com/document/product/1759/128391)
- [x] DingTalk - [How to get Webhook URL](https://open.dingtalk.com/document/robots/custom-robot-access)
- [x] Feishu (Lark) - [How to get Webhook URL](https://open.feishu.cn/document/client-docs/bot-v3/add-custom-bot)
- [x] OneBot (QQ) - Supports reverse WebSocket
- [x] Telegram - Supports HTML/Markdown format
- [x] Webhook - Custom Headers, Body template, Content-Type

### Environment Variables

| Variable                | Required | Description                                                 |
| ----------------------- | -------- | ----------------------------------------------------------- |
| `domain`                | ✅       | Email domains array, e.g. `["example.com"]`                 |
| `admin`                 | ✅       | Admin email address                                         |
| `jwt_secret`            | ✅       | JWT signing secret (security sensitive)                     |
| `NOTIFIERS`             | ❌       | Comma-separated notification channels, default: all enabled |
| `TIMEZONE`              | ❌       | Notification timestamp timezone, default: `Asia/Shanghai`   |
| `ai_model`              | ❌       | AI model, default: `@cf/meta/llama-3.1-8b-instruct-fast`    |
| `analysis_cache`        | ❌       | Analysis data cache toggle, default: `false`                |
| `orm_log`               | ❌       | SQL log toggle, default: `false`                            |
| `project_link`          | ❌       | Show project link, default: `true`                          |
| `linuxdo_switch`        | ❌       | LinuxDo OAuth toggle, default: `false`                      |
| `linuxdo_client_id`     | ❌       | LinuxDo OAuth client ID                                     |
| `linuxdo_client_secret` | ❌       | LinuxDo OAuth client secret                                 |

## Tech Stack

- **Platform**: [Cloudflare Workers](https://developers.cloudflare.com/workers/)

- **Web Framework**: [Hono](https://hono.dev/)

- **ORM**: [Drizzle](https://orm.drizzle.team/)

- **Frontend Framework**: [Vue3](https://vuejs.org/)

- **UI Framework**: [Element Plus](https://element-plus.org/)

- **Email Sending**: [Cloudflare Email](https://developers.cloudflare.com/email-service/) / [Resend](https://resend.com/)

- **Cache**: [Cloudflare KV](https://developers.cloudflare.com/kv/)

- **Database**: [Cloudflare D1](https://developers.cloudflare.com/d1/)

- **File Storage**: [Cloudflare R2](https://developers.cloudflare.com/r2/)

## Project Structure

```
cloud-mail
├── mail-worker                    # Backend worker project
│   ├── src
│   │   ├── api                    # API layer
│   │   ├── const                  # Project constants
│   │   ├── dao                    # Data access layer
│   │   ├── email                  # Email processing and handling
│   │   ├── entity                 # Database entities
│   │   ├── error                  # Custom exceptions
│   │   ├── hono                   # Web framework, middleware, error handling
│   │   ├── i18n                   # Internationalization
│   │   ├── init                   # Database and cache initialization
│   │   ├── model                  # Response data models
│   │   ├── plugins                # Plugin directory (notification, migration)
│   │   ├── security               # Authentication and authorization
│   │   ├── service                # Business logic layer
│   │   ├── template               # Message templates
│   │   ├── utils                  # Utility functions
│   │   └── index.js               # Entry point
│   ├── package.json               # Project dependencies
│   └── wrangler.toml              # Project configuration
│
├── mail-vue                       # Frontend Vue project
│   ├── src
│   │   ├── axios                  # Axios configuration
│   │   ├── components             # Custom components
│   │   ├── echarts                # ECharts integration
│   │   ├── i18n                   # Internationalization
│   │   ├── init                   # Startup initialization
│   │   ├── layout                 # Main layout components
│   │   ├── perm                   # Permissions and access control
│   │   ├── plugins                # Plugin request modules
│   │   ├── request                # API request layer
│   │   ├── router                 # Router configuration
│   │   ├── store                  # Global state management
│   │   ├── utils                  # Utility functions
│   │   ├── views                  # Page components
│   │   ├── app.vue                # Root component
│   │   ├── main.js                # Entry JS file
│   │   └── style.css              # Global styles
│   ├── package.json               # Project dependencies
└── └── env.release                # Environment configuration

```

## Development

```bash
# Clone the project
git clone https://github.com/yinleren6/cloud-mail.git
cd cloud-mail

# Install dependencies
cd mail-worker && pnpm install
cd ../mail-vue && pnpm install

# Run tests
cd mail-worker && pnpm run test:unit

# Local development
cd mail-worker && pnpm run dev
```

## Syncing Upstream

```bash
# Fetch upstream changes
git fetch upstream
git checkout main
git merge upstream/main

# Merge updates into patched branch
git checkout patched
git merge main
```

## Deployment

### Environment Variable Configuration

There are two ways to configure environment variables:

#### Option 1: Modify wrangler.toml (Recommended)

Uncomment and fill in the corresponding values in `mail-worker/wrangler.toml`:

```toml
[vars]
domain = ["your-domain.com"]          # Email domains
admin = "admin@your-domain.com"       # Admin email
jwt_secret = "your-jwt-secret"        # JWT secret

# Notification System (optional)
NOTIFIERS = "telegram,webhook"        # Enabled notification channels, comma-separated
TIMEZONE = "Asia/Shanghai"            # Notification timestamp timezone
```

优点：只需设置一次，每次部署自动生效。

#### Option 2: Cloudflare Dashboard

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to Workers & Pages → Select your Worker
3. In Settings → Variables and Secrets, add variables
4. Deploy using wrangler command:
   ```bash
   cd mail-worker
   wrangler deploy
   ```

优点：无需修改代码，适合临时调整。
缺点：每次重新部署后需要在 Dashboard 重新设置变量。

### Notification System Configuration

Notification channels are configured through the web interface after deployment, no code changes needed:

1. Access your app → System Settings → Notification System
2. Click the `+` button on the corresponding channel to add an instance
3. Fill in the Webhook URL and other configuration details
4. Click the test button to verify the configuration

### GitHub Action Deployment

See [.github/workflows/deploy-fork.yml](.github/workflows/deploy-fork.yml)

## Sponsor

<a href="https://cn3.top/blog/sponsor/" >
<img width="170px" src="./doc/images/support.png" alt="">
</a>

## License

This project is licensed under the [MIT](LICENSE) license.

## Upstream

This project is a fork of [maillab/cloud-mail](https://github.com/maillab/cloud-mail).

## Communication

[Telegram](https://t.me/cloud_mail_tg)
