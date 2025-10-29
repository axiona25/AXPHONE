from django.urls import path, include
from .views import (
    health, version, get_users, register_device, upload_keybundle, 
    get_keybundle, send_message, remote_wipe, get_ice_servers,
    create_call, create_group_call, end_call, update_call_status, get_call_timer, get_calls, get_chats, create_chat, delete_chat, get_chat_messages, send_chat_message, send_push_notification, mark_messages_as_read, delete_message_for_user, request_chat_deletion, respond_to_chat_deletion, mark_gestation_notification_seen, get_users_status, update_my_status, get_pending_calls, mark_call_seen
)
from .encrypted_calls_views import (
    call_encryption_stats, rotate_call_keys, call_security_info, verify_call_encryption
)
from .debug_views import debug_call_creation
from .debug_polling_views import debug_active_calls, force_app_polling_restart
from .call_cleanup_views import cleanup_user_calls, cleanup_all_calls, cleanup_expired_calls
from .test_calls_views import test_pending_calls_for_user, test_create_call_direct
from .emergency_views import emergency_stop_polling, emergency_status
from .force_logout_views import force_logout_all_users, check_active_sessions
from .authentication import (
    register_user, login_user, logout_user, verify_token,
    update_profile, change_password, upload_avatar, delete_avatar,
    request_password_reset, reset_password, auto_logout, verify_email_exists
)
from .enhanced_authentication import (
    enhanced_register_user, enhanced_login_user, enhanced_logout_user, enhanced_verify_token
)
from .securevox_call_integration import (
    generate_call_token, call_server_webhook, call_stats, 
    create_webrtc_call, end_webrtc_call
)
from .e2e_views import (
    upload_public_key, get_user_public_key, get_my_public_key, get_multiple_keys
)
from .chat_monitoring_views import (
    chat_statistics, users_list, user_chats, chat_messages, reset_user_password,
    block_user, unblock_user, delete_user, toggle_user_e2e,
    dashboard_statistics
)

urlpatterns = [
    # Health and version
    path("health/", health, name="health"),
    path("version/", version, name="version"),
    
    # Authentication (enhanced with status management)
    path("auth/register/", enhanced_register_user, name="register_user"),
    path("auth/login/", enhanced_login_user, name="login_user"),
    path("auth/logout/", enhanced_logout_user, name="logout_user"),
    path("auth/auto-logout/", auto_logout, name="auto_logout"),  # NUOVO: Per hot reload
    path("auth/verify/", enhanced_verify_token, name="verify_token"),
    path("auth/change-password/", change_password, name="change_password"),
    path("auth/verify-email/", verify_email_exists, name="verify_email_exists"),
    path("auth/request-reset/", request_password_reset, name="request_password_reset"),
    path("auth/reset-password/", reset_password, name="reset_password"),
    
    # Legacy authentication (fallback)
    path("auth/legacy/register/", register_user, name="legacy_register_user"),
    path("auth/legacy/login/", login_user, name="legacy_login_user"),
    path("auth/legacy/logout/", logout_user, name="legacy_logout_user"),
    path("auth/legacy/verify/", verify_token, name="legacy_verify_token"),
    
    # User management
    path("users/", get_users, name="get_users"),
    path("users/status/", get_users_status, name="get_users_status"),
    path("users/update-status/", update_my_status, name="update_my_status"),
    path("users/<int:user_id>/", update_profile, name="update_profile"),
    path("users/avatar/", upload_avatar, name="upload_avatar"),
    path("users/avatar/delete/", delete_avatar, name="delete_avatar"),
    
    # Device management
    path("devices/register/", register_device, name="register_device"),
    
    # Crypto APIs
    path("crypto/keybundle/upload/", upload_keybundle, name="upload_keybundle"),
    path("crypto/keybundle/<int:user_id>/", get_keybundle, name="get_keybundle"),
    
    # E2EE (End-to-End Encryption) APIs
    path("e2e/upload-key/", upload_public_key, name="upload_public_key"),
    path("e2e/get-key/<int:user_id>/", get_user_public_key, name="get_user_public_key"),
    path("e2e/my-key/", get_my_public_key, name="get_my_public_key"),
    path("e2e/get-keys/", get_multiple_keys, name="get_multiple_keys"),
    
    # Messaging
    path("messages/send/", send_message, name="send_message"),
    
    # Chat APIs
    path("chats/", get_chats, name="get_chats"),
    path("chats/create/", create_chat, name="create_chat"),
    path("chats/<str:chat_id>/", delete_chat, name="delete_chat"),
    path("chats/<str:chat_id>/messages/", get_chat_messages, name="get_chat_messages"),
    path("chats/<str:chat_id>/send/", send_chat_message, name="send_chat_message"),
    path("chats/<str:chat_id>/mark-read/", mark_messages_as_read, name="mark_messages_as_read"),
    path("chats/<str:chat_id>/messages/<str:message_id>/delete/", delete_message_for_user, name="delete_message_for_user"),
    path("chats/<str:chat_id>/request-deletion/", request_chat_deletion, name="request_chat_deletion"),
    path("chats/<str:chat_id>/respond-deletion/", respond_to_chat_deletion, name="respond_to_chat_deletion"),
    path("chats/<str:chat_id>/mark-notification-seen/", mark_gestation_notification_seen, name="mark_gestation_notification_seen"),
    path('users/status/', get_users_status, name='get_users_status'),
    path('users/status/update/', update_my_status, name='update_my_status'),
    
    # Notifications
    path("notifications/send/", send_push_notification, name="send_push_notification"),
    path("notifications/calls/pending/", get_pending_calls, name="get_pending_calls"),
    path("notifications/calls/mark-seen/", mark_call_seen, name="mark_call_seen"),
    
    # WebRTC
    path("webrtc/ice-servers/", get_ice_servers, name="get_ice_servers"),
    path("webrtc/calls/create/", create_call, name="create_call"),
    path("webrtc/calls/group/", create_group_call, name="create_group_call"),
    path("webrtc/calls/end/", end_call, name="end_call"),
    path("webrtc/calls/update-status/", update_call_status, name="update_call_status"),
    path("webrtc/calls/timer/<str:session_id>/", get_call_timer, name="get_call_timer"),
    path("webrtc/calls/", get_calls, name="get_calls"),
    
    # Call cleanup endpoints
    path("webrtc/calls/cleanup-user-calls/", cleanup_user_calls, name="cleanup_user_calls"),
    path("webrtc/calls/cleanup-all-calls/", cleanup_all_calls, name="cleanup_all_calls"),
    path("webrtc/calls/cleanup-expired-calls/", cleanup_expired_calls, name="cleanup_expired_calls"),
    
    # Endpoint crittografia E2E per chiamate
    path("webrtc/calls/<str:session_id>/encryption/", call_encryption_stats, name="call_encryption_stats"),
    path("webrtc/calls/<str:session_id>/security/", call_security_info, name="call_security_info"),
    path("webrtc/calls/rotate-keys/", rotate_call_keys, name="rotate_call_keys"),
    path("webrtc/calls/verify-encryption/", verify_call_encryption, name="verify_call_encryption"),
    
    # Debug endpoints
    path("debug/call-creation/", debug_call_creation, name="debug_call_creation"),
    path("debug/active-calls/", debug_active_calls, name="debug_active_calls"),
    path("debug/force-polling-restart/", force_app_polling_restart, name="force_polling_restart"),
    path("test/pending-calls/<int:user_id>/", test_pending_calls_for_user, name="test_pending_calls"),
    path("test/create-call/", test_create_call_direct, name="test_create_call"),
    
    # Emergency endpoints
    path("emergency/stop-polling/", emergency_stop_polling, name="emergency_stop_polling"),
    path("emergency/status/", emergency_status, name="emergency_status"),
    
    # Development force logout endpoints
    path("dev/force-logout-all/", force_logout_all_users, name="force_logout_all"),
    path("dev/check-sessions/", check_active_sessions, name="check_active_sessions"),
    
    # Admin
    path("admin/remote-wipe/", remote_wipe, name="remote_wipe"),
    
    # Dashboard Statistics (Admin Dashboard)
    path("dashboard-stats/", dashboard_statistics, name="dashboard_statistics"),
    
    # Chat Monitoring (Admin Dashboard)
    path("monitoring/chat/statistics/", chat_statistics, name="chat_statistics"),
    path("monitoring/chat/users/", users_list, name="users_list"),
    path("monitoring/chat/users/<int:user_id>/chats/", user_chats, name="user_chats"),
    path("monitoring/chat/chats/<str:chat_id>/messages/", chat_messages, name="chat_messages_monitoring"),
    path("monitoring/chat/users/<int:user_id>/reset-password/", reset_user_password, name="reset_user_password"),
    path("monitoring/chat/users/<int:user_id>/block/", block_user, name="block_user"),
    path("monitoring/chat/users/<int:user_id>/unblock/", unblock_user, name="unblock_user"),
    path("monitoring/chat/users/<int:user_id>/delete/", delete_user, name="delete_user"),
    path("monitoring/chat/users/<int:user_id>/toggle-e2e/", toggle_user_e2e, name="toggle_user_e2e"),
    
    # Media services
    path("media/", include("api.media_urls")),
    
    # SecureVOX Call Integration
    path("call/token/", generate_call_token, name="generate_call_token"),
    path("call/webhook/", call_server_webhook, name="call_server_webhook"),
    path("call/stats/", call_stats, name="call_stats"),
    path("call/create/", create_webrtc_call, name="create_webrtc_call"),
    path("call/end/", end_webrtc_call, name="end_webrtc_call"),
]
