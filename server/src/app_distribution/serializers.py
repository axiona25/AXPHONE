from rest_framework import serializers
from django.contrib.auth.models import User
from .models import AppBuild, AppDownload, AppFeedback


class AppBuildSerializer(serializers.ModelSerializer):
    """Serializer per AppBuild"""
    
    uploaded_by_name = serializers.CharField(source='uploaded_by.username', read_only=True)
    file_size_mb = serializers.ReadOnlyField()
    install_url = serializers.ReadOnlyField()
    download_count = serializers.ReadOnlyField()
    can_download = serializers.SerializerMethodField()
    
    class Meta:
        model = AppBuild
        fields = [
            'id', 'name', 'platform', 'version', 'build_number', 'bundle_id',
            'app_file', 'icon', 'description', 'release_notes', 'min_os_version',
            'status', 'is_active', 'is_beta', 'uploaded_by', 'uploaded_by_name',
            'created_at', 'updated_at', 'file_size_mb', 'install_url', 
            'download_count', 'can_download'
        ]
        read_only_fields = ['id', 'uploaded_by', 'created_at', 'updated_at', 'download_count']
    
    def get_can_download(self, obj):
        """Verifica se l'utente corrente può scaricare questa build"""
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            return obj.can_download(request.user)
        return False


class AppBuildCreateSerializer(serializers.ModelSerializer):
    """Serializer per la creazione di nuove build"""
    
    class Meta:
        model = AppBuild
        fields = [
            'name', 'platform', 'version', 'build_number', 'bundle_id',
            'app_file', 'icon', 'description', 'release_notes', 'min_os_version',
            'is_beta'
        ]
    
    def validate_app_file(self, value):
        """Valida il file dell'app in base alla piattaforma"""
        platform = self.initial_data.get('platform')
        
        if platform == 'ios':
            if not value.name.lower().endswith('.ipa'):
                raise serializers.ValidationError("Per iOS è richiesto un file .ipa")
        elif platform == 'android':
            if not (value.name.lower().endswith('.apk') or value.name.lower().endswith('.aab')):
                raise serializers.ValidationError("Per Android è richiesto un file .apk o .aab")
        
        # Verifica dimensione file (max 500MB)
        if value.size > 500 * 1024 * 1024:
            raise serializers.ValidationError("Il file non può superare i 500MB")
        
        return value
    
    def validate(self, data):
        """Validazione generale"""
        # Verifica unicità della combinazione platform + bundle_id + version + build_number
        if AppBuild.objects.filter(
            platform=data['platform'],
            bundle_id=data['bundle_id'],
            version=data['version'],
            build_number=data['build_number']
        ).exists():
            raise serializers.ValidationError(
                "Esiste già una build con questa combinazione di piattaforma, bundle ID, versione e build number"
            )
        
        return data


class AppDownloadSerializer(serializers.ModelSerializer):
    """Serializer per AppDownload"""
    
    app_build_name = serializers.CharField(source='app_build.name', read_only=True)
    user_name = serializers.CharField(source='user.username', read_only=True)
    
    class Meta:
        model = AppDownload
        fields = [
            'id', 'app_build', 'app_build_name', 'user', 'user_name',
            'ip_address', 'user_agent', 'device_info', 'downloaded_at'
        ]
        read_only_fields = ['id', 'downloaded_at']


class AppFeedbackSerializer(serializers.ModelSerializer):
    """Serializer per AppFeedback"""
    
    user_name = serializers.CharField(source='user.username', read_only=True)
    app_build_name = serializers.CharField(source='app_build.name', read_only=True)
    
    class Meta:
        model = AppFeedback
        fields = [
            'id', 'app_build', 'app_build_name', 'user', 'user_name',
            'rating', 'comment', 'device_info', 'created_at'
        ]
        read_only_fields = ['id', 'user', 'created_at']


class AppFeedbackCreateSerializer(serializers.ModelSerializer):
    """Serializer per la creazione di feedback"""
    
    class Meta:
        model = AppFeedback
        fields = ['app_build', 'rating', 'comment', 'device_info']
    
    def validate(self, data):
        """Verifica che l'utente non abbia già lasciato feedback per questa build"""
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            if AppFeedback.objects.filter(
                app_build=data['app_build'],
                user=request.user
            ).exists():
                raise serializers.ValidationError(
                    "Hai già lasciato un feedback per questa build"
                )
        return data


class UserSerializer(serializers.ModelSerializer):
    """Serializer semplice per User"""
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
