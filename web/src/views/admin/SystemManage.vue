<template>
  <div class="system-manage">
    <div class="system-header"><h2 class="section-title">系统全局设置</h2></div>
    <div class="system-card">
      <div class="form-group">
        <label>网站浏览器标题：</label>
        <input v-model="siteTitle" class="input" placeholder="请输入你的专属导航网站标题" />
      </div>

      <div class="form-group">
        <label>壁纸设置方式：</label>
        <div class="upload-tabs">
          <button @click="uploadMode = 'local'" :class="{active: uploadMode === 'local'}">📂 传本地文件</button>
          <button @click="uploadMode = 'network'" :class="{active: uploadMode === 'network'}">🌐 用网络链接</button>
        </div>
      </div>

      <div v-if="uploadMode === 'local'" class="tab-content local-upload-box">
        <input type="file" ref="fileInput" @change="handleFileUpload" accept="image/*,video/*" />
        <p class="hint">文件将上传至云存储，多台服务器完美同步显示。</p>
        <div v-if="uploading" class="loading-text">正在上传到服务器，请稍候...</div>
      </div>

      <div v-if="uploadMode === 'network'" class="tab-content network-upload-box">
        <input v-model="networkUrl" class="input" placeholder="请输入网络视频或图片链接" />
        <button class="detect-btn" @click="handleCacheNetwork" :disabled="!networkUrl.trim() || caching">
          {{ caching ? '正在下载并同步至云存储...' : '⬇️ 自动下载并缓存到服务器' }}
        </button>
      </div>

      <div class="form-group current-bg-info">
        <label>当前待保存的壁纸链接 (管理员有最终决定权)：</label>
        <input v-model="bgUrl" class="input disabled-input" placeholder="请在上方操作后自动生成" />
      </div>

      <div class="form-group">
        <label>确认壁纸类型：</label>
        <div class="type-selector">
          <button :class="['type-btn', { active: bgType === 'auto' }]" @click="bgType = 'auto'">🔄 自动</button>
          <button :class="['type-btn', { active: bgType === 'video' }]" @click="bgType = 'video'">🎬 视频</button>
          <button :class="['type-btn', { active: bgType === 'image' }]" @click="bgType = 'image'">🖼️ 图片</button>
        </div>
      </div>

      <button class="btn save-btn" @click="handleSave" :disabled="loading">{{ loading ? '保存中...' : '保存全局设置' }}</button>
      <p v-if="message" :class="['message', messageType]">{{ message }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { getConfig, updateConfig } from '../../api';

// 【新手讲解】在 Vue 中使用 ref 定义页面的各种状态
const siteTitle = ref('');
const bgUrl = ref('');
const bgType = ref('auto');
const loading = ref(false);
const message = ref('');
const messageType = ref('success');

// 新增的交互状态变量
const uploadMode = ref('local'); 
const fileInput = ref(null);
const uploading = ref(false);
const networkUrl = ref('');
const caching = ref(false);

onMounted(async () => {
  try {
    const res = await getConfig();
    siteTitle.value = res.data.title || '';
    bgType.value = res.data.bg_type || 'auto';
    let url = res.data.background || '';
    if (url.includes('/api/background?url=')) url = decodeURIComponent(url.split('url=')[1]);
    bgUrl.value = url;
  } catch (err) { console.error('获取配置失败:', err); }
});

// 【功能 1】处理本地文件上传，调用修改后的 /api/upload
async function handleFileUpload(event) {
  const file = event.target.files[0];
  if (!file) return;
  uploading.value = true;
  
  const formData = new FormData();
  formData.append('file', file); // 把文件打包

  try {
    // 调用原生 fetch 去请求我们的后端接口
    const response = await fetch('/api/upload', {
      method: 'POST',
      body: formData,
      headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token') } // 带着管理员权限
    });
    const result = await response.json();
    if (result.url) {
      bgUrl.value = result.url; // 获取后端返回的 R2 公网链接
      // 帮管理员智能推断一下类型
      bgType.value = file.type.includes('video') ? 'video' : 'image';
      message.value = '文件上传成功，请点击【保存全局设置】';
      messageType.value = 'success';
    } else {
      throw new Error(result.error || '上传失败');
    }
  } catch (error) {
    message.value = '上传报错: ' + error.message;
    messageType.value = 'error';
  } finally {
    uploading.value = false;
  }
}

// 【功能 2】处理网络链接缓存，调用新增的 /fetch-and-cache
async function handleCacheNetwork() {
  if (!networkUrl.value.trim()) return;
  caching.value = true;
  message.value = '';
  try {
    const response = await fetch('/api/upload/fetch-and-cache', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + localStorage.getItem('token')
      },
      body: JSON.stringify({ url: networkUrl.value })
    });
    const result = await response.json();
    if (result.success) {
      bgUrl.value = result.url; // 获取缓存后的 R2 链接
      bgType.value = result.type; // 后端自动推断出的类型
      message.value = '网络资源缓存成功，请点击【保存全局设置】';
      messageType.value = 'success';
    } else {
      throw new Error(result.error);
    }
  } catch (error) {
    message.value = '缓存失败，您可以直接把链接复制到下方输入框保存尝试。错误: ' + error.message;
    messageType.value = 'error';
  } finally {
    caching.value = false;
  }
}

// 保存最终到数据库
async function handleSave() {
  loading.value = true; message.value = '';
  try {
    await updateConfig({ title: siteTitle.value, background: bgUrl.value, bg_type: bgType.value });
    message.value = '设置保存成功！快去首页刷新看看效果吧！';
    messageType.value = 'success';
    if (siteTitle.value) document.title = siteTitle.value;
  } catch (err) {
    message.value = '保存失败：' + (err.response?.data?.error || err.message);
    messageType.value = 'error';
  } finally { loading.value = false; setTimeout(() => message.value = '', 5000); }
}
</script>

<style scoped>
/* 样式部分保持你原来的风格，增加了几个按钮的样式 */
.system-manage { max-width: 1400px; width: 90%; margin: 0 auto; }
.system-header { margin-bottom: 20px; }
.section-title { font-size: 1.5rem; font-weight: bold; color: #2566d8; margin-top: 2rem; }
.system-card { background: #fff; border-radius: 12px; box-shadow: 0 2px 12px rgba(0,0,0,0.06); padding: 30px; max-width: 800px; }
.form-group { margin-bottom: 20px; }
.form-group label { display: block; margin-bottom: 10px; font-weight: bold; color: #222; font-size: 1.1rem; }
.input { width: 100%; padding: 12px 16px; border-radius: 8px; border: 1px solid #d0d7e2; font-size: 1rem; box-sizing: border-box; margin-bottom: 10px; }
.input:focus { outline: 2px solid #2566d8; border-color: #2566d8; }
.upload-tabs { display: flex; gap: 10px; margin-bottom: 15px; }
.upload-tabs button { flex: 1; padding: 12px; border-radius: 8px; border: 1px solid #d0d7e2; background: #f8f9fa; cursor: pointer; font-weight: bold; transition: 0.2s; }
.upload-tabs button.active { background: #2566d8; color: white; border-color: #2566d8; }
.tab-content { background: #f8f9fa; padding: 20px; border-radius: 8px; border: 1px dashed #d0d7e2; margin-bottom: 20px; }
.hint { font-size: 0.9rem; color: #666; margin-top: 10px; }
.loading-text { color: #e67e22; font-weight: bold; margin-top: 10px; }
.type-selector { display: flex; gap: 10px; }
.type-btn { flex: 1; padding: 10px; border-radius: 8px; border: 1px solid #d0d7e2; background: #fff; color: #555; font-size: 14px; cursor: pointer; text-align: center; transition: all 0.2s; }
.type-btn.active { background: #2566d8; color: #fff; border-color: #2566d8; }
.detect-btn { width: 100%; padding: 10px; border-radius: 8px; border: 1px solid #d0d7e2; background: #e0f2fe; color: #0369a1; font-weight: bold; font-size: 14px; cursor: pointer; margin-top: 10px; }
.save-btn { width: 100%; background: #2566d8; color: #fff; border: none; border-radius: 8px; padding: 14px 24px; cursor: pointer; font-size: 1.1rem; font-weight: bold; margin-top: 10px; }
.message { margin-top: 15px; padding: 12px; border-radius: 8px; font-weight: bold; text-align: center; }
.message.success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.message.error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
.disabled-input { background-color: #e9ecef; cursor: not-allowed; }
</style>
