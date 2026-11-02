<template>
  <div class="fork-notify">
          <div class="settings-card">
            <div class="card-title">{{ $t('notifySystem') }}</div>
            <div class="card-content">
              <div class="setting-item">
                <div>
                  <span>{{ $t('manualMigration') }}</span>
                  <el-tooltip effect="dark" :content="$t('migrateEmailDesc')">
                    <Icon class="warning" icon="fe:warning" width="18" height="18"/>
                  </el-tooltip>
                </div>
                <div>
                  <el-button class="opt-button" size="small" type="primary" :loading="migrationLoading" @click="startMigration">
                    <Icon icon="material-symbols:upload-rounded" width="16" height="16"/>
                  </el-button>
                </div>
              </div>
              <div v-for="chType in notifyChannelTypes" :key="chType.type" class="notify-channel-group">
                <div class="setting-item">
                  <div><span>{{ $t(chType.label) }}</span></div>
                  <div class="forward">
                    <el-button class="opt-button" size="small" type="primary" @click="openAddNotifyDialog(chType.type)">
                      <Icon icon="material-symbols:add-rounded" width="16" height="16"/>
                    </el-button>
                    <span v-if="!notifyRulesByType(chType.type).length" class="no-instances">{{ $t('noNotifyInstance') }}</span>
                  </div>
                </div>
                <div v-if="notifyRulesByType(chType.type).length" class="notify-instance-list">
                  <div v-for="rule in notifyRulesByType(chType.type)" :key="rule.id" class="notify-instance-item">
                    <div class="notify-instance-name" @click="openEditNotifyDialog(rule)">{{ rule.name || $t('defaultInstanceName') }}</div>
                    <div class="notify-instance-actions">
                      <el-switch :model-value="rule.enabled" :active-value="1" :inactive-value="0" @change="toggleNotifyInstance(rule)"/>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

  <!-- 通知系统弹窗 -->
       <!-- 通知系统弹窗 -->
       <el-dialog v-model="notifyShow" class="forward-dialog">
         <template #header>
           <span class="forward-set-title">{{ notifyDialogTitle }}</span>
         </template>
         <div class="forward-set-body">
           <el-input :placeholder="$t('notifyInstanceName')" v-model="notifyForm.name" style="margin-bottom: 15px"/>

           <!-- Webhook 专用 UI -->
           <template v-if="notifyForm.type === 'webhook'">
             <el-input :placeholder="$t('webhookUrl')" v-model="notifyForm.url" style="margin-bottom:15px"/>
             <el-select v-model="notifyForm.method" style="width:100%;margin-bottom:15px" :placeholder="$t('webhookMethod')">
               <template #prefix><span style="font-size:13px;color:#606266">{{ $t('webhookMethod') }}</span></template>
               <el-option value="POST" label="POST"/>
               <el-option value="GET" label="GET"/>
             </el-select>

             <!-- Content-Type -->
             <div class="kv-section">
               <div class="kv-header">
                 <span>Content-Type</span>
               </div>
               <el-select
                 v-model="webhookContentType"
                 filterable
                 allow-create
                 clearable
                 default-first-option
                 style="width:100%;margin-bottom:15px"
                 placeholder="Content-Type"
               >
                 <el-option value="application/json" label="application/json"/>
                 <el-option value="form-data" label="multipart/form-data"/>
                 <el-option value="text/plain" label="text/plain"/>
                 <el-option value="application/x-www-form-urlencoded" label="application/x-www-form-urlencoded"/>
               </el-select>
             </div>

             <!-- Headers -->
             <div class="kv-section">
               <div class="kv-header">
                 <span>Headers</span>
                 <el-button size="small" @click="addWebhookHeader" circle>
                   <Icon icon="material-symbols:add-rounded" width="16" height="16"/>
                 </el-button>
               </div>
               <div v-for="(item, idx) in webhookHeaders" :key="idx" class="kv-row">
                 <el-input v-model="item.key" placeholder="Key" style="flex: 1"/>
                 <span class="kv-colon">:</span>
                 <el-input v-model="item.value" placeholder="Value" style="flex: 1"/>
                 <el-button type="danger" circle size="small" @click="removeWebhookHeader(idx)">
                   <Icon icon="material-symbols:delete-outline-rounded" width="16" height="16"/>
                 </el-button>
               </div>
             </div>

             <!-- Body -->
             <div v-if="webhookContentType !== 'form-data'" class="kv-section">
               <div class="kv-header">
                 <span>Body</span>
               </div>
               <textarea
                 :value="webhookBodyRaw"
                 @input="webhookBodyRaw = $event.target.value"
                 placeholder='{"key":"value"}'
                 rows="4"
                 style="width:100%;min-height:80px;max-height:300px;resize:vertical;padding:5px 11px;border:1px solid #dcdfe6;border-radius:4px;font-family:monospace;font-size:13px;margin-bottom:5px"
               />
               <div v-pre style="color:#909399;font-size:12px;margin-bottom:15px">可用变量: message, subject, from, to, toAddress, content, timestamp（使用双花括号包裹变量，如：{{message}}）</div>
             </div>
           </template>

           <!-- 其他 provider 走通用 schema -->
           <template v-else v-for="field in currentTypeSchema.fields" :key="field.key">
             <el-input
               v-if="field.type === 'input'"
               :placeholder="field.desc ? $t(field.label) + ' (' + $t(field.desc) + ')' : $t(field.label)"
               v-model="notifyForm[field.key]"
               style="margin-bottom:15px"
             />
             <el-input
               v-else-if="field.type === 'textarea'"
               type="textarea"
               :rows="3"
               :placeholder="field.desc ? $t(field.label) + ' (' + $t(field.desc) + ')' : $t(field.label)"
               v-model="notifyForm[field.key]"
               style="margin-bottom:15px"
             />
             <el-select
               v-else-if="field.type === 'select'"
               v-model="notifyForm[field.key]"
               style="width:100%;margin-bottom:15px"
               :placeholder="$t(field.label)"
             >
               <template #prefix><span style="font-size:13px;color:#606266">{{ $t(field.label) }}</span></template>
               <el-option
                 v-for="opt in field.options"
                 :key="opt.value"
                 :value="opt.value"
                 :label="$t(opt.label)"
               />
             </el-select>
             <div v-else-if="field.type === 'switch'" class="tg-msg-label" style="margin-bottom:15px">
               <span>{{ $t(field.label) }}</span>
               <el-switch v-model="notifyForm[field.key]" :active-value="true" :inactive-value="false"/>
             </div>
           </template>
         </div>
         <template #footer>
           <div class="dialog-footer">
             <div>
               <el-button v-if="notifyForm.id" type="danger" @click="deleteNotifyFromDialog">{{ $t('delete') }}</el-button>
             </div>
             <div>
               <el-switch v-model="notifyForm.enabled" :active-value="1" :inactive-value="0" style="margin-right: 10px"/>
               <el-button @click="previewNotifyConfig">{{ $t('preview') }}</el-button>
               <el-button :loading="loadingTest" @click="testNotify()">{{ $t('test') }}</el-button>
               <el-button :loading="loadingNotify" type="primary" @click="saveNotifyForm">{{ $t('save') }}</el-button>
             </div>
           </div>
         </template>
       </el-dialog>

       <el-dialog v-model="previewShow" title="Config Preview" width="600px">
         <pre class="config-preview">{{ previewContent }}</pre>
       </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { ElMessage, ElMessageBox } from 'element-plus'
import { notifyTypes, notifyList, notifyAdd, notifySet, notifyDelete, notifyTest, notifyTestPreview } from '@/plugins/notify.js'
import { migrationStart } from '@/plugins/migration.js'
// 注册本地的文案与语言包（不改动上游 i18n 文件）
import '@/i18n/fork/index.js'

defineOptions({ name: 'fork-notify-settings' })

const { t } = useI18n()
const emit = defineEmits(['refresh'])

// 新通知系统
const notifyRuleList = ref([])
const notifyShow = ref(false)
const notifyForm = reactive({ id: 0, type: '', name: '', enabled: 1 })
const notifyChannelTypes = ref([])
const loadingTest = ref(false)
const loadingNotify = ref(false)
const previewShow = ref(false)
const previewContent = ref('')
const webhookHeaders = ref([])
const webhookBodyRaw = ref('')
const webhookContentType = ref('')
const migrationLoading = ref(false)

const notifyDialogTitle = computed(() => {
  const schema = currentTypeSchema.value
  const base = schema.label ? t(schema.label) : 'Notify'
  return notifyForm.id ? `${t('editInstance')} ${base}` : `${t('addNew')} ${base}`
})

const currentTypeSchema = computed(() => {
  return notifyChannelTypes.value.find(t => t.type === notifyForm.type) || { fields: [] }
})

function notifyRulesByType(type) {
  return notifyRuleList.value.filter(r => r.type === type)
}

function kvEmpty() { return { key: '', value: '' } }
function addWebhookHeader() { webhookHeaders.value.push(kvEmpty()) }
function removeWebhookHeader(i) { webhookHeaders.value.splice(i, 1) }
function kvArrayToObj(arr) {
  const obj = {}
  for (const item of arr) {
    if (item.key) obj[item.key] = item.value
  }
  return obj
}
function objToKvArray(obj) {
  if (!obj || typeof obj !== 'object') return []
  return Object.entries(obj).map(([key, value]) => ({ key, value: String(value) }))
}

async function getNotifyRules() {
  try {
    const [types, list] = await Promise.all([notifyTypes(), notifyList()])
    notifyChannelTypes.value = types
    notifyRuleList.value = list
  } catch {}
}

function resetNotifyForm(data) {
  for (const key of Object.keys(notifyForm)) {
    if (!['id', 'type', 'name', 'enabled'].includes(key)) {
      delete notifyForm[key]
    }
  }
  Object.assign(notifyForm, data)
}

function openAddNotifyDialog(type) {
  const schema = notifyChannelTypes.value.find(t => t.type === type)
  const defaults = { id: 0, type, name: '', enabled: 1 }
  for (const field of (schema?.fields || [])) {
    defaults[field.key] = field.default !== undefined ? field.default : (field.type === 'switch' ? false : '')
  }
  resetNotifyForm(defaults)
  if (type === 'webhook') {
    webhookHeaders.value = [kvEmpty()]
    webhookBodyRaw.value = ''
    webhookContentType.value = ''
  }
  notifyShow.value = true
}

function openEditNotifyDialog(rule) {
  const schema = notifyChannelTypes.value.find(t => t.type === rule.type)
  const form = { id: rule.id, type: rule.type, name: rule.name || '', enabled: rule.enabled }
  const config = JSON.parse(rule.config)
  for (const field of (schema?.fields || [])) {
    form[field.key] = config[field.key] ?? (field.default !== undefined ? field.default : (field.type === 'switch' ? false : ''))
  }
  resetNotifyForm(form)
  if (rule.type === 'webhook') {
    webhookHeaders.value = objToKvArray(config.headers)
    webhookBodyRaw.value = typeof config.bodyTemplate === 'string' ? config.bodyTemplate : (config.bodyTemplate ? JSON.stringify(config.bodyTemplate, null, 2) : '')
    const ctMap = { 'json': 'application/json', 'form-data': 'form-data', 'custom': '' }
    webhookContentType.value = ctMap[config.contentType] ?? (config.contentType || '')
    if (!webhookHeaders.value.length) webhookHeaders.value = [kvEmpty()]
  }
  notifyShow.value = true
}

function toggleNotifyInstance(rule) {
  notifySet({ id: rule.id, enabled: rule.enabled ? 0 : 1 }).then(() => getNotifyRules())
}


function deleteNotifyFromDialog() {
  ElMessageBox.confirm(t('delNotifyInstanceConfirm'), {
    confirmButtonText: t('confirm'),
    cancelButtonText: t('cancel'),
    type: 'warning'
  }).then(() => {
    notifyDelete(notifyForm.id).then(() => {
      ElMessage({ message: t('delSuccessMsg'), type: 'success', plain: true })
      notifyShow.value = false
      getNotifyRules()
    })
  })
}

function saveNotify(rule) {
  loadingNotify.value = true
  const save = rule.id ? notifySet(rule) : notifyAdd(rule)
  save.then(() => {
    ElMessage({ message: t('saveSuccessMsg'), type: 'success', plain: true })
    notifyShow.value = false
    getNotifyRules()
  }).finally(() => { loadingNotify.value = false })
}

function saveNotifyForm() {
  const config = buildNotifyConfig()
  saveNotify({ id: notifyForm.id, type: notifyForm.type, name: notifyForm.name, config, enabled: notifyForm.enabled })
}

function buildNotifyConfig() {
  if (notifyForm.type === 'webhook') {
    const config = {
      url: notifyForm.url || '',
      method: notifyForm.method || 'POST',
    }
    if (webhookContentType.value) {
      config.contentType = webhookContentType.value
    }
    config.headers = kvArrayToObj(webhookHeaders.value)
    if (webhookBodyRaw.value) {
      try { config.bodyTemplate = JSON.parse(webhookBodyRaw.value) } catch { config.bodyTemplate = {} }
    } else {
      config.bodyTemplate = {}
    }
    return config
  }
  const config = {}
  const fields = currentTypeSchema.value.fields || []
  for (const field of fields) {
    const value = notifyForm[field.key]
    if (value !== undefined && value !== '') {
      config[field.key] = value
    }
  }
  return config
}

async function testNotify() {
  loadingTest.value = true
  try {
    const config = buildNotifyConfig()
    const res = await notifyTestPreview(notifyForm.type, config)
    const results = res.data || res
    const first = Array.isArray(results) ? results[0] : results
    if (first && first.success) {
      ElMessage({ message: t('testSuccess'), type: 'success', plain: true })
    } else {
      ElMessage({ message: first?.error || t('testFailed'), type: 'error', plain: true })
    }
  } catch {
    ElMessage({ message: t('testFailed'), type: 'error', plain: true })
  } finally {
    loadingTest.value = false
  }
}

function previewNotifyConfig() {
  const config = buildNotifyConfig()
  previewContent.value = JSON.stringify(config, null, 2)
  previewShow.value = true
}

async function startMigration() {
  if (migrationLoading.value) return
  migrationLoading.value = true
  try {
    await migrationStart()
    ElMessage({ message: t('migrateSuccessMsg').replace('{count}', '0'), type: 'success', plain: true })
    emit('refresh')
  } catch (e) {
    ElMessage({ message: e.message || t('testFailed'), type: 'error', plain: true })
  } finally {
    migrationLoading.value = false
  }
}

function getNotifyDialogTitle() {
  const schema = currentTypeSchema.value
  const base = schema.label ? t(schema.label) : 'Notify'
  return notifyForm.id ? `${t('editInstance')} ${base}` : `${t('addNew')} ${base}`
}

watch(webhookContentType, (val) => {
  const idx = webhookHeaders.value.findIndex(h => h.key.toLowerCase() === 'content-type')
  if (val) {
    if (idx >= 0) {
      webhookHeaders.value[idx].value = val
    } else {
      webhookHeaders.value.unshift({ key: 'Content-Type', value: val })
    }
  } else {
    if (idx >= 0) webhookHeaders.value.splice(idx, 1)
  }
})

// 新通知系统 end
onMounted(() => {
  getNotifyRules()
})
</script>

<style scoped lang="scss">
/* 卡片基础样式：与父页面保持一致，组件自带以便脱离父页面 scoped 样式 */
.settings-card {
  background-color: var(--el-bg-color);
  border-radius: 6px;
  border: 1px solid var(--el-border-color);
  transition: all 300ms;
  overflow: hidden;
  max-width: 900px;
  width: 100%;
}

.card-title {
  font-size: 15px;
  font-weight: bold;
  padding: 15px 20px 12px;
  border-bottom: 1px solid var(--el-border-color);
}

.card-content {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.setting-item {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 10px;
  font-weight: normal;

  > div:first-child {
    display: flex;
    align-items: center;
    gap: 5px;
  }

  > div:last-child {
    display: grid;
    grid-template-columns: 1fr auto;
    justify-items: flex-end;
    font-weight: normal;
  }
}

.opt-button {
  width: fit-content !important;
}

.warning {
  margin-left: 2px;
  color: grey;
  cursor: pointer;
}

/* 弹窗样式 */
:deep(.forward-dialog.el-dialog) {
  width: 500px !important;
  @media (max-width: 540px) {
    width: calc(100% - 40px) !important;
    margin-right: 20px !important;
    margin-left: 20px !important;
  }
}

.forward-set-title {
  font-size: 16px;
  font-weight: bold;
}

.forward-set-body {
  display: flex;
  flex-direction: column;

  > *:nth-child(-n+2) {
    margin-bottom: 15px;
  }
}

.tg-msg-label {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.dialog-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.kv-section {
  margin-bottom: 15px;
}

.kv-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
  font-size: 13px;
  font-weight: 500;
  color: #606266;
}

.kv-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 8px;
}

.kv-colon {
  color: #909399;
  flex-shrink: 0;
}

.config-preview {
  background: #f5f5f5;
  border: 1px solid #e4e7ed;
  border-radius: 4px;
  padding: 12px;
  font-size: 12px;
  font-family: monospace;
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 500px;
  overflow-y: auto;
  margin: 0;
}

.notify-channel-group {
  border-bottom: 1px solid var(--el-border-color-lighter);
  padding-bottom: 10px;
  margin-bottom: 5px;
  &:last-child {
    border-bottom: none;
    margin-bottom: 0;
    padding-bottom: 0;
  }
}

.notify-instance-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-left: 10px;
  margin-top: 4px;
}

.notify-instance-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  border-radius: 6px;
  background: var(--el-fill-color-lighter);
  transition: background 200ms;
  &:hover {
    background: var(--el-fill-color);
  }
}

.notify-instance-name {
  cursor: pointer;
  &:hover {
    color: var(--el-color-primary);
  }
}

.no-instances {
  color: var(--el-text-color-placeholder);
  font-size: 13px;
}

:deep(.el-select__wrapper) {
  min-height: 28px;
}
</style>
