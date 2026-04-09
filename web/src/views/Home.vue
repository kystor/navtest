<template>
  <div class="home-container">

    <div class="bg-placeholder"></div>

    <video v-if="shouldShowVideo" class="bg-video" :class="{ 'fade-in': isBgLoaded }" :src="customBackground" autoplay loop muted playsinline webkit-playsinline preload="auto" ref="bgVideoRef" @canplay="onVideoCanPlay" @loadeddata="onVideoLoadedData" @error="onVideoError" @ended="onVideoEnded" :poster="transparentPixel"></video>
    <div v-if="shouldShowImage" class="bg-image" :class="{ 'fade-in': isBgLoaded }" :style="customBackground ? { backgroundImage: `url('${customBackground}')` } : {}"></div>
    <div v-if="needsInteraction && isBgLoaded" class="tap-to-play-hint" @click="forcePlay">轻触屏幕播放动态壁纸</div>

    <div class="content-overlay">
      <button class="theme-toggle-btn" @click="showThemeSettings = true" title="自定义专属壁纸">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path>
        </svg>
      </button>

      <div class="menu-bar-fixed"><MenuBar :menus="menus" :activeId="activeMenu?.id" :activeSubMenuId="activeSubMenu?.id" @select="selectMenu" /></div>

      <div class="search-section">
        <div class="search-box-wrapper">
          <div class="search-engine-select">
            <button v-for="engine in searchEngines" :key="engine.name" :class="['engine-btn', {active: selectedEngine.name === engine.name}]" @click="selectEngine(engine)">{{ engine.label }}</button>
          </div>
          <div class="search-container">
            <input v-model="searchQuery" type="text" :placeholder="selectedEngine.placeholder" class="search-input" @keyup.enter="handleSearch" enterkeyhint="search" autocomplete="off" />
            <button v-if="searchQuery" class="clear-btn" @click="clearSearch" aria-label="清空"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"></path></svg></button>
            <button @click="handleSearch" class="search-btn"><svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></button>
          </div>
        </div>
      </div>

      <div v-if="leftAds.length" class="ad-space-fixed left-ad-fixed"><a v-for="ad in leftAds" :key="ad.id" :href="ad.url" target="_blank"><img :src="ad.img" alt="" /></a></div>
      <div v-if="rightAds.length" class="ad-space-fixed right-ad-fixed"><a v-for="ad in rightAds" :key="ad.id" :href="ad.url" target="_blank"><img :src="ad.img" alt="" /></a></div>

      <CardGrid :cards="filteredCards"/>

      <footer class="footer">
        <div class="footer-content">
          <button @click="showFriendLinks = true" class="friend-link-btn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>友情链接</button>
          <p class="copyright">Copyright © 2025 Nav-Item | <a href="https://github.com/eooce/Nav-Item" target="_blank" class="footer-link">Powered by eooce</a></p>
        </div>
      </footer>
    </div>

    <div v-if="showThemeSettings" class="modal-overlay" @click="showThemeSettings = false">
      <div class="modal-content theme-modal modal-bottom-sheet" @click.stop>
        <div class="modal-header">
          <h3>个性化访客壁纸设置</h3>
          <button @click="showThemeSettings = false" class="close-btn"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"></path></svg></button>
        </div>
        <div class="modal-body">
          <div class="upload-tabs">
            <button @click="visitorMode = 'network'" :class="{active: visitorMode === 'network'}">网络链接</button>
            <button @click="visitorMode = 'local'" :class="{active: visitorMode === 'local'}">读取本地文件</button>
          </div>

          <div v-if="visitorMode === 'local'" class="tab-content">
            <p class="theme-desc">选择你电脑/手机里的图片或视频作为壁纸，只保存在你的浏览器中哦。</p>
            <input type="file" @change="handleVisitorLocalFile" accept="image/*,video/*" />
          </div>

          <div v-if="visitorMode === 'network'" class="tab-content">
            <p class="theme-desc">粘贴网络视频链接（.mp4）或图片链接。</p>
            <input v-model="visitorBgInput" type="text" placeholder="请输入网络链接..." class="theme-input" />
            <div class="type-selector">
              <button :class="['type-btn', { active: visitorBgType === 'auto' }]" @click="visitorBgType = 'auto'">🔄 自动</button>
              <button :class="['type-btn', { active: visitorBgType === 'video' }]" @click="visitorBgType = 'video'">🎬 视频</button>
              <button :class="['type-btn', { active: visitorBgType === 'image' }]" @click="visitorBgType = 'image'">🖼️ 图片</button>
            </div>
            <button class="btn save-theme-btn" style="width:100%; margin-top: 10px;" @click="saveVisitorTheme">保存并应用网络链接</button>
          </div>

          <div class="theme-actions" style="margin-top:15px;">
            <button class="btn clear-theme-btn" @click="clearVisitorTheme" style="width:100%">恢复全站默认壁纸</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import { getMenus, getCards, getAds, getFriends, getConfig, searchCards } from '../api';
import MenuBar from '../components/MenuBar.vue';
import CardGrid from '../components/CardGrid.vue';

const menus = ref([]);
const activeMenu = ref(null);
const activeSubMenu = ref(null);
const cards = ref([]);
const searchQuery = ref('');
const leftAds = ref([]);
const rightAds = ref([]);
const showFriendLinks = ref(false);
const friendLinks = ref([]);

const globalBackground = ref('');
const globalBgType = ref('auto');
const customBackground = ref('');
const customBgType = ref('auto');
const showThemeSettings = ref(false);

const visitorMode = ref('network'); // 默认访客模式
const visitorBgInput = ref('');
const visitorBgType = ref('auto');
const isBgLoaded = ref(false);
const bgVideoRef = ref(null);
const videoFailed = ref(false);
const needsInteraction = ref(false);

const transparentPixel = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

// 判断视频逻辑保持不变
function isVideoType(url, bgType) {
  if (bgType === 'video') return true;
  if (bgType === 'image') return false;
  if (!url) return false;
  const lower = url.toLowerCase();
  // 注意，Base64 数据需要看它的头部格式
  if (url.startsWith('data:video/')) return true;
  return lower.includes('.mp4') || lower.includes('.webm') || lower.includes('.ogg');
}

const isVideoBg = computed(() => isVideoType(customBackground.value, customBgType.value));
const shouldShowVideo = computed(() => isVideoBg.value && !videoFailed.value);
const shouldShowImage = computed(() => customBackground.value && !isVideoBg.value);

function onVideoCanPlay() { isBgLoaded.value = true; attemptPlay(); }
function onVideoLoadedData() { if (!isBgLoaded.value) { isBgLoaded.value = true; attemptPlay(); } }
function onVideoError() { videoFailed.value = true; isBgLoaded.value = true; }
function onVideoEnded() {
  const video = bgVideoRef.value;
  if (video) { video.currentTime = 0; const p = video.play(); if (p && p.catch) p.catch(() => videoFailed.value = true); }
}

function attemptPlay() {
  const video = bgVideoRef.value;
  if (!video) return;
  video.muted = true;
  const p = video.play();
  if (p && p.catch) p.catch(err => { if (err.name === 'NotAllowedError') needsInteraction.value = true; else videoFailed.value = true; });
}
function forcePlay() {
  const video = bgVideoRef.value;
  if (video) { video.muted = true; video.play().then(() => { needsInteraction.value = false; }).catch(() => { videoFailed.value = true; }); }
  needsInteraction.value = false;
}

watch(customBackground, (newUrl) => {
  videoFailed.value = false; needsInteraction.value = false;
  if (!newUrl) { isBgLoaded.value = true; return; }
  isBgLoaded.value = false;
  if (!isVideoBg.value) {
    const img = new Image(); img.src = newUrl;
    img.onload = () => { isBgLoaded.value = true; }; img.onerror = () => { isBgLoaded.value = true; };
  }
}, { immediate: true });

// --- 【新手必看】访客本地壁纸的 IndexedDB 核心逻辑 ---
// 为什么不用 localStorage？因为一张图片轻松几MB，localStorage 只能存5MB，很快就崩了
function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('VisitorThemeDB', 1);
    request.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('wallpapers')) db.createObjectStore('wallpapers', { keyPath: 'id' });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

// 访客选择本地文件事件
async function handleVisitorLocalFile(event) {
  const file = event.target.files[0];
  if (!file) return;

  const type = file.type.includes('video') ? 'video' : 'image';
  const reader = new FileReader();
  
  // 读成可以在浏览器里直接渲染的 DataURL (Base64)
  reader.readAsDataURL(file);
  reader.onload = async (e) => {
    const base64Data = e.target.result;
    
    // 打开数据库
    const db = await openDB();
    const tx = db.transaction('wallpapers', 'readwrite');
    const store = tx.objectStore('wallpapers');
    
    // 【核心需求满足】清空旧壁纸，避免缓存越来越大
    store.clear();
    
    // 存入新壁纸
    store.put({ id: 'current', data: base64Data, type: type });
    
    // 应用到当前界面
    customBackground.value = base64Data;
    customBgType.value = type;
    
    // 在普通缓存中做个标记，表示当前正在用本地缓存
    localStorage.setItem('visitor_use_local_db', 'true');
    showThemeSettings.value = false;
    alert("本地壁纸设置成功！");
  };
}

// 网页加载时，尝试读取缓存的壁纸
async function loadLocalWallpaper() {
  if (localStorage.getItem('visitor_use_local_db') === 'true') {
    try {
      const db = await openDB();
      const tx = db.transaction('wallpapers', 'readonly');
      const store = tx.objectStore('wallpapers');
      const request = store.get('current');
      request.onsuccess = () => {
        if (request.result) {
          customBackground.value = request.result.data;
          customBgType.value = request.result.type;
        }
      };
    } catch (err) { console.log('读取本地壁纸缓存失败', err); }
  } else {
    // 如果不是用的本地文件，那就去读正常的网络链接
    const localBg = localStorage.getItem('visitor_bg');
    const localBgType = localStorage.getItem('visitor_bg_type');
    if (localBg) { 
      customBackground.value = localBg; customBgType.value = localBgType || 'auto'; 
      visitorBgInput.value = localBg; visitorBgType.value = localBgType || 'auto'; 
    } else { 
      customBackground.value = globalBackground.value; customBgType.value = globalBgType.value; 
    }
  }
}

function saveVisitorTheme() {
  const url = visitorBgInput.value.trim();
  if (url) {
    localStorage.setItem('visitor_bg', url);
    localStorage.setItem('visitor_bg_type', visitorBgType.value);
    localStorage.removeItem('visitor_use_local_db'); // 取消本地缓存标记
    customBackground.value = url;
    customBgType.value = visitorBgType.value;
  } else { clearVisitorTheme(); }
  showThemeSettings.value = false;
}

function clearVisitorTheme() {
  localStorage.removeItem('visitor_bg'); 
  localStorage.removeItem('visitor_bg_type');
  localStorage.removeItem('visitor_use_local_db');
  // 同时清空 IndexedDB
  openDB().then(db => {
    const tx = db.transaction('wallpapers', 'readwrite');
    tx.objectStore('wallpapers').clear();
  });
  
  visitorBgInput.value = ''; visitorBgType.value = 'auto';
  customBackground.value = globalBackground.value; customBgType.value = globalBgType.value;
  showThemeSettings.value = false;
}

// ------ 以下为原来的搜索和菜单逻辑，未做改动 ------
const searchEngines = [
  { name: 'google', label: 'Google', placeholder: 'Google 搜索...', url: q => `https://www.google.com/search?q=${encodeURIComponent(q)}` },
  { name: 'baidu', label: '百度', placeholder: '百度搜索...', url: q => `https://www.baidu.com/s?wd=${encodeURIComponent(q)}` },
  { name: 'bing', label: 'Bing', placeholder: 'Bing 搜索...', url: q => `https://www.bing.com/search?q=${encodeURIComponent(q)}` },
  { name: 'github', label: 'GitHub', placeholder: 'GitHub 搜索...', url: q => `https://github.com/search?q=${encodeURIComponent(q)}&type=repositories` },
  { name: 'site', label: '站内', placeholder: '站内搜索...', url: q => q }
];
const selectedEngine = ref(searchEngines[0]);
function selectEngine(engine) { selectedEngine.value = engine; }
function clearSearch() { searchQuery.value = ''; if (!activeMenu.value && menus.value.length > 0) activeMenu.value = menus.value[0]; loadCards(); }
const filteredCards = computed(() => {
  if (!searchQuery.value) return cards.value;
  return cards.value.filter(c => c.title.toLowerCase().includes(searchQuery.value.toLowerCase()) || c.url.toLowerCase().includes(searchQuery.value.toLowerCase()) || (c.desc && c.desc.toLowerCase().includes(searchQuery.value.toLowerCase())));
});

onMounted(async () => {
  try {
    const configRes = await getConfig();
    if (configRes.data.background) globalBackground.value = configRes.data.background;
    if (configRes.data.bg_type) globalBgType.value = configRes.data.bg_type;
    if (configRes.data.title) document.title = configRes.data.title;
  } catch (e) { console.error('Failed to load config:', e); }
  
  // 重点：挂载时调用读取本地缓存的逻辑
  await loadLocalWallpaper();

  const res = await getMenus(); menus.value = res.data;
  if (menus.value.length) { activeMenu.value = menus.value[0]; loadCards(); }
  const adRes = await getAds(); leftAds.value = adRes.data.filter(ad => ad.position === 'left'); rightAds.value = adRes.data.filter(ad => ad.position === 'right');
  const friendRes = await getFriends(); friendLinks.value = friendRes.data;
});

async function selectMenu(menu, parentMenu = null) {
  if (parentMenu) { activeMenu.value = parentMenu; activeSubMenu.value = menu; } else { activeMenu.value = menu; activeSubMenu.value = null; }
  loadCards();
}
async function loadCards() { if (!activeMenu.value) return; const r = await getCards(activeMenu.value.id, activeSubMenu.value?.id); cards.value = r.data; }
async function handleSearch() {
  if (!searchQuery.value.trim()) return;
  if (selectedEngine.value.name === 'site') { try { const r = await searchCards(searchQuery.value.trim()); if (r.data.length > 0) { cards.value = r.data; activeMenu.value = null; activeSubMenu.value = null; } else alert('未找到相关内容'); } catch { alert('搜索时发生错误'); } }
  else window.open(selectedEngine.value.url(searchQuery.value), '_blank');
}
</script>

<style scoped>
/* 保持你的原来样式即可，增加少量针对选项卡的微调 */
.home-container { min-height: 100vh; min-height: 100dvh; position: relative; display: flex; flex-direction: column; }
.bg-placeholder { position: fixed; inset: 0; background: linear-gradient(135deg, #1a1c29, #2a2d3e); z-index: -1; }
.bg-image, .bg-video { opacity: 0; transition: opacity 1.2s ease-in-out; }
.fade-in { opacity: 1 !important; }
.bg-image { position: fixed; inset: 0; background-size: cover; background-position: center; background-repeat: no-repeat; z-index: 0; }
.bg-video { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; height: 100dvh; object-fit: cover; z-index: 0; }
.home-container::before { content: ''; position: fixed; inset: 0; background: rgba(0,0,0,0.3); z-index: 1; }
.content-overlay { position: relative; z-index: 2; flex: 1; display: flex; flex-direction: column; padding-top: 50px; }
.tap-to-play-hint { position: fixed; bottom: 120px; left: 50%; transform: translateX(-50%); z-index: 3; background: rgba(0,0,0,0.5); backdrop-filter: blur(8px); color: #fff; font-size: 12px; padding: 8px 16px; border-radius: 20px; cursor: pointer; }
.theme-toggle-btn { position: fixed; top: 16px; right: 16px; z-index: 101; background: rgba(255,255,255,0.15); backdrop-filter: blur(8px); border: 1px solid rgba(255,255,255,0.3); border-radius: 50%; width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; color: white; cursor: pointer; }
.menu-bar-fixed { position: fixed; top: .6rem; left: 0; width: 100vw; z-index: 100; }
.search-section { display: flex; flex-direction: column; align-items: center; padding: 1.5rem 0 2rem; z-index: 2; }
.search-box-wrapper { display: flex; flex-direction: column; align-items: center; width: 100%; max-width: 480px; padding: 0 12px; box-sizing: border-box; }
.search-container { display: flex; align-items: center; background: #b3b7b83b; border-radius: 20px; padding: 0.2rem; box-shadow: 0 4px 20px rgba(0,0,0,0.1); backdrop-filter: blur(10px); width: 92%; }
.search-input { flex: 1; border: none; background: transparent; padding: .1rem .5rem; font-size: 1rem; color: #fff; outline: none; }
.search-btn, .clear-btn { background: transparent; border: none; color: white; cursor: pointer; display: flex; align-items: center; justify-content: center; width: 36px; height: 36px;}
.footer { margin-top: auto; text-align: center; padding: 1rem 0 1.5rem; z-index: 2; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.7); display: flex; align-items: center; justify-content: center; z-index: 1000; backdrop-filter: blur(5px); }
.modal-content { background: #f8fafc; border-radius: 16px; width: 55rem; max-width: 95vw; max-height: 95vh; display: flex; flex-direction: column; overflow: hidden; }
.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 15px 20px; border-bottom: 1px solid #e5e7eb; background: #fff; }
.close-btn { background: none; border: none; cursor: pointer; padding: 8px; border-radius: 8px; color: #6b7280; }
.modal-body { flex: 1; padding: 16px; overflow-y: auto; }
.theme-modal { width: 420px !important; }
.upload-tabs { display: flex; gap: 10px; margin-bottom: 15px; }
.upload-tabs button { flex: 1; padding: 10px; border-radius: 8px; border: 1px solid #d0d7e2; background: #f8f9fa; cursor: pointer; font-weight: bold; }
.upload-tabs button.active { background: #2566d8; color: white; border-color: #2566d8; }
.tab-content { background: #fff; padding: 15px; border-radius: 8px; border: 1px dashed #d0d7e2; }
.theme-desc { font-size: 12px; color: #555; margin-bottom: 12px; line-height: 1.6; }
.theme-input { width: 100%; padding: 12px 16px; border-radius: 8px; border: 1px solid #cbd5e1; font-size: 14px; background: #fff; margin-bottom: 12px; box-sizing: border-box; }
.type-selector { display: flex; gap: 8px; margin-bottom: 10px; }
.type-btn { flex: 1; padding: 10px 8px; border-radius: 8px; border: 1px solid #cbd5e1; background: #fff; font-size: 12px; cursor: pointer; }
.type-btn.active { background: #2566d8; color: #fff; }
.btn { border-radius: 8px; padding: 12px; cursor: pointer; font-weight: 500; border: none; }
.save-theme-btn { background: #2566d8; color: white; }
.clear-theme-btn { background: #fee2e2; color: #ef4444; }
</style>
