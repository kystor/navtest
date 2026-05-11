<template>
  <div class="card-manage">
    <div class="card-header">
      <div class="header-content">
        <h2 class="page-title">管理网站导航卡片，支持主菜单和子菜单分类</h2>
      </div>
      
      <div class="search-bar">
        <div class="search-input-wrapper">
          <svg class="search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"/>
            <path d="M21 21l-4.35-4.35"/>
          </svg>
          <input 
            v-model="searchQuery" 
            placeholder="搜索卡片标题、网址或描述..." 
            class="search-input"
            @keydown.enter="handleSearch"
          />
          <button v-if="searchQuery" class="clear-btn" @click="clearSearch">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18 6L6 18M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <button class="btn search-btn" @click="handleSearch" :disabled="isSearching">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"/>
            <path d="M21 21l-4.35-4.35"/>
          </svg>
          {{ isSearching ? '搜索中...' : '搜索' }}
        </button>
      </div>
      
      <div v-if="showSearchResults" class="search-result-tip">
        <span>找到 {{ searchResults.length }} 个结果</span>
        <button class="clear-search-btn" @click="clearSearch">清除搜索</button>
      </div>
    </div>

    <div v-if="selectedCards.size > 0" class="batch-operations">
      <div class="batch-info">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M9 11l3 3L22 4"/>
          <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
        </svg>
        <span>已选择 <strong>{{ selectedCards.size }}</strong> 张卡片</span>
        <button class="btn-cancel-select" @click="clearSelection" title="取消选择">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M18 6L6 18M6 6l12 12"/>
          </svg>
          取消选择
        </button>
      </div>
      <div class="batch-actions">
        <button class="btn btn-move" @click="showMoveModal = true">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M5 9l-3 3 3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3M2 12h20M12 2v20"/>
          </svg>
          批量移动
        </button>
        <button class="btn btn-danger" @click="handleBatchDelete">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>
          </svg>
          批量删除
        </button>
      </div>
    </div>

    <div v-if="!showSearchResults" class="card-filter-add">
      <div class="filter-row">
        <select v-model="selectedMenuId" class="input narrow" @change="onMenuChange">
          <option v-for="menu in menus" :value="menu.id" :key="menu.id">{{ menu.name }}</option>
        </select>
        <select v-model="selectedSubMenuId" class="input narrow" @change="onSubMenuChange">
          <option value="">主菜单</option>
          <option v-for="subMenu in currentSubMenus" :value="subMenu.id" :key="subMenu.id">{{ subMenu.name }}</option>
        </select>
      </div>
      <div class="add-row">
        <input v-model="newCardTitle" placeholder="卡片标题 (留空可自动解析)" class="input flex-input" />
        <input v-model="newCardUrl" placeholder="卡片链接" class="input flex-input" @blur="autoParseNewCard" />
        <input v-model="newCardLogo" placeholder="Logo链接 (留空可自动解析)" class="input flex-input" />
        <button class="btn btn-add-fixed" @click="addCard" :disabled="isParsing">
          <svg v-if="!isParsing" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 5v14M5 12h14"/>
          </svg>
          <svg v-else width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="spin">
            <circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>
          </svg>
          {{ isParsing ? '解析中...' : '添加卡片' }}
        </button>
      </div>
      <p v-if="parseError" class="parse-tip error">{{ parseError }}</p>
      <p v-if="parseSuccess" class="parse-tip success">{{ parseSuccess }}</p>
    </div>

    <div class="card-card">
      <table class="card-table">
        <thead>
          <tr>
            <th style="width: 40px; text-align: center;">
              <button class="checkbox-btn" @click="toggleAllSelection" :title="isAllSelected ? '取消全选' : '全选'">
                <svg v-if="isAllSelected" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#399dff" stroke-width="2">
                  <rect x="3" y="3" width="18" height="18" rx="2"/>
                  <path d="M9 12l2 2 4-4"/>
                </svg>
                <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#999" stroke-width="2">
                  <rect x="3" y="3" width="18" height="18" rx="2"/>
                </svg>
              </button>
            </th>
            <th style="width: 50px; text-align: center;">排序</th>
            <th style="width: 20%;">标题</th>
            <th style="width: 25%;">Logo</th>
            <th style="width: 25%;">网址</th>
            <th style="width: 20%;">描述</th>
            <th v-if="showSearchResults" style="width: 15%;">所属菜单</th>
            <th style="width: 70px; text-align: center;">操作</th>
          </tr>
        </thead>
        
        <draggable 
          v-model="displayCards" 
          tag="tbody" 
          item-key="id" 
          handle=".drag-handle"
          ghost-class="ghost"
          animation="200"
          :force-fallback="true" 
          :scroll="true"
          :scroll-sensitivity="100"
          :scroll-speed="20"
          @end="onDragEnd"
        >
          <template #item="{ element }">
            <tr :class="{ 'selected-row': selectedCards.has(element.id) }">
              <td class="checkbox-cell">
                <button class="checkbox-btn" @click="toggleCardSelection(element.id)">
                  <svg v-if="selectedCards.has(element.id)" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#399dff" stroke-width="2">
                    <rect x="3" y="3" width="18" height="18" rx="2"/>
                    <path d="M9 12l2 2 4-4"/>
                  </svg>
                  <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="2">
                    <rect x="3" y="3" width="18" height="18" rx="2"/>
                  </svg>
                </button>
              </td>
              <td class="drag-handle" title="按住此处拖动进行排序">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#999" stroke-width="2">
                  <path d="M3 6h18M3 12h18M3 18h18"/>
                </svg>
              </td>
              <td>
                <div class="card-title-cell">
                  <input v-model="element.title" @blur="updateCard(element)" class="table-input" placeholder="输入标题" />
                </div>
              </td>
              <td>
                <div class="logo-cell">
                  <img :src="getLogo(element)" class="logo-preview" @error="handleLogoError" />
                  <input v-model="element.logo_url" @blur="updateCard(element)" class="table-input logo-input" placeholder="Logo链接" />
                </div>
              </td>
              <td><input v-model="element.url" @blur="updateCard(element)" class="table-input" placeholder="网页链接" /></td>
              <td><input v-model="element.desc" @blur="updateCard(element)" class="table-input" placeholder="描述（可选）" /></td>
              <td v-if="showSearchResults">
                <span class="menu-tag">
                  {{ element.menu_name }}
                  <span v-if="element.sub_menu_name"> / {{ element.sub_menu_name }}</span>
                </span>
              </td>
              <td style="text-align: center;">
                <button class="btn btn-danger btn-icon" @click="deleteCard(element.id)" title="删除">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/>
                    <path d="M10 11v6M14 11v6"/>
                  </svg>
                </button>
              </td>
            </tr>
          </template>
        </draggable>
      </table>
      
      <div v-if="displayCards.length === 0 && !loading" class="empty-state">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="1.5">
          <path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"/>
        </svg>
        <p>{{ showSearchResults ? '没有找到匹配的卡片' : '暂无卡片' }}</p>
      </div>
    </div>

    <div v-if="showMoveModal" class="modal-overlay" @click.self="showMoveModal = false">
      <div class="modal">
        <div class="modal-header">
          <h3>批量移动卡片</h3>
          <button class="modal-close" @click="showMoveModal = false">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18 6L6 18M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label>选择目标主菜单</label>
            <select v-model="targetMenuId" class="input">
              <option value="">请选择主菜单</option>
              <option v-for="menu in menus" :value="menu.id" :key="menu.id">{{ menu.name }}</option>
            </select>
          </div>
          <div v-if="targetSubMenus.length > 0" class="form-group">
            <label>选择目标子菜单（可选）</label>
            <select v-model="targetSubMenuId" class="input">
              <option value="">主菜单（不选择子菜单）</option>
              <option v-for="sub in targetSubMenus" :value="sub.id" :key="sub.id">{{ sub.name }}</option>
            </select>
          </div>
          <div class="move-preview">
            <p>将移动 <strong>{{ selectedCards.size }}</strong> 张卡片到</p>
            <p v-if="targetMenuId" class="target-preview">
              「{{ getMenuName(targetMenuId) }}」
              <span v-if="targetSubMenuId"> / {{ getSubMenuName(targetSubMenuId) }}</span>
            </p>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-secondary" @click="showMoveModal = false">取消</button>
          <button class="btn btn-primary" @click="handleBatchMove" :disabled="!targetMenuId">确认移动</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from 'vue';
import draggable from 'vuedraggable';
import { getMenus, getCards, addCard as apiAddCard, updateCard as apiUpdateCard, deleteCard as apiDeleteCard, updateCardOrder, searchCards, batchMoveCards, batchDeleteCards, parseLink } from '../../api';

// Vue 数据状态定义
const menus = ref([]);
const cards = ref([]);
const selectedMenuId = ref();
const selectedSubMenuId = ref('');
const newCardTitle = ref('');
const newCardUrl = ref('');
const newCardLogo = ref('');
const loading = ref(false);
const isParsing = ref(false);
const parseError = ref('');
const parseSuccess = ref('');

const searchQuery = ref('');
const searchResults = ref([]);
const isSearching = ref(false);
const showSearchResults = ref(false);

const selectedCards = ref(new Set());
const showMoveModal = ref(false);
const targetMenuId = ref(null);
const targetSubMenuId = ref(null);

const currentSubMenus = computed(() => {
  if (!selectedMenuId.value) return [];
  const menu = menus.value.find(m => m.id === selectedMenuId.value);
  return menu?.subMenus || [];
});

const targetSubMenus = computed(() => {
  if (!targetMenuId.value) return [];
  const menu = menus.value.find(m => m.id === targetMenuId.value);
  return menu?.subMenus || [];
});

const displayCards = computed({
  get: () => showSearchResults.value ? searchResults.value : cards.value,
  set: (val) => {
    if (showSearchResults.value) { searchResults.value = val; } else { cards.value = val; }
  }
});

const isAllSelected = computed(() => {
  return displayCards.value.length > 0 && selectedCards.value.size === displayCards.value.length;
});

// 页面加载完成时请求数据
onMounted(async () => {
  const res = await getMenus();
  menus.value = res.data;
  if (menus.value.length) {
    selectedMenuId.value = menus.value[0].id;
    selectedSubMenuId.value = '';
  }
});

watch(selectedMenuId, () => { selectedSubMenuId.value = ''; loadCards(); });
watch(selectedSubMenuId, loadCards);

function onMenuChange() { selectedSubMenuId.value = ''; }
function onSubMenuChange() { loadCards(); }

async function loadCards() {
  if (!selectedMenuId.value) return;
  loading.value = true;
  const res = await getCards(selectedMenuId.value, selectedSubMenuId.value || null);
  cards.value = res.data;
  selectedCards.value = new Set();
  loading.value = false;
}

async function handleSearch() {
  if (!searchQuery.value.trim()) { clearSearch(); return; }
  isSearching.value = true;
  try {
    const res = await searchCards(searchQuery.value);
    searchResults.value = res.data || [];
    showSearchResults.value = true;
    selectedCards.value = new Set();
  } catch (err) { console.error('搜索失败:', err); } finally { isSearching.value = false; }
}

function clearSearch() { searchQuery.value = ''; showSearchResults.value = false; searchResults.value = []; }

function toggleCardSelection(cardId) {
  const newSet = new Set(selectedCards.value);
  if (newSet.has(cardId)) { newSet.delete(cardId); } else { newSet.add(cardId); }
  selectedCards.value = newSet;
}

function toggleAllSelection() {
  if (isAllSelected.value) { selectedCards.value = new Set(); } else { selectedCards.value = new Set(displayCards.value.map(c => c.id)); }
}
function clearSelection() { selectedCards.value = new Set(); }

function getLogo(card) {
  if (card.custom_logo_path) { return '/uploads/' + card.custom_logo_path; }
  if (card.logo_url) { return card.logo_url; }
  try { const url = new URL(card.url); return url.origin + '/favicon.ico'; } catch { return '/default-favicon.png'; }
}
function handleLogoError(e) { e.target.src = '/default-favicon.png'; }

function getMenuName(menuId) {
  const menu = menus.value.find(m => m.id === menuId); return menu?.name || '';
}
function getSubMenuName(subMenuId) {
  for (const menu of menus.value) {
    const sub = menu.subMenus?.find(s => s.id === subMenuId);
    if (sub) return sub.name;
  }
  return '';
}

async function addCard() {
  if (!newCardUrl.value) return;
  await apiAddCard({ menu_id: selectedMenuId.value, sub_menu_id: selectedSubMenuId.value || null, title: newCardTitle.value || '', url: newCardUrl.value, logo_url: newCardLogo.value || '' });
  newCardTitle.value = ''; newCardUrl.value = ''; newCardLogo.value = ''; parseError.value = ''; parseSuccess.value = ''; loadCards();
}

async function autoParseNewCard() {
  if (!newCardUrl.value.trim()) return;
  if (newCardTitle.value.trim() && newCardLogo.value.trim()) return;
  isParsing.value = true; parseError.value = ''; parseSuccess.value = '';
  try {
    const res = await parseLink(newCardUrl.value.trim());
    if (res.data.success) {
      if (!newCardTitle.value.trim() && res.data.title) newCardTitle.value = res.data.title;
      if (!newCardLogo.value.trim() && res.data.icon) newCardLogo.value = res.data.icon;
      parseSuccess.value = res.data.message || '已自动填充';
      setTimeout(() => { parseSuccess.value = ''; }, 3000);
    } else {
      if (!newCardLogo.value.trim() && res.data.icon) newCardLogo.value = res.data.icon;
      parseError.value = res.data.message || '自动解析失败，请手动填写';
      setTimeout(() => { parseError.value = ''; }, 5000);
    }
  } catch (err) {
    parseError.value = '网络错误，自动解析失败'; setTimeout(() => { parseError.value = ''; }, 5000);
  } finally { isParsing.value = false; }
}

async function updateCard(card) {
  await apiUpdateCard(card.id, { menu_id: card.menu_id, sub_menu_id: card.sub_menu_id, title: card.title, url: card.url, logo_url: card.logo_url, desc: card.desc, order: card.order });
}

async function deleteCard(id) {
  await apiDeleteCard(id);
  if (showSearchResults.value) { handleSearch(); } else { loadCards(); }
}

async function onDragEnd() {
  const sortedIds = cards.value.map(card => card.id);
  try { await updateCardOrder({ sortedIds }); } catch (error) { console.error('排序保存失败', error); alert('排序保存失败，请刷新页面重试'); }
}

async function handleBatchMove() {
  if (selectedCards.value.size === 0 || !targetMenuId.value) return;
  try {
    const res = await batchMoveCards(Array.from(selectedCards.value), targetMenuId.value, targetSubMenuId.value || null);
    alert(res.message || '移动成功'); showMoveModal.value = false; selectedCards.value = new Set(); targetMenuId.value = null; targetSubMenuId.value = null;
    if (showSearchResults.value) { handleSearch(); } else { loadCards(); }
  } catch (err) { console.error('移动失败:', err); alert('移动失败'); }
}

async function handleBatchDelete() {
  if (selectedCards.value.size === 0) return;
  if (!confirm(`确定要删除选中的 ${selectedCards.value.size} 张卡片吗？`)) return;
  try {
    const res = await batchDeleteCards(Array.from(selectedCards.value));
    alert(res.message || '删除成功'); selectedCards.value = new Set();
    if (showSearchResults.value) { handleSearch(); } else { loadCards(); }
  } catch (err) { console.error('删除失败:', err); alert('删除失败'); }
}
</script>

<style scoped>
/* 核心容器与头部 */
.card-manage { max-width: 1200px; width: 100%; margin: 0 auto; display: flex; flex-direction: column; align-items: center; }
.card-header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 16px; padding: 24px; margin-bottom: 20px; color: white; box-shadow: 0 8px 32px rgba(102, 126, 234, 0.3); width: 100%; text-align: center; box-sizing: border-box; }
.header-content { margin-bottom: 15px; text-align: center; }
.page-title { font-size: 1.5rem; font-weight: 700; margin: 0 0 8px 0; letter-spacing: -0.5px; }

/* 搜索栏样式 */
.search-bar { display: flex; gap: 10px; justify-content: center; margin-bottom: 15px; width: 100%; max-width: 500px; margin-left: auto; margin-right: auto; }
.search-input-wrapper { position: relative; flex: 1; min-width: 0; }
.search-icon { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: #999; pointer-events: none; }
.search-input { width: 100%; padding: 10px 36px 10px 36px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.3); background: rgba(255,255,255,0.15); color: white; font-size: 0.9rem; box-sizing: border-box; }
.search-input::placeholder { color: rgba(255,255,255,0.7); }
.search-input:focus { outline: none; border-color: white; background: rgba(255,255,255,0.25); }
.clear-btn { position: absolute; right: 8px; top: 50%; transform: translateY(-50%); background: none; border: none; color: rgba(255,255,255,0.7); cursor: pointer; padding: 4px; display: flex; align-items: center; justify-content: center; }
.search-btn { background: white; color: #667eea; flex-shrink: 0; white-space: nowrap; }
.search-result-tip { display: flex; align-items: center; justify-content: center; gap: 10px; font-size: 0.9rem; color: rgba(255,255,255,0.9); }
.clear-search-btn { background: none; border: none; color: white; text-decoration: underline; cursor: pointer; font-size: 0.85rem; }

/* 批量操作样式 */
.batch-operations { background: #eef2ff; border: 1px solid #c7d2fe; border-radius: 12px; padding: 12px 20px; margin-bottom: 16px; width: 100%; display: flex; align-items: center; justify-content: space-between; box-sizing: border-box; }
.batch-info { display: flex; align-items: center; gap: 8px; color: #4f46e5; font-size: 0.95rem; }
.btn-cancel-select { background: none; border: 1px solid #4f46e5; color: #4f46e5; padding: 4px 10px; border-radius: 6px; cursor: pointer; font-size: 0.8rem; display: flex; align-items: center; gap: 4px; transition: all 0.2s; }
.batch-actions { display: flex; gap: 10px; }
.btn-move { background: #4f46e5; }
.card-filter-add { background: white; border-radius: 12px; padding: 16px 20px; margin-bottom: 16px; width: 100%; box-shadow: 0 2px 8px rgba(0,0,0,0.06); box-sizing: border-box; }
.filter-row { display: flex; gap: 10px; margin-bottom: 12px; }

/* ====================================================
   新增网址输入框排版 (已优化为弹性均分排版)
   ==================================================== */
.add-row { 
  display: flex; 
  gap: 12px; /* 输入框之间的距离 */
  margin-bottom: 12px; 
  align-items: center; /* 保证三个框和按钮在同一高度对齐 */
  width: 100%; /* 占满整个父容器宽度 */
}
.flex-input {
  flex: 1; /* 告诉浏览器，所有的框平均分配剩下的宽度空间 */
  min-width: 0; /* 防止内容超出撑破布局，极其重要的小技巧 */
}
.btn-add-fixed {
  flex-shrink: 0; /* 保护按钮不被压缩 */
  white-space: nowrap; /* 保护按钮里的字不换行 */
}
/* ==================================================== */

/* 表格主体样式 */
.card-card { background: white; border-radius: 16px; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08); overflow: hidden; width: 100%; box-sizing: border-box; }
.card-table { width: 100%; border-collapse: collapse; }
.card-table th, .card-table td { padding: 12px 16px; text-align: left; border-bottom: 1px solid #e5e7eb; vertical-align: middle; }
.card-table th { background: #f9fafb; font-weight: 600; color: #374151; font-size: 0.85rem; }

/* 拖拽功能样式 */
.drag-handle { cursor: grab; text-align: center; color: #999; user-select: none; -webkit-user-select: none; }
.drag-handle:active { cursor: grabbing; }
.ghost, .sortable-drag, .sortable-chosen { opacity: 0.5; background-color: #f3f4f6; user-select: none !important; -webkit-user-select: none !important; }

.selected-row { background-color: #eef2ff !important; }
.checkbox-cell { text-align: center; }
.checkbox-btn { background: none; border: none; cursor: pointer; padding: 4px; display: flex; align-items: center; justify-content: center; }
.card-title-cell { display: flex; align-items: center; gap: 8px; }
.menu-tag { background: #f3f4f6; color: #6b7280; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; }

/* 基础输入框样式 */
.input { padding: 10px 12px; border-radius: 8px; border: 1px solid #d0d7e2; background: #fff; font-size: 0.9rem; box-sizing: border-box; transition: all 0.2s; }
.input.narrow { width: 140px; } /* 这个留给筛选下拉菜单用 */
.input:focus { outline: none; border-color: #399dff; box-shadow: 0 0 0 3px rgba(57, 157, 255, 0.1); }
.table-input { width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid transparent; background: transparent; color: #222; font-size: 0.9rem; transition: all 0.2s ease; box-sizing: border-box; }
.table-input:focus { outline: none; border-color: #399dff; background: white; box-shadow: 0 0 0 2px rgba(57, 157, 255, 0.1); }

/* Logo预览样式 */
.logo-cell { display: flex; align-items: center; gap: 8px; }
.logo-preview { width: 28px; height: 28px; border-radius: 6px; object-fit: contain; background: #f3f4f6; border: 1px solid #e5e7eb; flex-shrink: 0; }
.logo-input { flex: 1; min-width: 0; }

/* 提示信息与按钮样式 */
.parse-tip { font-size: 0.8rem; margin-top: 8px; padding: 6px 12px; border-radius: 6px; text-align: center; }
.parse-tip.success { background: #ecfdf5; color: #059669; border: 1px solid #a7f3d0; }
.parse-tip.error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

.btn { padding: 10px 16px; border: none; border-radius: 8px; background: #399dff; color: white; cursor: pointer; font-weight: 500; font-size: 0.9rem; transition: all 0.2s; display: inline-flex; align-items: center; gap: 6px; }
.btn:hover { background: #2d7dd2; transform: translateY(-1px); }
.btn-icon { width: 32px; height: 32px; padding: 0; justify-content: center; border-radius: 6px; }
.btn-danger { background: #ef4444; }
.btn-danger:hover { background: #dc2626; }
.btn-secondary { background: #e5e7eb; color: #374151; }
.btn-primary { background: #4f46e5; }
.empty-state { padding: 60px 20px; text-align: center; color: #9ca3af; }

/* 弹出框样式 */
.modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.6); display: flex; align-items: center; justify-content: center; z-index: 9999; padding: 20px; }
.modal { background: white; border-radius: 16px; width: 100%; max-width: 420px; box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3); }
.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 20px 24px; border-bottom: 1px solid #e5e7eb; }
.modal-close { background: none; border: none; cursor: pointer; color: #9ca3af; padding: 4px; }
.modal-body { padding: 24px; }
.form-group { margin-bottom: 16px; }
.form-group label { display: block; font-size: 0.85rem; font-weight: 500; color: #374151; margin-bottom: 6px; }
.form-group .input { width: 100%; }
.move-preview { background: #f9fafb; border-radius: 8px; padding: 12px 16px; margin-top: 8px; }
.move-preview p { margin: 0; font-size: 0.9rem; color: #6b7280; }
.move-preview .target-preview { margin-top: 4px; font-weight: 600; color: #4f46e5; }
.modal-footer { display: flex; gap: 12px; justify-content: flex-end; padding: 16px 24px; border-top: 1px solid #e5e7eb; }
</style>
