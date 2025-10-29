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
        console.log('🚀 Inizializzazione dashboard SecureVOX...');
        showNotification('🚀 Inizializzazione dashboard...', 'info');
        
        // Setup navigazione
        setupNavigation();
        
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

function setupNavigation() {
    // Setup click handlers per sidebar
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            // Rimuovi active da tutti
            document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
            
            // Aggiungi active al clicked
            this.classList.add('active');
            
            // Estrai sezione dal onclick
            const onclick = this.getAttribute('onclick');
            if (onclick) {
                const match = onclick.match(/loadSection\('([^']+)'\)/);
                if (match) {
                    loadSectionData(match[1]);
                }
            }
        });
    });
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
        const response = await fetch('/admin/api/dashboard-stats-test/', {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
            }
        });
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
    
    // Aggiorna con gli ID corretti dal template
    const totalUsersEl = document.getElementById('total-users');
    const messagesEl = document.getElementById('messages-24h');
    const callsEl = document.getElementById('active-calls');
    const healthEl = document.getElementById('health-score');
    const usersGrowthEl = document.getElementById('users-growth');
    const messagesGrowthEl = document.getElementById('messages-growth');
    
    if (totalUsersEl) totalUsersEl.textContent = stats.total_users || '0';
    if (messagesEl) messagesEl.textContent = stats.total_messages || '0';
    if (callsEl) callsEl.textContent = stats.total_calls || '0';
    if (healthEl) healthEl.textContent = `${stats.system_health || 0}%`;
    if (usersGrowthEl) usersGrowthEl.textContent = `+${stats.active_users || 0}`;
    if (messagesGrowthEl) messagesGrowthEl.textContent = `+${stats.messages_24h || 0}`;
    
    console.log('✅ Statistiche aggiornate:', stats);
}

// === GESTIONE UTENTI AVANZATA ===
async function loadUsersAdvanced() {
    try {
        console.log('🔄 Caricamento dati utenti avanzati...');
        
        const response = await fetch('/admin/api/users-management/', {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        // Trasforma i dati per il display
        const usersData = {
            statistics: {
                total_users: data.pagination?.total || data.users?.length || 0,
                active_users: data.users?.filter(u => u.is_active).length || 0,
                blocked_users: data.users?.filter(u => !u.is_active).length || 0,
                online_users: data.users?.filter(u => u.last_login && new Date(u.last_login) > new Date(Date.now() - 5 * 60 * 1000)).length || 0,
                new_users_24h: 0 // Calcoleremo questo
            },
            users: data.users || []
        };
        
        console.log('✅ Dati utenti caricati:', usersData);
        currentUsersData = usersData;
        createDynamicSection('users', 'Gestione Utenti', generateUsersHTML(usersData, {}));
        
    } catch (error) {
        console.error('Errore caricamento utenti:', error);
        showNotification('❌ Errore caricamento utenti: ' + error.message, 'error');
        
        // Fallback con dati mock in caso di errore
        const fallbackData = {
            statistics: {
                total_users: 3,
                active_users: 1,
                blocked_users: 0,
                online_users: 1,
                new_users_24h: 0
            },
            users: [
                {
                    id: 1,
                    username: 'admin',
                    email: 'admin@securevox.com',
                    full_name: 'Amministratore',
                    is_active: true,
                    is_staff: true,
                    is_superuser: true,
                    last_login: new Date().toISOString(),
                    groups: [],
                    devices: []
                }
            ]
        };
        currentUsersData = fallbackData;
        createDynamicSection('users', 'Gestione Utenti', generateUsersHTML(fallbackData, {}));
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
        const response = await fetch('/admin/api/groups/advanced/', {
            credentials: 'same-origin',
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
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
        console.log('🔄 Caricamento stato server...');
        
        const response = await fetch('/admin/api/servers/status/', {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        console.log('✅ Dati server caricati:', data);
        statusData = data;
        createDynamicSection('server', 'Controllo Server', generateServerHTML(data));
        
    } catch (error) {
        console.error('Errore caricamento server:', error);
        showNotification('❌ Errore caricamento server: ' + error.message, 'error');
        
        // Fallback con dati mock in caso di errore
        const fallbackData = {
            servers: {
                'django_api': {
                    name: 'Django API Server',
                    status: 'running',
                    port: 8001,
                    color: '#26A884',
                    icon: 'fas fa-server'
                },
                'call_server': {
                    name: 'Call Server',
                    status: 'running',
                    port: 8003,
                    color: '#2196F3',
                    icon: 'fas fa-phone'
                },
                'notify_server': {
                    name: 'Notification Server',
                    status: 'running',
                    port: 8002,
                    color: '#FF9800',
                    icon: 'fas fa-bell'
                }
            }
        };
        
        statusData = fallbackData;
        createDynamicSection('server', 'Controllo Server', generateServerHTML(fallbackData));
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
    
    // Crea toast notification visibile
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${type === 'error' ? '#F44336' : type === 'success' ? '#26A884' : '#2196F3'};
        color: white;
        padding: 1rem 1.5rem;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        z-index: 10000;
        font-family: 'Poppins', sans-serif;
        font-weight: 500;
        max-width: 400px;
        word-wrap: break-word;
    `;
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    // Rimuovi dopo 4 secondi
    setTimeout(() => {
        if (toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
    }, 4000);
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
async function loadDevicesSection() {
    try {
        console.log('🔄 Caricamento gestione dispositivi...');
        
        const response = await fetch('/admin/api/devices-management/', {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        console.log('✅ Dati dispositivi caricati:', data);
        createDynamicSection('devices', 'Gestione Dispositivi', generateDevicesHTML(data));
        
    } catch (error) {
        console.error('Errore caricamento dispositivi:', error);
        showNotification('❌ Errore caricamento dispositivi: ' + error.message, 'error');
        showComingSoon('devices');
    }
}
async function loadChatsSection() {
    try {
        console.log('🔄 Caricamento gestione chat...');
        
        const response = await fetch('/admin/api/chats-management/', {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        console.log('✅ Dati chat caricati:', data);
        createDynamicSection('chats', 'Gestione Chat', generateChatsHTML(data));
        
    } catch (error) {
        console.error('Errore caricamento chat:', error);
        showNotification('❌ Errore caricamento chat: ' + error.message, 'error');
        showComingSoon('chats');
    }
}
async function loadMediaSection() { showComingSoon('media'); }
async function loadCallsSection() { showComingSoon('calls'); }
async function loadSecuritySection() {
    try {
        console.log('🔄 Caricamento monitoraggio sicurezza...');
        
        const response = await fetch('/admin/api/security-monitoring/', {
            credentials: 'same-origin',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            throw new Error(data.error);
        }
        
        console.log('✅ Dati sicurezza caricati:', data);
        createDynamicSection('security', 'Monitoraggio Sicurezza', generateSecurityHTML(data));
        
    } catch (error) {
        console.error('Errore caricamento sicurezza:', error);
        showNotification('❌ Errore caricamento sicurezza: ' + error.message, 'error');
        showComingSoon('security');
    }
}
async function loadAnalyticsSection() { showComingSoon('analytics'); }
async function loadMonitoringSection() { showComingSoon('monitoring'); }
async function loadServerManagement() { 
    try {
        const response = await fetch('/admin/api/server-management/', {
            credentials: 'same-origin',
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        const data = await response.json();
        createDynamicSection('management', 'Gestione Server', generateServerManagementHTML(data));
    } catch (error) {
        showComingSoon('management');
    }
}

async function loadLicensesSection() { 
    try {
        const response = await fetch('/admin/api/licenses-management/', {
            credentials: 'same-origin',
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        const data = await response.json();
        createDynamicSection('licenses', 'Gestione Licenze', generateLicensesHTML(data));
    } catch (error) {
        showComingSoon('licenses');
    }
}

async function loadSettingsSection() { 
    createDynamicSection('settings', 'Impostazioni', `
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Configurazioni Sistema</h3>
            </div>
            <div style="padding: 2rem;">
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-header">
                            <div class="stat-icon system">
                                <i class="fas fa-cog"></i>
                            </div>
                        </div>
                        <div class="stat-label">Configurazioni</div>
                        <div class="stat-value">12</div>
                        <div class="stat-change">impostazioni</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-header">
                            <div class="stat-icon users">
                                <i class="fas fa-shield-alt"></i>
                            </div>
                        </div>
                        <div class="stat-label">Sicurezza</div>
                        <div class="stat-value">Alto</div>
                        <div class="stat-change positive">livello</div>
                    </div>
                </div>
            </div>
        </div>
    `);
}

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

function generateServerManagementHTML(data) {
    return `
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Gestione Server</h3>
            </div>
            <div style="padding: 2rem;">
                <p>Gestione avanzata dei server SecureVOX</p>
            </div>
        </div>
    `;
}

function generateLicensesHTML(data) {
    return `
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Gestione Licenze</h3>
            </div>
            <div style="padding: 2rem;">
                <p>Gestione licenze e rinnovi</p>
            </div>
        </div>
    `;
}

// === GESTIONE USER DROPDOWN ===
function toggleUserDropdown() {
    const dropdown = document.getElementById('userDropdown');
    const userInfo = document.querySelector('.user-info');
    
    if (dropdown && userInfo) {
        if (dropdown.classList.contains('show')) {
            dropdown.classList.remove('show');
        } else {
            // Calcola la posizione corretta
            const rect = userInfo.getBoundingClientRect();
            dropdown.style.top = (rect.bottom + 5) + 'px';
            dropdown.style.right = (window.innerWidth - rect.right) + 'px';
            
            dropdown.classList.add('show');
        }
        
        // Chiudi dropdown se si clicca fuori
        document.addEventListener('click', function closeDropdown(e) {
            if (!e.target.closest('.user-info')) {
                dropdown.classList.remove('show');
                document.removeEventListener('click', closeDropdown);
            }
        });
    }
}

function showProfile() {
    showNotification('👤 Profilo utente - Funzionalità in sviluppo', 'info');
    document.getElementById('userDropdown').classList.remove('show');
}

function confirmLogout(event) {
    event.preventDefault();
    
    if (confirm('Sei sicuro di voler effettuare il logout?')) {
        showNotification('🚪 Logout in corso...', 'info');
        
        // Redirect al logout dopo un breve delay
        setTimeout(() => {
            window.location.href = '/admin/logout/';
        }, 1000);
    } else {
        document.getElementById('userDropdown').classList.remove('show');
    }
}

// === FUNZIONI NAVIGAZIONE ===
function loadSection(section) {
    // Rimuovi classe active da tutti i link
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    // Aggiungi classe active al link cliccato
    event.target.closest('.nav-link').classList.add('active');
    
    // Carica la sezione
    loadSectionData(section);
}

function toggleMobileMenu() {
    const sidebar = document.getElementById('sidebar');
    sidebar.classList.toggle('open');
}

function refreshData() {
    console.log('🔄 Aggiornamento dati...');
    if (currentSection === 'dashboard') {
        loadDashboardData();
    } else {
        loadSectionData(currentSection);
    }
    showNotification('🔄 Dati aggiornati', 'success');
}

// === FUNZIONI HTML GENERATOR ===
function generateDevicesHTML(data) {
    const devices = data.devices || [];
    
    return `
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Gestione Dispositivi</h3>
                <div class="table-actions">
                    <button class="btn btn-primary btn-sm" onclick="refreshData()">
                        <i class="fas fa-sync"></i> Aggiorna
                    </button>
                </div>
            </div>
            
            <div class="stats-grid mb-3">
                <div class="stat-card">
                    <div class="stat-label">Totale Dispositivi</div>
                    <div class="stat-value">${devices.length}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Attivi</div>
                    <div class="stat-value">${devices.filter(d => d.is_active).length}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Compromessi</div>
                    <div class="stat-value">${devices.filter(d => d.is_compromised).length}</div>
                </div>
            </div>
            
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>Nome</th>
                            <th>Tipo</th>
                            <th>Utente</th>
                            <th>Stato</th>
                            <th>Ultimo Accesso</th>
                            <th>Azioni</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${devices.map(device => `
                            <tr>
                                <td>${device.device_name || 'N/A'}</td>
                                <td>
                                    <span class="device-type-badge ${device.device_type || 'unknown'}">
                                        ${device.device_type || 'Unknown'}
                                    </span>
                                </td>
                                <td>${device.user || 'N/A'}</td>
                                <td>
                                    <span class="status-badge ${device.is_active ? 'online' : 'offline'}">
                                        ${device.is_active ? 'Attivo' : 'Inattivo'}
                                    </span>
                                </td>
                                <td>${device.last_seen ? new Date(device.last_seen).toLocaleString() : 'Mai'}</td>
                                <td>
                                    <button class="btn btn-warning btn-sm" onclick="blockDevice('${device.id}')">
                                        <i class="fas fa-ban"></i>
                                    </button>
                                </td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function generateChatsHTML(data) {
    const chats = data.chats || [];
    
    return `
        <div class="table-card">
            <div class="table-header">
                <h3 class="table-title">Gestione Chat</h3>
                <div class="table-actions">
                    <button class="btn btn-primary btn-sm" onclick="refreshData()">
                        <i class="fas fa-sync"></i> Aggiorna
                    </button>
                </div>
            </div>
            
            <div class="stats-grid mb-3">
                <div class="stat-card">
                    <div class="stat-label">Totale Chat</div>
                    <div class="stat-value">${chats.length}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Attive</div>
                    <div class="stat-value">${chats.filter(c => c.is_active).length}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Messaggi Totali</div>
                    <div class="stat-value">${chats.reduce((sum, c) => sum + (c.message_count || 0), 0)}</div>
                </div>
            </div>
            
            <div class="table-responsive">
                <table class="table">
                    <thead>
                        <tr>
                            <th>ID Chat</th>
                            <th>Partecipanti</th>
                            <th>Messaggi</th>
                            <th>Ultimo Messaggio</th>
                            <th>Stato</th>
                            <th>Azioni</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${chats.map(chat => `
                            <tr>
                                <td>${chat.id || 'N/A'}</td>
                                <td>${chat.participants || 'N/A'}</td>
                                <td>${chat.message_count || 0}</td>
                                <td>${chat.last_message ? new Date(chat.last_message).toLocaleString() : 'Mai'}</td>
                                <td>
                                    <span class="status-badge ${chat.is_active ? 'online' : 'offline'}">
                                        ${chat.is_active ? 'Attiva' : 'Inattiva'}
                                    </span>
                                </td>
                                <td>
                                    <button class="btn btn-info btn-sm" onclick="viewChat('${chat.id}')">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                </td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        </div>
    `;
}

function generateSecurityHTML(data) {
    const events = data.events || [];
    const stats = data.statistics || {};
    
    return `
        <div class="security-dashboard">
            <div class="stats-grid mb-3">
                <div class="stat-card">
                    <div class="stat-label">Login Falliti (24h)</div>
                    <div class="stat-value">${stats.failed_logins_24h || 0}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">IP Bloccati</div>
                    <div class="stat-value">${stats.blocked_ips || 0}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Dispositivi Compromessi</div>
                    <div class="stat-value">${stats.compromised_devices || 0}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Livello Minaccia</div>
                    <div class="stat-value">
                        <span class="threat-level ${data.threat_level || 'low'}">
                            ${data.threat_level || 'Basso'}
                        </span>
                    </div>
                </div>
            </div>
            
            <div class="table-card">
                <div class="table-header">
                    <h3 class="table-title">Eventi di Sicurezza Recenti</h3>
                </div>
                
                <div class="table-responsive">
                    <table class="table">
                        <thead>
                            <tr>
                                <th>Tipo</th>
                                <th>Severità</th>
                                <th>Descrizione</th>
                                <th>IP</th>
                                <th>Timestamp</th>
                                <th>Azioni</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${events.map(event => `
                                <tr>
                                    <td>
                                        <span class="event-type-badge ${event.type}">
                                            ${event.type || 'N/A'}
                                        </span>
                                    </td>
                                    <td>
                                        <span class="severity-badge ${event.severity}">
                                            ${event.severity || 'N/A'}
                                        </span>
                                    </td>
                                    <td>${event.description || 'N/A'}</td>
                                    <td>${event.ip_address || 'N/A'}</td>
                                    <td>${event.timestamp ? new Date(event.timestamp).toLocaleString() : 'N/A'}</td>
                                    <td>
                                        <button class="btn btn-warning btn-sm" onclick="investigateEvent('${event.id}')">
                                            <i class="fas fa-search"></i>
                                        </button>
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    `;
}
