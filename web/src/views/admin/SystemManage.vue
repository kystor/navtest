<template>
  <div class="system-manage">
    <div class="system-header">
      <h2 class="section-title">系统全局设置</h2>
      <span v-if="r2Status !== null" class="r2-badge" :class="r2Status ? 'on' : 'off'">{{ r2Status ? 'R2 同步已启用' : 'R2 未配置' }}</span>
    </div>
    <div class="system-card">
      <div class="form-group">
        <label>网站标题</label>
        <input v-model="siteTitle" class="input" placeholder="你的导航网站标题" />
      </div>

      <div class="form-group">
        <label>壁纸链接</label>
        <input v-model="bgUrl" class="input" :class="{'r2-url': isR2Url}" placeholder="视频/图片链接，留空恢复默认" readonly />
        <p v-if="isR2Url" class="r2-url-hint">R2 公网地址，所有容器自动同步</p>
      </div>

      <div class="form-group">
        <label>壁纸类型</label>
        <div class="type-selector">
          <button :class="['type-btn', { active: bgType === 'auto' }]" @click="bgType = 'auto'">自动</button>
          <button :class="['type-btn', { active: bgType === 'video' }]" @click="bgType = 'video'">视频</button>
          <button :class="['type-btn', { active: bgType === 'image' }]" @click="bgType = 'image'">图片</button>
        </div>
      </div>

      <button class="btn save-btn" @click="handleSave" :disabled="loading">{{ loading ? '保存中...' : '保存设置' }}</button>

      <!-- 上传壁纸: 拖拽上传区域 -->
      <div class="upload-section">
        <label class="upload-label">上传壁纸</label>
        <div
          class="drop-zone"
          :class="{ dragover: isDragOver, uploading: uploadState === 'uploading', error: uploadState === 'error', success: uploadState === 'success' }"
          @dragover.prevent="isDragOver = true"
          @dragleave="isDragOver = false"
          @drop.prevent="handleDrop"
          @click="$refs.adminFileInput.click()"
        >
          <input type="file" ref="adminFileInput" @change="handleFileSelect" accept="image/*,video/*,video/quicktime,.mov,.m4v,.avi,.mkv" class="file-input-hidden" />

          <!-- 默认状态 -->
          <div v-if="uploadState === 'idle'" class="drop-content">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5"><path d="M12 16V4m0 0l-4 4m4-4l4 4"/><path d="M4 20h16"/></svg>
            <span class="drop-main-text">点击选择或拖拽文件到此处</span>
            <span class="drop-sub-text">支持 MP4 / MOV / WebM / JPG / PNG / WebP / GIF</span>
          </div>

          <!-- 上传中 -->
          <div v-if="uploadState === 'uploading'" class="drop-content">
            <div class="progress-ring">
              <svg viewBox="0 0 36 36" class="progress-svg">
                <path class="progress-bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                <path class="progress-fill" :stroke-dasharray="`${uploadProgress}, 100`" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
              </svg>
              <span class="progress-text">{{ uploadProgress }}%</span>
            </div>
            <span class="drop-main-text">正在上传{{ r2Status ? '并同步到 R2' : '' }}...</span>
          </div>

          <!-- 成功 -->
          <div v-if="uploadState === 'success'" class="drop-content">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#059669" stroke-width="2"><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="10"/></svg>
            <span class="drop-main-text success-text">上传成功{{ uploadResult?.r2_synced ? ', R2 已同步' : '' }}</span>
            <span class="drop-sub-text">{{ uploadFileName }}</span>
          </div>

          <!-- 失败 -->
          <div v-if="uploadState === 'error'" class="drop-content">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#dc2626" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M15 9l-6 6M9 9l6 6"/></svg>
            <span class="drop-main-text error-text">{{ uploadError }}</span>
            <button class="retry-btn" @click.stop="retryUpload">重试</button>
          </div>
        </div>
        <p v-if="formatError" class="format-error">{{ formatError }}</p>
      </div>

      <!-- 缓存网络资源 -->
      <details class="advanced-section">
        <summary>缓存网络资源到服务器</summary>
        <div class="advanced-body">
          <p class="hint">下载网络图片/视频到{{ r2Status ? ' R2' : '本地' }}。</p>
          <input v-model="cacheUrl" class="input" placeholder="输入网络链接" />
          <button class="cache-btn" @click="handleCache" :disabled="!cacheUrl.trim()||caching">{{ caching ? '缓存中...' : '下载并缓存' }}</button>
          <div v-if="cacheResult" class="status-text success">缓存成功{{ cacheResult.r2_synced ? ', R2 已同步' : '' }}</div>
        </div>
      </details>

      <p v-if="message" :class="['message', messageType]">{{ message }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getConfig, updateConfig } from '../../api';

const siteTitle = ref(''); const bgUrl = ref(''); const bgType = ref('auto');
const loading = ref(false); const message = ref(''); const messageType = ref('success');
const cacheUrl = ref(''); const caching = ref(false); const cacheResult = ref(null);
const r2Status = ref(null); const r2Domain = ref('');

// 上传状态机: idle -> uploading -> success/error
const uploadState = ref('idle'); // idle | uploading | success | error
const uploadProgress = ref(0);
const uploadResult = ref(null);
const uploadError = ref('');
const uploadFileName = ref('');
const isDragOver = ref(false);
const formatError = ref('');
const adminFileInput = ref(null);
let lastFile = null; // 用于重试

const isR2Url = computed(() => r2Domain.value && bgUrl.value && bgUrl.value.startsWith(r2Domain.value));

// 格式校验
const ALLOWED_TYPES = /^(image\/(jpeg|png|gif|webp|bmp|svg\+xml)|video\/(mp4|webm|ogg|quicktime|x-m4v|x-msvideo|x-matroska))$/;
const ALLOWED_EXTS = /\.(jpg|jpeg|png|gif|webp|bmp|svg|mp4|webm|ogg|mov|m4v|avi|mkv)$/i;

function validateFile(file) {
  if (ALLOWED_TYPES.test(file.type)) return true;
  if (ALLOWED_EXTS.test(file.name)) return true;
  return false;
}

onMounted(async () => {
  try {
    const res = await getConfig();
    siteTitle.value = res.data.title || '';
    bgType.value = res.data.bg_type || 'auto';
    r2Status.value = res.data.r2_enabled || false;
    let url = res.data.background || '';
    if (url.includes('/api/background?url=')) url = decodeURIComponent(url.split('url=')[1]);
    bgUrl.value = url;
    if (r2Status.value) {
      try {
        const r2Res = await fetch('/api/r2/status', { headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token') } });
        const r2Data = await r2Res.json();
        r2Domain.value = r2Data.publicDomain || '';
      } catch(e) {}
    }
  } catch (err) { console.error('获取配置失败:', err); }
});

function handleFileSelect(event) {
  const file = event.target.files[0];
  if (file) doUpload(file);
}

function handleDrop(event) {
  isDragOver.value = false;
  const file = event.dataTransfer.files[0];
  if (file) doUpload(file);
}

function retryUpload() {
  if (lastFile) doUpload(lastFile);
}

async function doUpload(file) {
  formatError.value = '';
  if (!validateFile(file)) {
    formatError.value = `不支持的格式: .${file.name.split('.').pop()}。支持 JPG/PNG/GIF/WebP/MP4/MOV/WebM/AVI/MKV。`;
    return;
  }
  lastFile = file;
  uploadFileName.value = file.name;
  uploadState.value = 'uploading';
  uploadProgress.value = 0;
  uploadResult.value = null;
  uploadError.value = '';

  const formData = new FormData();
  formData.append('file', file);

  try {
    const xhr = new XMLHttpRequest();
    const result = await new Promise((resolve, reject) => {
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) uploadProgress.value = Math.round((e.loaded / e.total) * 100);
      });
      xhr.addEventListener('load', () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try { resolve(JSON.parse(xhr.responseText)); }
          catch { reject(new Error('响应解析失败')); }
        } else {
          try { const e = JSON.parse(xhr.responseText); reject(new Error(e.error || `HTTP ${xhr.status}`)); }
          catch { reject(new Error(`上传失败 (HTTP ${xhr.status})`)); }
        }
      });
      xhr.addEventListener('error', () => reject(new Error('网络错误，请检查连接')));
      xhr.addEventListener('timeout', () => reject(new Error('上传超时，请重试')));
      xhr.timeout = 120000;
      xhr.open('POST', '/api/upload?type=wallpaper');
      xhr.setRequestHeader('Authorization', 'Bearer ' + localStorage.getItem('token'));
      xhr.send(formData);
    });

    if (result.url) {
      bgUrl.value = result.url;
      bgType.value = result.type || (file.type.includes('video') || /\.(mov|m4v|avi|mkv)$/i.test(file.name) ? 'video' : 'image');
      uploadResult.value = result;
      uploadState.value = 'success';
      message.value = '上传成功，壁纸已更新！请保存设置确认标题和类型。';
      messageType.value = 'success';
      // 3秒后回到空闲状态
      setTimeout(() => { if (uploadState.value === 'success') uploadState.value = 'idle'; }, 3000);
    } else {
      throw new Error(result.error || '上传失败');
    }
  } catch (e) {
    uploadError.value = e.message;
    uploadState.value = 'error';
    message.value = '上传失败: ' + e.message;
    messageType.value = 'error';
  }
}

async function handleCache() {
  if (!cacheUrl.value.trim()) return;
  caching.value = true; cacheResult.value = null;
  try {
    const resp = await fetch('/api/upload/fetch-and-cache', { method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer '+localStorage.getItem('token')}, body:JSON.stringify({url:cacheUrl.value}) });
    const result = await resp.json();
    if (result.success) {
      bgUrl.value = result.url;
      bgType.value = result.recommended_type||result.type||'auto';
      cacheResult.value = result;
      message.value = '缓存成功，请保存设置'; messageType.value = 'success';
    } else throw new Error(result.error);
  } catch(e) { message.value = '缓存失败: '+e.message; messageType.value = 'error'; }
  finally { caching.value = false; }
}

async function handleSave() {
  loading.value = true; message.value = '';
  try {
    await updateConfig({ title: siteTitle.value, background: bgUrl.value, bg_type: bgType.value });
    message.value = '保存成功！'; messageType.value = 'success';
    if (siteTitle.value) document.title = siteTitle.value;
  } catch(err) { message.value = '保存失败: '+(err.response?.data?.error||err.message); messageType.value = 'error'; }
  finally { loading.value = false; setTimeout(()=>message.value='', 5000); }
}
</script>

<style scoped>
.system-manage { max-width: 1400px; width: 90%; margin: 0 auto; }
.system-header { margin-bottom: 20px; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
.section-title { font-size: 1.5rem; font-weight: bold; color: #2566d8; margin-top: 2rem; }
.r2-badge { font-size: 11px; padding: 3px 10px; border-radius: 20px; font-weight: 600; margin-top: 2rem; }
.r2-badge.on { background: #d1fae5; color: #065f46; } .r2-badge.off { background: #f3f4f6; color: #6b7280; }
.system-card { background: #fff; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,0.06); padding: 30px; max-width: 700px; }
.form-group { margin-bottom: 18px; }
.form-group label { display: block; margin-bottom: 6px; font-weight: 600; color: #222; font-size: 0.95rem; }
.input { width: 100%; padding: 10px 14px; border-radius: 8px; border: 1px solid #d0d7e2; font-size: 0.95rem; box-sizing: border-box; }
.input:focus { outline: 2px solid #2566d8; border-color: #2566d8; }
.input.r2-url { background: #f0fdf4; border-color: #86efac; color: #166534; }
.r2-url-hint { font-size: 0.78rem; color: #059669; margin-top: 4px; }
.type-selector { display: flex; gap: 8px; }
.type-btn { flex: 1; padding: 8px; border-radius: 8px; border: 1px solid #d0d7e2; background: #fff; color: #555; font-size: 13px; cursor: pointer; text-align: center; transition: 0.2s; }
.type-btn.active { background: #2566d8; color: #fff; border-color: #2566d8; }
.type-btn:hover:not(.active) { border-color: #2566d8; color: #2566d8; }
.save-btn { width: 100%; background: #2566d8; color: #fff; border: none; border-radius: 8px; padding: 12px; cursor: pointer; font-size: 1rem; font-weight: 600; margin-top: 4px; margin-bottom: 20px; }
.save-btn:hover:not(:disabled) { background: #174ea6; }

/* 上传区域 */
.upload-section { margin-bottom: 16px; }
.upload-label { display: block; margin-bottom: 8px; font-weight: 600; color: #222; font-size: 0.95rem; }
.drop-zone { border: 2px dashed #d0d7e2; border-radius: 12px; padding: 28px 16px; text-align: center; cursor: pointer; transition: all 0.25s ease; position: relative; background: #fafbfc; }
.drop-zone:hover { border-color: #93c5fd; background: #f0f7ff; }
.drop-zone.dragover { border-color: #2566d8; background: rgba(37,102,216,0.06); transform: scale(1.01); }
.drop-zone.uploading { border-color: #f59e0b; border-style: solid; background: #fffbeb; cursor: default; }
.drop-zone.success { border-color: #059669; border-style: solid; background: #f0fdf4; }
.drop-zone.error { border-color: #dc2626; border-style: solid; background: #fef2f2; }
.file-input-hidden { position: absolute; inset: 0; opacity: 0; cursor: pointer; z-index: 1; }
.drop-zone.uploading .file-input-hidden, .drop-zone.error .file-input-hidden { pointer-events: none; }
.drop-content { display: flex; flex-direction: column; align-items: center; gap: 6px; pointer-events: none; }
.drop-main-text { font-size: 14px; color: #64748b; font-weight: 500; }
.drop-sub-text { font-size: 11px; color: #94a3b8; }
.success-text { color: #059669; }
.error-text { color: #dc2626; }
.format-error { font-size: 12px; color: #dc2626; margin-top: 6px; padding: 6px 10px; background: #fef2f2; border-radius: 6px; }

/* 进度环 */
.progress-ring { width: 48px; height: 48px; position: relative; }
.progress-svg { width: 100%; height: 100%; transform: rotate(-90deg); }
.progress-bg { fill: none; stroke: #e5e7eb; stroke-width: 3; }
.progress-fill { fill: none; stroke: #2566d8; stroke-width: 3; stroke-linecap: round; transition: stroke-dasharray 0.3s ease; }
.progress-text { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 600; color: #2566d8; }

/* 重试按钮 */
.retry-btn { pointer-events: auto; margin-top: 4px; padding: 6px 16px; border-radius: 6px; border: 1px solid #dc2626; background: #fff; color: #dc2626; font-size: 12px; font-weight: 500; cursor: pointer; transition: 0.2s; z-index: 2; }
.retry-btn:hover { background: #dc2626; color: #fff; }

.advanced-section { margin-bottom: 12px; border: 1px solid #e5e7eb; border-radius: 8px; }
.advanced-section summary { padding: 10px 14px; cursor: pointer; font-size: 0.9rem; color: #6b7280; font-weight: 500; }
.advanced-section summary:hover { color: #2566d8; }
.advanced-body { padding: 12px 14px 14px; border-top: 1px solid #f3f4f6; }
.hint { font-size: 0.82rem; color: #888; margin-bottom: 8px; }
.cache-btn { width: 100%; padding: 8px; border-radius: 8px; border: 1px solid #d0d7e2; background: #f8f9fa; color: #555; font-size: 13px; cursor: pointer; margin-top: 6px; }
.cache-btn:hover:not(:disabled) { background: #e2e8f0; } .cache-btn:disabled { opacity: 0.5; }
.status-text { font-size: 0.82rem; margin-top: 6px; } .status-text.success { color: #059669; }
.message { margin-top: 12px; padding: 10px; border-radius: 8px; font-size: 0.9rem; text-align: center; }
.message.success { background: #d4edda; color: #155724; } .message.error { background: #f8d7da; color: #721c24; }
@media (max-width: 768px) { .system-manage { width: 100%; padding: 0 4vw; } }
</style>
