<template>
  <div class="home-container">
    <div class="bg-placeholder"></div>
    <video v-if="shouldShowVideo" class="bg-video" :class="{ 'fade-in': isBgLoaded }" :src="customBackground" autoplay loop muted playsinline webkit-playsinline preload="auto" ref="bgVideoRef" @canplay="onVideoCanPlay" @loadeddata="onVideoLoadedData" @error="onVideoError" @ended="onVideoEnded" :poster="transparentPixel"></video>
    <img v-show="false" ref="bgImageRef" crossorigin="anonymous" />
    <div v-if="shouldShowImage" class="bg-image" :class="{ 'fade-in': isBgLoaded }" :style="customBackground ? { backgroundImage: `url('${customBackground}')` } : {}"></div>
    
    <!-- 已删除轻触屏幕提示 -->

    <div class="content-overlay">
      <button class="theme-toggle-btn" @click="showThemeSettings = true" title="自定义壁纸">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>
      </button>
      
      <div class="search-section">
        
        <img :src="currentLogoSrc" alt="八方来财 Logo" class="home-logo" />

        <MenuBar :menus="menus" :activeId="activeMenu?.id" :activeSubMenuId="activeSubMenu?.id" @select="selectMenu" />

        <div class="search-box-wrapper">
          <div class="search-engine-select"><button v-for="engine in searchEngines" :key="engine.name" :class="['engine-btn',{active:selectedEngine.name===engine.name}]" @click="selectEngine(engine)">{{engine.label}}</button></div>
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
      <footer class="footer"><div class="footer-content">
        <button @click="showFriendLinks = true" class="friend-link-btn"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>友情链接</button>
        <p class="copyright">Copyright 2025 Nav-Item | <a href="https://github.com/eooce/Nav-Item" target="_blank" class="footer-link">Powered by eooce</a></p>
      </div></footer>
    </div>

    <div v-if="showFriendLinks" class="modal-overlay" @click="showFriendLinks = false">
      <div class="modal-content modal-bottom-sheet" @click.stop>
        <div class="modal-header"><h3>友情链接</h3><button @click="showFriendLinks = false" class="close-btn"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"></path></svg></button></div>
        <div class="modal-body"><div class="friend-links-grid">
          <a v-for="friend in friendLinks" :key="friend.id" :href="friend.url" target="_blank" class="friend-link-card">
            <div class="friend-link-logo"><img v-if="friend.logo" :src="friend.logo" :alt="friend.title" @error="handleLogoError" /><div v-else class="friend-link-placeholder">{{friend.title.charAt(0)}}</div></div>
            <div class="friend-link-info"><h4>{{friend.title}}</h4></div>
          </a>
        </div></div>
      </div>
    </div>

    <div v-if="showThemeSettings" class="modal-overlay" @click="showThemeSettings = false">
      <div class="modal-content theme-modal modal-bottom-sheet" @click.stop>
        <div class="modal-header"><h3>个性化壁纸设置</h3><button @click="showThemeSettings = false" class="close-btn"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"></path></svg></button></div>
        <div class="modal-body">
          <div class="upload-tabs">
            <button @click="visitorMode='local'" :class="{active:visitorMode==='local'}">本地图片/视频</button>
            <button @click="visitorMode='network'" :class="{active:visitorMode==='network'}">网络链接</button>
          </div>
          <div v-if="visitorMode==='local'" class="tab-content">
            <p class="theme-desc">选择或拖拽图片/视频文件，支持 MP4/MOV/WebM/JPG/PNG/WebP/GIF 等格式。</p>
            <div class="drop-zone" :class="{dragover:isDragOver}" @dragover.prevent="isDragOver=true" @dragleave="isDragOver=false" @drop.prevent="handleDrop">
              <input type="file" @change="handleVisitorLocalFile" accept="image/*,video/*,video/quicktime,.mov,.m4v" class="file-input" ref="fileInputRef" />
              <div class="drop-hint" @click="$refs.fileInputRef.click()">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M12 16V4m0 0l-4 4m4-4l4 4M4 20h16"/></svg>
                <span>{{ localFileName || '点击选择或拖拽文件到此处' }}</span>
              </div>
            </div>
            <p v-if="formatError" class="format-error">{{ formatError }}</p>
          </div>
          <div v-if="visitorMode==='network'" class="tab-content">
            <p class="theme-desc">粘贴视频(.mp4/.mov/.webm)或图片链接。</p>
            <input v-model="visitorBgInput" type="text" placeholder="请输入链接" class="theme-input" />
            <div class="type-selector">
              <button :class="['type-btn',{active:visitorBgType==='auto'}]" @click="visitorBgType='auto'">自动</button>
              <button :class="['type-btn',{active:visitorBgType==='video'}]" @click="visitorBgType='video'">视频</button>
              <button :class="['type-btn',{active:visitorBgType==='image'}]" @click="visitorBgType='image'">图片</button>
            </div>
          </div>
          <div class="theme-actions">
            <button class="btn clear-theme-btn" @click="clearVisitorTheme">恢复默认</button>
            <button v-if="visitorMode==='network'" class="btn save-theme-btn" @click="saveVisitorTheme">保存并应用</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, watch, nextTick } from 'vue';
import { getMenus, getCards, getAds, getFriends, getConfig, searchCards } from '../api';
import MenuBar from '../components/MenuBar.vue';
import CardGrid from '../components/CardGrid.vue';

const menus = ref([]); const activeMenu = ref(null); const activeSubMenu = ref(null);
const cards = ref([]); const searchQuery = ref('');
const leftAds = ref([]); const rightAds = ref([]); const showFriendLinks = ref(false); const friendLinks = ref([]);
const globalBackground = ref(''); const globalBgType = ref('auto');
const customBackground = ref(''); const customBgType = ref('auto');
const showThemeSettings = ref(false); const visitorMode = ref('local');
const visitorBgInput = ref(''); const visitorBgType = ref('auto');
const isBgLoaded = ref(false); const bgVideoRef = ref(null); const bgImageRef = ref(null);
const videoFailed = ref(false); const needsInteraction = ref(false);
const isDragOver = ref(false); const localFileName = ref('');
const fileInputRef = ref(null); const formatError = ref('');
const transparentPixel = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

const logoType = ref('white'); 
const currentLogoSrc = computed(() => `/${logoType.value}.png`);

function analyzeBrightness(sourceElement) {
  try {
    const canvas = document.createElement('canvas');
    canvas.width = 64; 
    canvas.height = 64;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(sourceElement, 0, 0, 64, 64);
    
    const data = ctx.getImageData(0, 0, 64, 64).data;
    let r = 0, g = 0, b = 0, count = 0;
    
    for(let i = 0; i < data.length; i += 4) {
      if(data[i+3] > 0) {
        r += data[i]; g += data[i+1]; b += data[i+2]; 
        count++;
      }
    }
    
    if(count > 0) {
      const avgBrightness = (r * 0.299 + g * 0.587 + b * 0.114) / count;
      logoType.value = avgBrightness > 130 ? 'black' : 'white';
    }
  } catch(e) {
    console.warn('跨域限制导致无法分析背景亮度，已恢复默认白色 Logo。');
    logoType.value = 'white';
  }
}

function isVideoType(url, bgType) {
  if (bgType==='video') return true; if (bgType==='image') return false; if (!url) return false;
  if (url.startsWith('data:video/')) return true;
  const l = url.toLowerCase();
  return /\.(mp4|webm|ogg|mov|m4v|avi|mkv)(\?|$)/.test(l);
}
const isVideoBg = computed(() => isVideoType(customBackground.value, customBgType.value));
const shouldShowVideo = computed(() => isVideoBg.value && !videoFailed.value);
const shouldShowImage = computed(() => customBackground.value && !isVideoBg.value);

function onVideoCanPlay() { isBgLoaded.value=true; attemptPlay(); }
function onVideoLoadedData() { 
  if(!isBgLoaded.value){
    isBgLoaded.value=true;
    attemptPlay();
  }
  setTimeout(() => { if(bgVideoRef.value) analyzeBrightness(bgVideoRef.value); }, 200);
}

function onVideoError() {
  const v = bgVideoRef.value;
  if (!v || !customBackground.value) {
    videoFailed.value = true;
    return;
  }
  if (!v.dataset.retryCount) v.dataset.retryCount = 0;
  if (parseInt(v.dataset.retryCount) > 3) {
    videoFailed.value = true;
    return;
  }
  v.dataset.retryCount = parseInt(v.dataset.retryCount) + 1;
  
  v.load();
  setTimeout(() => {
    if (!document.hidden && v) {
      v.play().catch(() => {});
    }
  }, 500);
}

function onVideoEnded() { const v=bgVideoRef.value; if(v){v.currentTime=0; const p=v.play(); if(p&&p.catch)p.catch(()=>{videoFailed.value=true;});} }

function attemptPlay() { 
  const v = bgVideoRef.value; 
  if(!v) return; 

  v.muted = true; 

  if (document.hidden) {
    return;
  }

  const p = v.play(); 
  if(p && p.catch) {
    p.catch(err => {
      if(err.name === 'NotAllowedError') {
        needsInteraction.value = true;
      } else {
        if (!document.hidden) {
          videoFailed.value = true;
        }
      }
    });
  } 
}

// 不再需要 forcePlay，已删除

if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => { 
    const v = bgVideoRef.value; 
    if(!v) return; 

    if(document.hidden) {
      v.pause();
    } 
    else { 
      if (isVideoBg.value) {
        videoFailed.value = false; 
        v.muted = true;
        v.load();  // 强制重新加载，解决资源回收
        const playPromise = v.play();
        if (playPromise && playPromise.catch) {
          playPromise.catch(err => {
            if (err.name === 'NotAllowedError') {
              needsInteraction.value = true;
            } else {
              setTimeout(() => {
                if (v && !document.hidden) {
                  v.load();
                  v.play().catch(() => { videoFailed.value = true; });
                }
              }, 800);
            }
          });
        }
      } else {
        v.play().catch(()=>{}); 
      }
    } 
  });
}

watch(customBackground, (newUrl) => {
  videoFailed.value=false; needsInteraction.value=false;
  if(!newUrl){
    isBgLoaded.value=true; 
    logoType.value = 'white'; 
    return;
  }
  
  isBgLoaded.value=false;
  
  if(!isVideoBg.value){
    nextTick(() => {
      if(bgImageRef.value) {
        bgImageRef.value.src = newUrl;
        bgImageRef.value.onload = () => {
          isBgLoaded.value=true;
          analyzeBrightness(bgImageRef.value); 
        };
        bgImageRef.value.onerror = () => {
          isBgLoaded.value=true;
          logoType.value = 'white';
        };
      }
    });
  }
}, {immediate:true});

const ALLOWED_TYPES = /^(image\/(jpeg|png|gif|webp|bmp|svg\+xml)|video\/(mp4|webm|ogg|quicktime|x-m4v|x-msvideo|x-matroska))$/;
const ALLOWED_EXTS = /\.(jpg|jpeg|png|gif|webp|bmp|svg|mp4|webm|ogg|mov|m4v|avi|mkv)$/i;

function validateFile(file) {
  if (ALLOWED_TYPES.test(file.type)) return true;
  if (ALLOWED_EXTS.test(file.name)) return true;
  return false;
}

function openDB() {
  return new Promise((resolve,reject)=>{
    const req=indexedDB.open('VisitorThemeDB',1);
    req.onupgradeneeded=(e)=>{const db=e.target.result;if(!db.objectStoreNames.contains('wallpapers'))db.createObjectStore('wallpapers',{keyPath:'id'});};
    req.onsuccess=()=>resolve(req.result); req.onerror=()=>reject(req.error);
  });
}

function processLocalFile(file) {
  if(!file) return;
  formatError.value = '';
  if (!validateFile(file)) {
    formatError.value = `不支持的格式: ${file.name.split('.').pop()}`; return;
  }
  const type = (file.type.includes('video') || /\.(mp4|webm|ogg|mov|m4v|avi|mkv)$/i.test(file.name)) ? 'video' : 'image';
  const reader = new FileReader();
  reader.readAsDataURL(file);
  reader.onload = async (e)=>{
    const base64Data = e.target.result;
    try {
      const db = await openDB(); const tx = db.transaction('wallpapers','readwrite'); const store = tx.objectStore('wallpapers');
      store.clear(); store.put({id:'current',data:base64Data,type,name:file.name,timestamp:Date.now()});
      tx.oncomplete=()=>{
        customBackground.value=base64Data; customBgType.value=type; localFileName.value=file.name;
        localStorage.setItem('visitor_use_local_db','true'); localStorage.setItem('visitor_local_name',file.name);
        localStorage.removeItem('visitor_bg'); localStorage.removeItem('visitor_bg_type');
        showThemeSettings.value=false;
      };
    } catch(err){ alert('壁纸保存失败'); }
  };
}

function handleVisitorLocalFile(event) { processLocalFile(event.target.files[0]); }
function handleDrop(event) { isDragOver.value=false; const file=event.dataTransfer.files[0]; if (file) processLocalFile(file); }

async function loadLocalWallpaper() {
  if(localStorage.getItem('visitor_use_local_db')==='true'){
    localFileName.value = localStorage.getItem('visitor_local_name')||'';
    try {
      const db=await openDB(); const tx=db.transaction('wallpapers','readonly'); const store=tx.objectStore('wallpapers'); const req=store.get('current');
      req.onsuccess=()=>{ if(req.result){customBackground.value=req.result.data;customBgType.value=req.result.type;if(req.result.name)localFileName.value=req.result.name;} else {localStorage.removeItem('visitor_use_local_db');customBackground.value=globalBackground.value;customBgType.value=globalBgType.value;} };
    } catch{ customBackground.value=globalBackground.value; customBgType.value=globalBgType.value; }
  } else {
    const localBg=localStorage.getItem('visitor_bg'); const localBgType=localStorage.getItem('visitor_bg_type');
    if(localBg){customBackground.value=localBg;customBgType.value=localBgType||'auto';visitorBgInput.value=localBg;visitorBgType.value=localBgType||'auto';}
    else {customBackground.value=globalBackground.value;customBgType.value=globalBgType.value;}
  }
}

function saveVisitorTheme() {
  const url=visitorBgInput.value.trim();
  if(url){localStorage.setItem('visitor_bg',url);localStorage.setItem('visitor_bg_type',visitorBgType.value);localStorage.removeItem('visitor_use_local_db');localStorage.removeItem('visitor_local_name');localFileName.value='';
    openDB().then(db=>{db.transaction('wallpapers','readwrite').objectStore('wallpapers').clear();}).catch(()=>{});
    customBackground.value=url;customBgType.value=visitorBgType.value;
  } else clearVisitorTheme();
  showThemeSettings.value=false;
}
function clearVisitorTheme() {
  localStorage.removeItem('visitor_bg');localStorage.removeItem('visitor_bg_type');localStorage.removeItem('visitor_use_local_db');localStorage.removeItem('visitor_local_name');
  openDB().then(db=>{db.transaction('wallpapers','readwrite').objectStore('wallpapers').clear();}).catch(()=>{});
  visitorBgInput.value='';visitorBgType.value='auto';localFileName.value='';formatError.value='';
  customBackground.value=globalBackground.value;customBgType.value=globalBgType.value;
  showThemeSettings.value=false;
}

const searchEngines = [
  {name:'google',label:'Google',placeholder:'Google 搜索...',url:q=>`https://www.google.com/search?q=${encodeURIComponent(q)}`},
  {name:'baidu',label:'百度',placeholder:'百度搜索...',url:q=>`https://www.baidu.com/s?wd=${encodeURIComponent(q)}`},
  {name:'bing',label:'Bing',placeholder:'Bing 搜索...',url:q=>`https://www.bing.com/search?q=${encodeURIComponent(q)}`},
  {name:'github',label:'GitHub',placeholder:'GitHub 搜索...',url:q=>`https://github.com/search?q=${encodeURIComponent(q)}&type=repositories`},
  {name:'site',label:'站内',placeholder:'站内搜索...',url:q=>q}
];
const selectedEngine = ref(searchEngines[0]);
function selectEngine(engine){selectedEngine.value=engine;}
function clearSearch(){searchQuery.value='';if(!activeMenu.value&&menus.value.length>0)activeMenu.value=menus.value[0];loadCards();}
const filteredCards = computed(()=>{
  if(!searchQuery.value)return cards.value;
  return cards.value.filter(c=>c.title.toLowerCase().includes(searchQuery.value.toLowerCase())||c.url.toLowerCase().includes(searchQuery.value.toLowerCase())||(c.desc&&c.desc.toLowerCase().includes(searchQuery.value.toLowerCase())));
});
let searchTimer=null;
watch(searchQuery,(v)=>{
  if(v.trim()===''){if(!activeMenu.value&&menus.value.length>0)activeMenu.value=menus.value[0];loadCards();return;}
  if(selectedEngine.value.name==='site'){clearTimeout(searchTimer);searchTimer=setTimeout(async()=>{try{const r=await searchCards(v.trim());if(r.data.length>0){cards.value=r.data;activeMenu.value=null;activeSubMenu.value=null;}else cards.value=[];}catch{}},100);}
});

onMounted(async()=>{
  try {
    const c = await getConfig();
    if (c.data.background) globalBackground.value = c.data.background;
    if (c.data.bg_type) globalBgType.value = c.data.bg_type;
    if (c.data.title) document.title = c.data.title;
  } catch(e) {}
  
  await loadLocalWallpaper(); 
  
  // 利用任意一次用户交互激活自动播放
  const activateOnce = () => {
    const v = bgVideoRef.value;
    if (v && isVideoBg.value) {
      v.muted = true;
      v.play().then(() => {
        needsInteraction.value = false;
      }).catch(() => {});
    }
  };
  ['click', 'touchstart'].forEach(evt => 
    document.addEventListener(evt, activateOnce, { once: true })
  );
  
  const res = await getMenus();
  menus.value = res.data;
  if (menus.value.length) {
    activeMenu.value = menus.value[0];
    loadCards();
  }
  
  const adRes = await getAds();
  leftAds.value = adRes.data.filter(a => a.position === 'left');
  rightAds.value = adRes.data.filter(a => a.position === 'right');
  
  const friendRes = await getFriends();
  friendLinks.value = friendRes.data;

  const eventSource = new EventSource('/api/stream');
  
  eventSource.onmessage = async (event) => {
    const data = JSON.parse(event.data);
    if (data.action === 'reload') {
      console.log('✨ 收到云端数据更新指令，正在丝滑无感替换内容...');
      
      try {
        const c = await getConfig();
        if (c.data.background) globalBackground.value = c.data.background;
        if (c.data.bg_type) globalBgType.value = c.data.bg_type;
        if (c.data.title) document.title = c.data.title;
        
        if (localStorage.getItem('visitor_use_local_db') !== 'true' && !localStorage.getItem('visitor_bg')) {
          customBackground.value = globalBackground.value;
          customBgType.value = globalBgType.value;
        }

        const newMenusRes = await getMenus();
        menus.value = newMenusRes.data;
        if (menus.value.length) {
          if (!activeMenu.value || !menus.value.find(m => m.id === activeMenu.value.id)) {
            activeMenu.value = menus.value[0];
            activeSubMenu.value = null;
          }
          loadCards(); 
        }

        const newAdRes = await getAds();
        leftAds.value = newAdRes.data.filter(a => a.position === 'left');
        rightAds.value = newAdRes.data.filter(a => a.position === 'right');
        
        const newFriendRes = await getFriends();
        friendLinks.value = newFriendRes.data;

      } catch (e) {
        console.error('无感更新失败:', e);
      }
    }
  };
});

async function selectMenu(menu,parentMenu=null){if(parentMenu){activeMenu.value=parentMenu;activeSubMenu.value=menu;}else{activeMenu.value=menu;activeSubMenu.value=null;}loadCards();}
async function loadCards(){if(!activeMenu.value)return;const r=await getCards(activeMenu.value.id,activeSubMenu.value?.id);cards.value=r.data;}
async function handleSearch(){if(!searchQuery.value.trim())return;if(selectedEngine.value.name==='site'){try{const r=await searchCards(searchQuery.value.trim());if(r.data.length>0){cards.value=r.data;activeMenu.value=null;activeSubMenu.value=null;}else alert('未找到相关内容');}catch{alert('搜索时发生错误');}}else window.open(selectedEngine.value.url(searchQuery.value),'_blank');}
function handleLogoError(e){e.target.style.display='none';if(e.target.nextElementSibling)e.target.nextElementSibling.style.display='flex';}
</script>

<style scoped>
.home-container{min-height:100vh;min-height:100dvh;position:relative;display:flex;flex-direction:column}
.bg-placeholder{position:fixed;inset:0;background:linear-gradient(135deg,#1a1c29,#2a2d3e);z-index:-1}
.bg-image,.bg-video{opacity:0;transition:opacity 1.2s ease-in-out}
.fade-in{opacity:1!important}
.bg-image{position:fixed;inset:0;background-size:cover;background-position:center;background-repeat:no-repeat;z-index:0}
.bg-video{position:fixed;top:0;left:0;width:100vw;height:100vh;height:100dvh;object-fit:cover;z-index:0;-webkit-transform:translateZ(0);transform:translateZ(0)}
.home-container::before{content:'';position:fixed;inset:0;background:rgba(0,0,0,0.3);z-index:1}
.content-overlay{position:relative;z-index:2;flex:1;display:flex;flex-direction:column;padding-top:40px}
@media(max-width:767px){.content-overlay{padding-top:60px}} 
.theme-toggle-btn{position:fixed;top:16px;right:16px;z-index:101;background:rgba(255,255,255,0.15);backdrop-filter:blur(8px);border:1px solid rgba(255,255,255,0.3);border-radius:50%;width:40px;height:40px;display:flex;align-items:center;justify-content:center;color:#fff;cursor:pointer;transition:all .3s;box-shadow:0 4px 12px rgba(0,0,0,0.1)}
.theme-toggle-btn:active{background:rgba(255,255,255,0.25);transform:scale(0.95)}
@media(pointer:fine){.theme-toggle-btn:hover{background:rgba(255,255,255,0.25);transform:rotate(15deg) scale(1.1)}}
.home-logo {
  height: 48px; 
  margin-bottom: 16px;
  position: relative; 
  z-index: 10;
  object-fit: contain;
  transition: opacity 0.5s ease;
  filter: drop-shadow(0 4px 8px rgba(0,0,0,0.25)); 
}
@media(min-width: 768px){
  .home-logo { 
    position: fixed;
    top: 16px;
    left: 16px;
    transform: none;
    height: 40px;
    margin-bottom: 0;
    z-index: 100;
  }
}
.search-engine-select{display:flex;align-items:center;padding-bottom:.3rem;gap:3px;overflow-x:auto}
.engine-btn{border:none;background:none;color:#fff;font-size:.8rem;padding:4px 10px;border-radius:4px;cursor:pointer;white-space:nowrap;min-height:32px}
.engine-btn.active,.engine-btn:hover{color:#399dff;background:#ffffff1a}
.search-container{display:flex;align-items:center;background:#b3b7b83b;border-radius:20px;padding:0.2rem;box-shadow:0 4px 20px rgba(0,0,0,0.1);backdrop-filter:blur(10px);max-width:480px;width:92%}
.search-input{flex:1;border:none;background:transparent;padding:.1rem .5rem;font-size:1rem;color:#fff;outline:none;min-width:0}
.search-input::placeholder{color:#999}
.clear-btn{background:none;border:none;cursor:pointer;display:flex;align-items:center;padding:4px;min-width:36px;min-height:36px;justify-content:center}
.search-btn{background:transparent;color:#fff;border:none;border-radius:50%;width:36px;height:36px;display:flex;align-items:center;justify-content:center;cursor:pointer}
.search-section{display:flex;flex-direction:column;align-items:center;padding:1.5rem 0 2rem;z-index:2}
@media(min-width:768px){.search-section{padding:3.5rem 0 2rem}}
.search-box-wrapper{display:flex;flex-direction:column;align-items:center;width:100%;max-width:480px;padding:0 12px;box-sizing:border-box}
.ad-space-fixed{position:fixed;top:13rem;z-index:10;width:90px;display:flex;flex-direction:column;align-items:center;gap:5px}
.left-ad-fixed{left:0}.right-ad-fixed{right:0}
.ad-space-fixed a{width:100%;display:block}.ad-space-fixed img{width:100%;max-width:90px;max-height:160px;box-shadow:0 2px 12px rgba(0,0,0,0.12);background:#fff}
@media(max-width:1024px){.ad-space-fixed{display:none}}
.footer{margin-top:auto;text-align:center;padding:1rem 0 1.5rem;padding-bottom:max(1.5rem,env(safe-area-inset-bottom,0px));z-index:2}
.footer-content{display:flex;flex-direction:column;align-items:center;gap:8px}
@media(min-width:768px){.footer-content{flex-direction:row;justify-content:center;gap:50px}}
.friend-link-btn{display:flex;align-items:center;gap:8px;background:none;border:none;color:rgba(255,255,255,0.8);cursor:pointer;font-size:12px;min-height:36px}
@media(min-width:768px){.friend-link-btn{font-size:14px}}
.copyright{color:rgba(255,255,255,0.6);font-size:10px;margin:0}
@media(min-width:768px){.copyright{font-size:14px;color:rgba(255,255,255,0.8)}}
.footer-link{color:inherit;text-decoration:none}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,0.7);display:flex;align-items:center;justify-content:center;z-index:1000;backdrop-filter:blur(5px)}
@media(max-width:767px){.modal-overlay{align-items:flex-end}}
.modal-content{background:#f8fafc;border-radius:16px;width:55rem;max-width:95vw;max-height:95vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,0.3);overflow:hidden}
@media(max-width:767px){.modal-content.modal-bottom-sheet{width:100%;max-width:100%;max-height:80vh;border-radius:16px 16px 0 0}}
.modal-header{display:flex;align-items:center;justify-content:space-between;padding:15px 20px;border-bottom:1px solid #e5e7eb;background:#fff;flex-shrink:0}
.modal-header h3{margin:0;font-size:16px;font-weight:600;color:#111827}
@media(min-width:768px){.modal-header h3{font-size:20px}}
.close-btn{background:none;border:none;cursor:pointer;padding:8px;border-radius:8px;color:#6b7280;min-width:40px;min-height:40px;display:flex;align-items:center;justify-content:center}
.close-btn:active{background:#fee2e2;color:#ef4444}
.modal-body{flex:1;padding:16px;overflow-y:auto;overscroll-behavior:contain;padding-bottom:max(16px,env(safe-area-inset-bottom,0px))}
@media(min-width:768px){.modal-body{padding:24px}}
.friend-links-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
@media(min-width:768px){.friend-links-grid{grid-template-columns:repeat(6,1fr);gap:12px}}
.friend-link-card{display:flex;flex-direction:column;align-items:center;padding:10px;background:#fff;border-radius:12px;text-decoration:none;color:inherit;border:1px solid #e2e8f0;min-height:72px}
.friend-link-card:active{transform:scale(0.97)}
.friend-link-logo{width:40px;height:40px;border-radius:8px;overflow:hidden;margin-bottom:6px;display:flex;align-items:center;justify-content:center;background:#f8fafc}
@media(min-width:768px){.friend-link-logo{width:48px;height:48px;margin-bottom:8px}}
.friend-link-logo img{width:100%;height:100%;object-fit:contain}
.friend-link-placeholder{width:100%;height:100%;display:flex;align-items:center;justify-content:center;color:#64748b;font-size:18px;font-weight:600}
.friend-link-info h4{margin:0;font-size:11px;font-weight:500;color:#334155;text-align:center;word-break:break-all}
@media(min-width:768px){.friend-link-info h4{font-size:13px}}
.theme-modal{width:420px!important;height:auto!important;min-height:220px}
@media(max-width:767px){.theme-modal{width:100%!important}}
.upload-tabs{display:flex;gap:8px;margin-bottom:14px}
.upload-tabs button{flex:1;padding:10px;border-radius:8px;border:1px solid #d0d7e2;background:#f8f9fa;cursor:pointer;font-weight:600;font-size:13px;min-height:42px;transition:.2s}
.upload-tabs button.active{background:#2566d8;color:#fff;border-color:#2566d8}
.tab-content{margin-bottom:14px}
.theme-desc{font-size:12px;color:#555;margin-bottom:12px;line-height:1.6;background:#f0f4f8;padding:10px;border-radius:6px;border-left:3px solid #2566d8}
.theme-input{width:100%;padding:12px 16px;border-radius:8px;border:1px solid #cbd5e1;font-size:14px;background:#fff;margin-bottom:12px;box-sizing:border-box}
.theme-input:focus{outline:none;border-color:#2566d8;box-shadow:0 0 0 2px rgba(37,102,216,0.1)}
.drop-zone{border:2px dashed #cbd5e1;border-radius:10px;padding:20px 16px;text-align:center;transition:all .2s;position:relative;cursor:pointer}
.drop-zone.dragover{border-color:#2566d8;background:rgba(37,102,216,0.06)}
.drop-zone .file-input{position:absolute;inset:0;opacity:0;cursor:pointer;z-index:1}
.drop-hint{display:flex;flex-direction:column;align-items:center;gap:6px;color:#94a3b8;font-size:13px;pointer-events:none}
.drop-hint svg{color:#94a3b8}
.format-error{font-size:12px;color:#dc2626;margin-top:6px;padding:6px 10px;background:#fef2f2;border-radius:6px}
.type-selector{display:flex;gap:8px;margin-bottom:10px}
.type-btn{flex:1;padding:10px 8px;border-radius:8px;border:1px solid #cbd5e1;background:#fff;color:#555;font-size:12px;cursor:pointer;text-align:center;min-height:40px}
.type-btn.active{background:#2566d8;color:#fff;border-color:#2566d8}
.theme-actions{display:flex;gap:10px}
.btn{border:none;border-radius:8px;padding:12px;cursor:pointer;font-weight:500;min-height:48px}
.save-theme-btn{flex:1;background:#2566d8;color:#fff}
.save-theme-btn:active{background:#1a4ba3}
.clear-theme-btn{flex:1;background:#fff;color:#64748b;border:1px solid #cbd5e1}
.clear-theme-btn:active{color:#ef4444;border-color:#ef4444}
</style>
