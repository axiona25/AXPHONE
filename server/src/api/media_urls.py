"""
URL per i servizi multimediali
"""
from django.urls import path
from . import media_service

urlpatterns = [
    # Upload endpoints
    path('upload/file/', media_service.upload_file, name='upload_file'),
    path('upload/image/', media_service.upload_image, name='upload_image'),
    path('upload/video/', media_service.upload_video, name='upload_video'),
    path('upload/audio/', media_service.upload_audio, name='upload_audio'),
    
    # Save endpoints (for non-file content)
    path('save/location/', media_service.save_location, name='save_location'),
    path('save/contact/', media_service.save_contact, name='save_contact'),
    
    # Download endpoints
    path('download/<str:file_path>', media_service.download_file, name='download_file'),
    path('video/<str:file_path>', media_service.download_video_with_range, name='download_video_with_range'),
    path('thumbnail/<str:file_path>', media_service.get_thumbnail, name='get_thumbnail'),
]
