// 🛡️ SecureVOX Admin Dashboard - JavaScript Functions Complete

// === VARIABILI GLOBALI ===
let charts = {};
let realTimeInterval;
let currentSection = 'dashboard';
let statusData = {};
let currentUsersData = null;
let currentGroupsData = null;
let selectedUsers = new Set();
let selectedGroups = new Set();

// === INIZIALIZZAZIONE ===
document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
});

async function initializeApp() {
    try {
        showNotification('🚀 Inizializzazione dashboard...', 'info');
        
        // Carica dashboard principale
        await loadDashboardData();
        
        // Avvia aggiornamenti real-time
        startRealTimeUpdates();
        
        showNotification('✅ Dashboard inizializzata', 'success');
        
    } catch (error) {
        console.error('Errore inizializzazione:', error);
        showNotification('❌ Errore inizializzazione dashboard', 'error');
    }
}

// === GESTIONE SEZIONI ===
async function loadSectionData(section) {
    try {
        switch (section) {
            case 'users':
                await loadUsersAdvanced();
                break;
            case 'groups':
                await loadGroupsAdvanced();
                break;
            case 'server':
                await loadServerSection();
                break;
            case 'devices':
                await loadDevicesSection();
                break;
            case 'chats':
                await loadChatsSection();
                break;
            case 'media':
                await loadMediaSection();
                break;
            case 'calls':
                await loadCallsSection();
                break;
            case 'security':
                await loadSecuritySection();
                break;
            case 'analytics':
                await loadAnalyticsSection();
                break;
            case 'monitoring':
                await loadMonitoringSection();
                break;
            case 'management':
                await loadServerManagement();
                break;
            case 'licenses':
                await loadLicensesSection();
                break;
            case 'settings':
                await loadSettingsSection();
                break;
            default:
                await loadDashboardData();
        }
        currentSection = section;
    } catch (error) {
        console.error(`Errore caricamento sezione ${section}:`, error);
        showNotification(`❌ Errore caricamento ${section}`, 'error');
    }
}

// === DASHBOARD PRINCIPALE ===
async function loadDashboardData() {
    try {
        const response = await fetch('/admin/api/dashboard-stats/');
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        updateDashboardStats(data);
        createSystemHealthChart(data.system_health);
        
    } catch (error) {
        console.error('Errore caricamento dashboard:', error);
        showNotification('❌ Errore caricamento dashboard', 'error');
    }
}

function updateDashboardStats(data) {
    // Aggiorna statistiche principali
    const stats = data.stats;
    
    document.getElementById('total-users').textContent = stats.total_users || '0';
    document.getElementById('total-messages').textContent = stats.total_messages || '0';
    document.getElementById('total-calls').textContent = stats.total_calls || '0';
    document.getElementById('system-health').textContent = `${stats.system_health || 0}%`;
}

// === GESTIONE UTENTI AVANZATA ===
async function loadUsersAdvanced() {
    try {
        const [usersResponse, filtersResponse] = await Promise.all([
            fetch('/admin/api/users/advanced/'),
            fetch('/admin/api/users/filter-options/')
        ]);
        
        const usersData = await usersResponse.json();
        const filtersData = await filtersResponse.json();
        
        currentUsersData = usersData;
        
        createDynamicSection('users', 'Gestione Utenti', generateUsersHTML(usersData, filtersData));
        setupUsersEventListeners();
        
    } catch (error) {
        console.error('Errore caricamento utenti:', error);
        showNotification('❌ Errore caricamento utenti', 'error');
    }
}

function generateUsersHTML(usersData, filtersData) {
    return `
        <!-- Statistiche Utenti -->
        <div class="stats-grid mb-3">
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon users">
                        <i class="fas fa-users"></i>
                    </div>
                </div>
                <div class="stat-label">Utenti Totali</div>
                <div class="stat-value">${usersData.statistics?.total_users || 0}</div>
                <div class="stat-change positive">
                    <i class="fas fa-plus"></i>
                    <span>+${usersData.statistics?.new_users_24h || 0} oggi</span>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon messages">
                        <i class="fas fa-user-check"></i>
                    </div>
                </div>
                <div class="stat-label">Utenti Attivi</div>
                <div class="stat-value">${usersData.statistics?.active_users || 0}</div>
                <div class="stat-change positive">
                    <i class="fas fa-wifi"></i>
                    <span>${usersData.statistics?.online_users || 0} online</span>
                </div>
            </div>
        </div>
        
        <!-- Tabella Utenti -->
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Lista Utenti</h3>
                <div class="flex gap-2">
                    <button class="btn btn-primary btn-sm" onclick="showCreateUserModal()">
                        <i class="fas fa-user-plus"></i> Nuovo
                    </button>
                </div>
            </div>
            <div class="table-responsive">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th><input type="checkbox" id="select-all-users" onchange="toggleSelectAllUsers(this)"></th>
                            <th>Utente</th>
                            <th>Email</th>
                            <th>Stato</th>
                            <th>Azioni</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${(usersData.users || []).map(user => generateUserRow(user)).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function generateUserRow(user) {
    return `
        <tr id="user-row-${user.id}">
            <td><input type="checkbox" class="user-checkbox" value="${user.id}" onchange="updateUsersSelection()"></td>
            <td>${user.username || 'N/A'}</td>
            <td>${user.email || 'N/A'}</td>
            <td><span class="status-badge ${user.is_active ? 'online' : 'offline'}">${user.is_active ? 'Attivo' : 'Inattivo'}</span></td>
            <td>
                <button class="btn btn-primary btn-sm" onclick="editUser(${user.id})">
                    <i class="fas fa-edit"></i>
                </button>
            </td>
        </tr>
    `;
}

// === GESTIONE GRUPPI ===
async function loadGroupsAdvanced() {
    try {
        const response = await fetch('/admin/api/groups/advanced/');
        const groupsData = await response.json();
        
        currentGroupsData = groupsData;
        
        createDynamicSection('groups', 'Gestione Gruppi', generateGroupsHTML(groupsData));
        
    } catch (error) {
        console.error('Errore caricamento gruppi:', error);
        showNotification('❌ Errore caricamento gruppi', 'error');
    }
}

function generateGroupsHTML(groupsData) {
    return `
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Gestione Gruppi</h3>
                <button class="btn btn-primary btn-sm" onclick="showCreateGroupModal()">
                    <i class="fas fa-plus"></i> Nuovo Gruppo
                </button>
            </div>
            <div class="stats-grid">
                ${(groupsData.groups || []).map(group => `
                    <div class="stat-card">
                        <div class="stat-label">${group.name || 'Gruppo'}</div>
                        <div class="stat-value">${group.members_count || 0}</div>
                        <div class="stat-change">membri</div>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
}

// === GESTIONE SERVER ===
async function loadServerSection() {
    try {
        const response = await fetch('/admin/api/servers/status/');
        const data = await response.json();
        
        statusData = data;
        
        createDynamicSection('server', 'Controllo Server', generateServerHTML(data));
        
    } catch (error) {
        console.error('Errore caricamento server:', error);
        showNotification('❌ Errore caricamento server', 'error');
    }
}

function generateServerHTML(data) {
    const servers = data.servers || {};
    
    return `
        <div class="stats-grid">
            ${Object.entries(servers).map(([id, server]) => `
                <div class="stat-card server-card" id="server-${id}">
                    <div class="stat-header">
                        <div class="stat-icon" style="color: ${server.color || '#26A884'};">
                            <i class="${server.icon || 'fas fa-server'}"></i>
                        </div>
                        <button class="server-info-btn" onclick="showServerInfo('${id}')" title="Informazioni">
                            <i class="fas fa-info"></i>
                        </button>
                    </div>
                    
                    <div class="stat-label">${server.name}</div>
                    <div class="stat-value">
                        <span class="status-badge ${server.status === 'running' ? 'online' : 'offline'}">
                            ${server.status === 'running' ? 'Attivo' : 'Spento'}
                        </span>
                    </div>
                    
                    <div class="server-controls-compact">
                        <button class="control-btn-compact start-btn" onclick="controlServer('${id}', 'start')" ${server.status === 'running' ? 'disabled' : ''}>
                            <i class="fas fa-play"></i>
                        </button>
                        <button class="control-btn-compact stop-btn" onclick="controlServer('${id}', 'stop')" ${server.status !== 'running' ? 'disabled' : ''}>
                            <i class="fas fa-stop"></i>
                        </button>
                        <button class="control-btn-compact restart-btn" onclick="controlServer('${id}', 'restart')" ${server.status !== 'running' ? 'disabled' : ''}>
                            <i class="fas fa-redo"></i>
                        </button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

// === UTILITY FUNCTIONS ===
function createDynamicSection(id, title, content) {
    const container = document.querySelector('.loading-section');
    container.innerHTML = `
        <div class="section-header">
            <h2>${title}</h2>
        </div>
        <div id="${id}-section">
            ${content}
        </div>
    `;
    container.style.display = 'block';
}

function showNotification(message, type = 'info') {
    console.log(`[${type.toUpperCase()}] ${message}`);
    // Implementazione toast notification
}

function getCsrfToken() {
    return document.querySelector('[name=csrfmiddlewaretoken]')?.value || '';
}

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// === REAL-TIME UPDATES ===
function startRealTimeUpdates() {
    realTimeInterval = setInterval(async () => {
        if (currentSection === 'dashboard') {
            await loadDashboardData();
        }
    }, 30000); // Ogni 30 secondi
}

// === FUNZIONI PLACEHOLDER ===
function setupUsersEventListeners() {}
function toggleSelectAllUsers(checkbox) {}
function updateUsersSelection() {}
function showCreateUserModal() { showNotification('🚧 In sviluppo', 'info'); }
function editUser(id) { showNotification('🚧 In sviluppo', 'info'); }
function showCreateGroupModal() { showNotification('🚧 In sviluppo', 'info'); }
function showServerInfo(id) { showNotification('🚧 In sviluppo', 'info'); }
function controlServer(id, action) { showNotification(`🚧 ${action} server ${id}`, 'info'); }

// === SEZIONI PLACEHOLDER ===
async function loadDevicesSection() { showComingSoon('devices'); }
async function loadChatsSection() { showComingSoon('chats'); }
async function loadMediaSection() { showComingSoon('media'); }
async function loadCallsSection() { showComingSoon('calls'); }
async function loadSecuritySection() { showComingSoon('security'); }
async function loadAnalyticsSection() { showComingSoon('analytics'); }
async function loadMonitoringSection() { showComingSoon('monitoring'); }
async function loadServerManagement() { showComingSoon('management'); }
async function loadLicensesSection() { showComingSoon('licenses'); }
async function loadSettingsSection() { showComingSoon('settings'); }

function showComingSoon(section) {
    createDynamicSection(section, section.charAt(0).toUpperCase() + section.slice(1), `
        <div style="text-align: center; padding: 4rem;">
            <i class="fas fa-tools" style="font-size: 4rem; color: #ccc; margin-bottom: 2rem;"></i>
            <h3>Sezione in Sviluppo</h3>
            <p style="color: #666;">Questa sezione sarà disponibile presto.</p>
        </div>
    `);
}

function createSystemHealthChart(data) {
    // Chart placeholder
}
