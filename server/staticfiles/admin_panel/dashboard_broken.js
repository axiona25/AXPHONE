// 🛡️ SecureVOX Admin Dashboard - JavaScript Functions

// === VARIABILI GLOBALI ===
let currentUsersData = null;
let currentGroupsData = null;
let selectedUsers = new Set();
let selectedGroups = new Set();

// === GESTIONE UTENTI ===
async function loadUsersSection() {
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
                <div class="stat-value">${usersData.statistics.total_users}</div>
                <div class="stat-change positive">
                    <i class="fas fa-plus"></i>
                    <span>+${usersData.statistics.new_users_24h} oggi</span>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon messages">
                        <i class="fas fa-user-check"></i>
                    </div>
                </div>
                <div class="stat-label">Utenti Attivi</div>
                <div class="stat-value">${usersData.statistics.active_users}</div>
                <div class="stat-change positive">
                    <i class="fas fa-wifi"></i>
                    <span>${usersData.statistics.online_users} online</span>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon system">
                        <i class="fas fa-user-slash"></i>
                    </div>
                </div>
                <div class="stat-label">Utenti Bloccati</div>
                <div class="stat-value">${usersData.statistics.blocked_users}</div>
                <div class="stat-change ${usersData.statistics.blocked_users > 0 ? 'negative' : 'positive'}">
                    <i class="fas fa-ban"></i>
                    <span>${usersData.statistics.blocked_users === 0 ? 'Nessuno' : 'Attenzione'}</span>
                </div>
            </div>
        </div>
        
        <!-- Filtri -->
        <div class="table-card mb-3">
            <div class="table-header">
                <h3 class="table-title">Filtri e Ricerca</h3>
                <div class="flex gap-2">
                    <button class="btn btn-primary btn-sm" onclick="showCreateUserModal()">
                        <i class="fas fa-user-plus"></i> Nuovo Utente
                    </button>
                    <button class="btn btn-secondary btn-sm" onclick="exportUsers()">
                        <i class="fas fa-download"></i> Esporta
                    </button>
                </div>
            </div>
            <div style="padding: 1rem 2rem;">
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                    <input type="text" id="users-search" placeholder="Cerca utenti..." style="padding: 0.5rem; border: 1px solid #ddd; border-radius: 8px;">
                    <select id="users-status-filter" style="padding: 0.5rem; border: 1px solid #ddd; border-radius: 8px;">
                        ${filtersData.status_options.map(option => `
                            <option value="${option.value}">${option.label}</option>
                        `).join('')}
                    </select>
                    <select id="users-group-filter" style="padding: 0.5rem; border: 1px solid #ddd; border-radius: 8px;">
                        <option value="">Tutti i gruppi</option>
                        ${filtersData.groups.map(group => `
                            <option value="${group.id}">${group.name}</option>
                        `).join('')}
                    </select>
                    <button class="btn btn-primary" onclick="filterUsers()">
                        <i class="fas fa-search"></i> Filtra
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Azioni Bulk -->
        <div class="table-card mb-3" id="users-bulk-actions" style="display: none;">
            <div class="table-header" style="background: rgba(38, 168, 132, 0.1);">
                <h3 class="table-title">
                    <i class="fas fa-tasks"></i> 
                    <span id="selected-users-count">0</span> utenti selezionati
                </h3>
                <div class="flex gap-2">
                    <button class="btn btn-primary btn-sm" onclick="bulkUserAction('unblock')">
                        <i class="fas fa-user-check"></i> Sblocca
                    </button>
                    <button class="btn btn-secondary btn-sm" onclick="bulkUserAction('block')">
                        <i class="fas fa-user-slash"></i> Blocca
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="bulkUserAction('delete')">
                        <i class="fas fa-trash"></i> Elimina
                    </button>
                    <button class="btn btn-secondary btn-sm" onclick="clearUsersSelection()">
                        <i class="fas fa-times"></i> Annulla
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Tabella Utenti -->
        <div class="table-card">
            <div class="table-responsive">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th style="width: 40px;">
                                <input type="checkbox" id="select-all-users" onchange="toggleSelectAllUsers(this)">
                            </th>
                            <th>Utente</th>
                            <th>Email</th>
                            <th>Stato</th>
                            <th>Gruppi</th>
                            <th>Dispositivi</th>
                            <th>Ultimo Accesso</th>
                            <th>Azioni</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${usersData.users.map(user => generateUserRow(user)).join('')}
                    </tbody>
                </table>
            </div>
            
            <!-- Paginazione -->
            <div style="padding: 1rem 2rem; border-top: 1px solid #eee;">
                <div class="flex justify-between items-center">
                    <span style="color: var(--text-secondary); font-size: 0.9rem;">
                        Mostra ${usersData.pagination.per_page} di ${usersData.pagination.total_count} utenti
                    </span>
                    <div class="flex gap-1">
                        <button class="btn btn-secondary btn-sm" 
                                onclick="loadUsersPage(${usersData.pagination.page - 1})"
                                ${!usersData.pagination.has_previous ? 'disabled' : ''}>
                            <i class="fas fa-chevron-left"></i>
                        </button>
                        <span style="padding: 0.5rem 1rem; color: var(--text-primary);">
                            ${usersData.pagination.page} / ${usersData.pagination.total_pages}
                        </span>
                        <button class="btn btn-secondary btn-sm" 
                                onclick="loadUsersPage(${usersData.pagination.page + 1})"
                                ${!usersData.pagination.has_next ? 'disabled' : ''}>
                            <i class="fas fa-chevron-right"></i>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
}

function generateUserRow(user) {
    return `
        <tr id="user-row-${user.id}">
            <td>
                <input type="checkbox" class="user-checkbox" value="${user.id}" onchange="updateUsersSelection()">
            </td>
            <td>
                <div class="flex items-center gap-2">
                    <div class="user-avatar" style="width: 32px; height: 32px; font-size: 0.8rem; background: var(--primary-gradient); color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center;">
                        ${user.username.charAt(0).toUpperCase()}
                    </div>
                    <div>
                        <div style="font-weight: 600;">${user.username}</div>
                        <div style="font-size: 0.8rem; color: var(--text-secondary);">${user.full_name}</div>
                    </div>
                </div>
            </td>
            <td>${user.email}</td>
            <td>
                <span class="status-badge ${user.is_active ? 'online' : 'offline'}">
                    <div class="live-dot" style="width: 6px; height: 6px;"></div>
                    ${user.is_active ? 'Attivo' : 'Bloccato'}
                </span>
                ${user.is_staff ? '<span class="status-badge warning" style="margin-left: 0.5rem;">Staff</span>' : ''}
                ${user.is_superuser ? '<span class="status-badge error" style="margin-left: 0.5rem;">Admin</span>' : ''}
            </td>
            <td>
                ${user.groups.length > 0 ? 
                    user.groups.map(group => `
                        <span class="status-badge" style="background: ${group.color}20; color: ${group.color}; border: 1px solid ${group.color}40;">
                            ${group.name}
                        </span>
                    `).join(' ') : 
                    '<span style="color: var(--text-tertiary);">Nessun gruppo</span>'
                }
            </td>
            <td>
                <span class="status-badge ${user.devices.length > 0 ? 'online' : 'offline'}">
                    <i class="fas fa-mobile-alt"></i> ${user.devices.length}
                </span>
                ${user.devices.some(d => d.is_compromised) ? 
                    '<span class="status-badge error" style="margin-left: 0.5rem;" title="Dispositivo compromesso">⚠️</span>' : ''
                }
            </td>
            <td>
                ${user.last_login ? 
                    `<span title="${new Date(user.last_login).toLocaleString()}">${getTimeAgo(user.last_login)}</span>` : 
                    '<span style="color: var(--text-tertiary);">Mai</span>'
                }
            </td>
            <td>
                <div class="flex gap-1">
                    <button class="btn btn-primary btn-sm" onclick="editUser(${user.id})" title="Modifica">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn btn-secondary btn-sm" onclick="viewUserDetails(${user.id})" title="Dettagli">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn ${user.is_active ? 'btn-danger' : 'btn-primary'} btn-sm" 
                            onclick="toggleUserStatus(${user.id})" 
                            title="${user.is_active ? 'Blocca' : 'Sblocca'}">
                        <i class="fas ${user.is_active ? 'fa-ban' : 'fa-check'}"></i>
                    </button>
                </div>
            </td>
        </tr>
    `;
}

// === GESTIONE GRUPPI ===
async function loadGroupsSection() {
    try {
        const response = await fetch('/admin/api/groups/advanced/');
        const groupsData = await response.json();
        
        currentGroupsData = groupsData;
        
        createDynamicSection('groups', 'Gestione Gruppi', generateGroupsHTML(groupsData));
        setupGroupsEventListeners();
        
    } catch (error) {
        console.error('Errore caricamento gruppi:', error);
        showNotification('❌ Errore caricamento gruppi', 'error');
    }
}

function generateGroupsHTML(groupsData) {
    return `
        <!-- Statistiche Gruppi -->
        <div class="stats-grid mb-3">
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon users">
                        <i class="fas fa-layer-group"></i>
                    </div>
                </div>
                <div class="stat-label">Gruppi Totali</div>
                <div class="stat-value">${groupsData.statistics.total_groups}</div>
                <div class="stat-change positive">
                    <i class="fas fa-check"></i>
                    <span>${groupsData.statistics.active_groups} attivi</span>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-header">
                    <div class="stat-icon messages">
                        <i class="fas fa-users"></i>
                    </div>
                </div>
                <div class="stat-label">Membri Totali</div>
                <div class="stat-value">${groupsData.statistics.total_members}</div>
                <div class="stat-change">
                    <i class="fas fa-calculator"></i>
                    <span>Media: ${groupsData.statistics.avg_members_per_group.toFixed(1)}</span>
                </div>
            </div>
        </div>
        
        <!-- Controlli Gruppi -->
        <div class="table-card mb-3">
            <div class="table-header">
                <h3 class="table-title">Gestione Gruppi</h3>
                <div class="flex gap-2">
                    <button class="btn btn-primary btn-sm" onclick="showCreateGroupModal()">
                        <i class="fas fa-plus"></i> Nuovo Gruppo
                    </button>
                    <button class="btn btn-secondary btn-sm" onclick="importGroups()">
                        <i class="fas fa-upload"></i> Importa
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Azioni Bulk Gruppi -->
        <div class="table-card mb-3" id="groups-bulk-actions" style="display: none;">
            <div class="table-header" style="background: rgba(38, 168, 132, 0.1);">
                <h3 class="table-title">
                    <i class="fas fa-tasks"></i> 
                    <span id="selected-groups-count">0</span> gruppi selezionati
                </h3>
                <div class="flex gap-2">
                    <button class="btn btn-secondary btn-sm" onclick="bulkGroupAction('export')">
                        <i class="fas fa-download"></i> Esporta
                    </button>
                    <button class="btn btn-danger btn-sm" onclick="bulkGroupAction('delete')">
                        <i class="fas fa-trash"></i> Elimina
                    </button>
                    <button class="btn btn-secondary btn-sm" onclick="clearGroupsSelection()">
                        <i class="fas fa-times"></i> Annulla
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Griglia Gruppi -->
        <div class="stats-grid">
            ${groupsData.groups.map(group => `
                <div class="stat-card group-card" id="group-${group.id}">
                    <div class="stat-header">
                        <div class="stat-icon" style="background: ${group.color};">
                            <i class="fas fa-users"></i>
                        </div>
                        <div style="display: flex; gap: 0.5rem;">
                            <input type="checkbox" class="group-checkbox" value="${group.id}" onchange="updateGroupsSelection()">
                            <button class="btn btn-secondary btn-sm" onclick="editGroup('${group.id}')" title="Modifica">
                                <i class="fas fa-edit"></i>
                            </button>
                        </div>
                    </div>
                    
                    <div class="stat-label">${group.name}</div>
                    <div class="stat-value">${group.members_count}</div>
                    <div class="stat-change">
                        <i class="fas fa-users"></i>
                        <span>membri</span>
                    </div>
                    
                    <div style="margin-top: 1rem; padding-top: 1rem; border-top: 1px solid #f0f0f0;">
                        <div style="font-size: 0.8rem; color: var(--text-secondary); margin-bottom: 0.5rem;">
                            ${group.description || 'Nessuna descrizione'}
                        </div>
                        <div style="display: flex; flex-wrap: wrap; gap: 0.25rem;">
                            ${group.permissions.slice(0, 3).map(perm => `
                                <span style="background: ${group.color}20; color: ${group.color}; padding: 0.1rem 0.4rem; border-radius: 4px; font-size: 0.7rem;">
                                    ${perm}
                                </span>
                            `).join('')}
                            ${group.permissions.length > 3 ? `<span style="color: var(--text-tertiary); font-size: 0.7rem;">+${group.permissions.length - 3}</span>` : ''}
                        </div>
                    </div>
                    
                    <div style="margin-top: 1rem;">
                        <button class="btn btn-primary btn-sm w-100" onclick="manageGroupMembers('${group.id}', '${group.name}')">
                            <i class="fas fa-users-cog"></i> Gestisci Membri
                        </button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

// === FUNZIONI UTENTI ===
function setupUsersEventListeners() {
    // Ricerca con debounce
    const searchInput = document.getElementById('users-search');
    if (searchInput) {
        searchInput.addEventListener('input', debounce(filterUsers, 300));
    }
    
    // Filtri
    const statusFilter = document.getElementById('users-status-filter');
    const groupFilter = document.getElementById('users-group-filter');
    
    if (statusFilter) statusFilter.addEventListener('change', filterUsers);
    if (groupFilter) groupFilter.addEventListener('change', filterUsers);
}

function toggleSelectAllUsers(checkbox) {
    const userCheckboxes = document.querySelectorAll('.user-checkbox');
    userCheckboxes.forEach(cb => {
        cb.checked = checkbox.checked;
        if (checkbox.checked) {
            selectedUsers.add(cb.value);
        } else {
            selectedUsers.delete(cb.value);
        }
    });
    updateUsersSelection();
}

function updateUsersSelection() {
    const checkboxes = document.querySelectorAll('.user-checkbox:checked');
    selectedUsers.clear();
    checkboxes.forEach(cb => selectedUsers.add(cb.value));
    
    const count = selectedUsers.size;
    const bulkActions = document.getElementById('users-bulk-actions');
    const countSpan = document.getElementById('selected-users-count');
    
    if (count > 0) {
        bulkActions.style.display = 'block';
        countSpan.textContent = count;
    } else {
        bulkActions.style.display = 'none';
    }
    
    // Aggiorna checkbox "seleziona tutto"
    const selectAll = document.getElementById('select-all-users');
    const totalCheckboxes = document.querySelectorAll('.user-checkbox').length;
    if (selectAll) {
        selectAll.checked = count === totalCheckboxes && count > 0;
        selectAll.indeterminate = count > 0 && count < totalCheckboxes;
    }
}

async function bulkUserAction(action) {
    if (selectedUsers.size === 0) {
        showNotification('❌ Nessun utente selezionato', 'error');
        return;
    }
    
    const actionNames = {
        'block': 'bloccare',
        'unblock': 'sbloccare', 
        'delete': 'eliminare',
        'make_staff': 'promuovere a staff',
        'remove_staff': 'rimuovere da staff'
    };
    
    if (!confirm(`Sei sicuro di voler ${actionNames[action]} ${selectedUsers.size} utenti?`)) {
        return;
    }
    
    try {
        const response = await fetch('/admin/api/users/bulk-actions/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRFToken': getCsrfToken(),
            },
            body: JSON.stringify({
                action,
                user_ids: Array.from(selectedUsers)
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            showNotification(`✅ ${result.message}`, 'success');
            clearUsersSelection();
            loadUsersSection(); // Ricarica
        } else {
            showNotification(`❌ ${result.message}`, 'error');
        }
        
    } catch (error) {
        showNotification(`❌ Errore: ${error.message}`, 'error');
    }
}

function clearUsersSelection() {
    selectedUsers.clear();
    document.querySelectorAll('.user-checkbox').forEach(cb => cb.checked = false);
    document.getElementById('select-all-users').checked = false;
    document.getElementById('users-bulk-actions').style.display = 'none';
}

async function toggleUserStatus(userId) {
    const user = currentUsersData.users.find(u => u.id === userId);
    if (!user) return;
    
    const action = user.is_active ? 'block' : 'unblock';
    
    try {
        const response = await fetch('/admin/api/users/bulk-actions/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRFToken': getCsrfToken(),
            },
            body: JSON.stringify({
                action,
                user_ids: [userId]
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            showNotification(`✅ Utente ${user.username} ${action === 'block' ? 'bloccato' : 'sbloccato'}`, 'success');
            loadUsersSection(); // Ricarica
        } else {
            showNotification(`❌ ${result.message}`, 'error');
        }
        
    } catch (error) {
        showNotification(`❌ Errore: ${error.message}`, 'error');
    }
}

// === FUNZIONI GRUPPI ===
function setupGroupsEventListeners() {
    // Event listeners per gruppi
}

function updateGroupsSelection() {
    const checkboxes = document.querySelectorAll('.group-checkbox:checked');
    selectedGroups.clear();
    checkboxes.forEach(cb => selectedGroups.add(cb.value));
    
    const count = selectedGroups.size;
    const bulkActions = document.getElementById('groups-bulk-actions');
    const countSpan = document.getElementById('selected-groups-count');
    
    if (count > 0) {
        bulkActions.style.display = 'block';
        countSpan.textContent = count;
    } else {
        bulkActions.style.display = 'none';
    }
}

// === UTILITY FUNCTIONS ===
function getTimeAgo(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);
    
    if (diffMins < 1) return 'Ora';
    if (diffMins < 60) return `${diffMins}m fa`;
    if (diffHours < 24) return `${diffHours}h fa`;
    if (diffDays < 7) return `${diffDays}g fa`;
    return date.toLocaleDateString();
}

async function filterUsers() {
    const search = document.getElementById('users-search')?.value || '';
    const status = document.getElementById('users-status-filter')?.value || 'all';
    const groupId = document.getElementById('users-group-filter')?.value || '';
    
    try {
        const params = new URLSearchParams({
            search,
            status,
            group_id: groupId,
            page: 1
        });
        
        const response = await fetch(`/admin/api/users/advanced/?${params}`);
        const data = await response.json();
        
        // Aggiorna solo la tabella
        updateUsersTable(data);
        
    } catch (error) {
        console.error('Errore filtro utenti:', error);
        showNotification('❌ Errore filtro utenti', 'error');
    }
}

function updateUsersTable(usersData) {
    const tbody = document.querySelector('#users-section tbody');
    if (tbody) {
        tbody.innerHTML = usersData.users.map(user => generateUserRow(user)).join('');
    }
    
    // Aggiorna statistiche
    const statsCards = document.querySelectorAll('#users-section .stat-value');
    if (statsCards.length >= 3) {
        statsCards[0].textContent = usersData.statistics.total_users;
        statsCards[1].textContent = usersData.statistics.active_users;
        statsCards[2].textContent = usersData.statistics.blocked_users;
    }
}

function resetUsersFilters() {
    document.getElementById('users-search').value = '';
    document.getElementById('users-status-filter').value = 'all';
    document.getElementById('users-group-filter').value = '';
    filterUsers();
}

// Placeholder functions
function showCreateUserModal() {
    showNotification('🚧 Modal creazione utente in sviluppo', 'info');
}

function editUser(userId) {
    showNotification(`🚧 Modifica utente ${userId} in sviluppo`, 'info');
}

function viewUserDetails(userId) {
    showNotification(`🚧 Dettagli utente ${userId} in sviluppo`, 'info');
}

function showCreateGroupModal() {
    showNotification('🚧 Modal creazione gruppo in sviluppo', 'info');
}

function editGroup(groupId) {
    showNotification(`🚧 Modifica gruppo ${groupId} in sviluppo`, 'info');
}

function manageGroupMembers(groupId, groupName) {
    showNotification(`🚧 Gestione membri gruppo "${groupName}" in sviluppo`, 'info');
}

function exportUsers() {
    showNotification('🚧 Export utenti in sviluppo', 'info');
}

function importGroups() {
    showNotification('🚧 Import gruppi in sviluppo', 'info');
}
