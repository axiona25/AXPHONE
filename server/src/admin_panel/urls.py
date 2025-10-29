from django.urls import path
from . import views, dashboard_views, dashboard_sections, server_management, server_control, terminal_views, users_management, groups_management, react_dashboard_views

app_name = 'admin_panel'

urlpatterns = [
    # API per Dashboard React
    path('api/login/', react_dashboard_views.api_login_view, name='api_login'),
    path('api/logout/', react_dashboard_views.api_logout_view, name='api_logout'),
    path('api/current-user/', react_dashboard_views.api_current_user_view, name='api_current_user'),
    
    # Dashboard React (nuova - principale) - serve la React app per tutte le route
    path('', react_dashboard_views.react_dashboard_view, name='admin_dashboard'),
    path('dashboard/', react_dashboard_views.react_dashboard_view, name='dashboard'),
    path('login/', react_dashboard_views.react_dashboard_view, name='admin_login'),
    path('users/', react_dashboard_views.react_dashboard_view, name='users'),
    path('groups/', react_dashboard_views.react_dashboard_view, name='groups'),
    path('servers/', react_dashboard_views.react_dashboard_view, name='servers'),
    path('settings/', react_dashboard_views.react_dashboard_view, name='settings'),
    
    # Dashboard Django (vecchia - fallback)
    path('django/', dashboard_views.admin_dashboard, name='admin_dashboard_django'),
    
    # Pagina database viewer (vecchia, manteniamo per compatibilità)
    path('database/', views.database_viewer, name='database_viewer'),
    
    # API per Dashboard React
    path('api/login/', react_dashboard_views.api_login_view, name='api_login'),
    path('api/logout/', react_dashboard_views.api_logout_view, name='api_logout'),
    path('api/current-user/', react_dashboard_views.api_current_user_view, name='api_current_user'),
    
    # API Dashboard principali
    path('api/dashboard-stats/', dashboard_views.get_dashboard_stats, name='api_dashboard_stats'),
    path('api/dashboard-stats-test/', dashboard_views.get_dashboard_stats_test, name='api_dashboard_stats_test'),
    path('api/system-health/', dashboard_views.get_system_health, name='api_system_health'),
    path('api/users-management/', dashboard_views.get_users_management, name='api_users_management'),
    path('api/groups-management/', dashboard_views.get_groups_management, name='api_groups_management'),
    path('api/security-monitoring/', dashboard_views.get_security_monitoring, name='api_security_monitoring'),
    path('api/real-time-data/', dashboard_views.get_real_time_data, name='api_real_time_data'),
    
    # API sezioni aggiuntive
    path('api/devices-management/', dashboard_sections.get_devices_management, name='api_devices_management'),
    path('api/chats-management/', dashboard_sections.get_chats_management, name='api_chats_management'),
    path('api/media-management/', dashboard_sections.get_media_management, name='api_media_management'),
    path('api/calls-management/', dashboard_sections.get_calls_management, name='api_calls_management'),
    path('api/analytics-data/', dashboard_sections.get_analytics_data, name='api_analytics_data'),
    path('api/monitoring-data/', dashboard_sections.get_monitoring_data, name='api_monitoring_data'),
    
    # API nuove sezioni
    path('api/server-management/', server_management.get_server_management, name='api_server_management'),
    path('api/licenses-management/', server_management.get_licenses_management, name='api_licenses_management'),
    
    # API controllo server
    path('api/servers/status/', server_control.get_servers_status, name='api_servers_status'),
    path('api/servers/<str:service_id>/control/', server_control.control_server, name='api_control_server'),
    path('api/servers/<str:service_id>/logs/', server_control.get_service_logs, name='api_service_logs'),
    path('api/servers/<str:service_id>/performance/', server_control.get_server_performance, name='api_server_performance'),
    path('api/servers/bulk-action/', server_control.bulk_server_action, name='api_bulk_server_action'),
    
    # API terminale integrato
    path('api/terminal/session/', terminal_views.get_terminal_session, name='api_terminal_session'),
    path('api/terminal/input/', terminal_views.terminal_input, name='api_terminal_input'),
    path('api/terminal/output/', terminal_views.terminal_output, name='api_terminal_output'),
    path('api/terminal/resize/', terminal_views.terminal_resize, name='api_terminal_resize'),
    path('api/terminal/close/', terminal_views.terminal_close, name='api_terminal_close'),
    path('api/terminal/quick-command/', terminal_views.execute_quick_command, name='api_quick_command'),
    path('api/terminal/commands/', terminal_views.get_terminal_commands, name='api_terminal_commands'),
    path('api/system/info/', terminal_views.get_system_info, name='api_system_info'),
    
    # API gestione utenti avanzata
    path('api/users/advanced/', users_management.get_users_advanced, name='api_users_advanced'),
    path('api/users/create/', users_management.create_user, name='api_create_user'),
    path('api/users/<int:user_id>/update/', users_management.update_user, name='api_update_user'),
    path('api/users/<int:user_id>/delete/', users_management.delete_user, name='api_delete_user'),
    path('api/users/<int:user_id>/details/', users_management.get_user_details, name='api_user_details'),
    path('api/users/bulk-actions/', users_management.bulk_user_actions, name='api_bulk_user_actions'),
    path('api/users/filter-options/', users_management.get_filter_options, name='api_filter_options'),
    
    # API gestione gruppi avanzata
    path('api/groups/advanced/', groups_management.get_groups_advanced, name='api_groups_advanced'),
    path('api/groups/create-advanced/', groups_management.create_group, name='api_create_group_advanced'),
    path('api/groups/<str:group_id>/update/', groups_management.update_group, name='api_update_group'),
    path('api/groups/<str:group_id>/delete-advanced/', groups_management.delete_group, name='api_delete_group_advanced'),
    path('api/groups/<str:group_id>/members/', groups_management.get_group_members, name='api_group_members'),
    path('api/groups/<str:group_id>/manage-members/', groups_management.manage_group_members, name='api_manage_group_members'),
    path('api/groups/available-users/', groups_management.get_available_users, name='api_available_users'),
    
    # API azioni amministrative
    path('api/block-user/', dashboard_sections.block_user, name='api_block_user'),
    path('api/block-device/', dashboard_sections.block_device, name='api_block_device'),
    
    # API originali (manteniamo per compatibilità)
    path('api/users/', views.get_users_data, name='api_users'),
    path('api/users/delete/', views.delete_users_bulk, name='api_users_delete'),
    path('api/groups/', views.get_groups_data, name='api_groups'),
    path('api/groups/create/', views.create_group, name='api_groups_create'),
    path('api/groups/<uuid:group_id>/delete/', views.delete_group, name='api_groups_delete'),
    path('api/messages/', views.get_messages_data, name='api_messages'),
    path('api/sessions/', views.get_sessions_data, name='api_sessions'),
    path('api/statistics/', views.get_statistics, name='api_statistics'),
    path('api/conversations/', views.search_conversations, name='api_conversations'),
    
    # File statici dashboard React
    path('static/<path:file_path>', react_dashboard_views.react_static_files, name='react_static'),
    
    # Manifest e altri file della dashboard
    path('manifest.json', react_dashboard_views.react_static_files, {'file_path': '../manifest.json'}, name='react_manifest'),
    
]
