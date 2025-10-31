"""
Servizio per gestire tutti i tipi di contenuti multimediali
"""
import os
import uuid
import mimetypes
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.conf import settings
import json
import logging
from .office_converter import office_converter

logger = logging.getLogger(__name__)

# Configurazione supportati
SUPPORTED_FILE_TYPES = {
    # Formati Office moderni
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    # 🆕 Formati Office vecchi
    'doc': 'application/msword',
    'xls': 'application/vnd.ms-excel',
    'ppt': 'application/vnd.ms-powerpoint',
    # Altri formati
    'pdf': 'application/pdf',
    'zip': 'application/zip',
    'txt': 'text/plain',  # 🆕 File di testo
    # Formati immagine supportati
    'png': 'image/png',
    'jpeg': 'image/jpeg',
    'jpg': 'image/jpeg',
    'tiff': 'image/tiff',
    'tif': 'image/tiff',
    # Formati video supportati
    'mp4': 'video/mp4',
    'mpeg': 'video/mpeg',
    'mpg': 'video/mpeg',
    'mkv': 'video/x-matroska',
    # Formati audio supportati
    'mp3': 'audio/mpeg',
}

MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB

@csrf_exempt
@require_http_methods(["POST"])
def upload_file(request):
    """
    Endpoint per upload di file
    Supporta: docx, xlsx, pptx, pdf, zip, png, jpeg, jpg, mp3, mp4
    """
    try:
        if 'file' not in request.FILES:
            return JsonResponse({'error': 'Nessun file fornito'}, status=400)
        
        file = request.FILES['file']
        user_id = request.POST.get('user_id')
        chat_id = request.POST.get('chat_id')
        
        if not user_id or not chat_id:
            return JsonResponse({'error': 'user_id e chat_id richiesti'}, status=400)
        
        # 🔐 MODIFICA E2E: Rileva se il file è cifrato
        is_encrypted = file.content_type == 'application/octet-stream' or file.name.endswith('_encrypted.bin')
        
        if is_encrypted:
            logger.info("🔐 File cifrato rilevato (application/octet-stream)")
        
        # Verifica dimensione file
        if file.size > MAX_FILE_SIZE:
            return JsonResponse({'error': 'File troppo grande (max 50MB)'}, status=400)
        
        # 🔐 CORREZIONE FINALE: Usa original_file_name dal form se disponibile (inviato dal mobile per file cifrati)
        # Altrimenti usa il nome del file stesso
        original_file_name_from_request = request.POST.get('original_file_name')
        
        if is_encrypted and original_file_name_from_request:
            # File cifrato: usa il nome originale passato dal mobile
            original_file_name = original_file_name_from_request
            logger.info(f"🔐 File cifrato: uso original_file_name dal request: {original_file_name}")
        else:
            # File normale: usa il nome del file
            original_file_name = file.name
            logger.info(f"📄 File normale: uso file.name: {original_file_name}")
        
        file_extension = os.path.splitext(original_file_name)[1][1:].lower()
        
        logger.info(f"📄 File originale: {original_file_name}, estensione: {file_extension}")
        
        # 🔐 MODIFICA E2E: Salta verifica tipo file se cifrato
        if not is_encrypted:
            # Verifica tipo file solo per file non cifrati
            if file_extension not in SUPPORTED_FILE_TYPES:
                return JsonResponse({'error': f'Tipo file non supportato: {file_extension}'}, status=400)
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{file.name}"
        file_path = default_storage.save(f"uploads/{unique_filename}", ContentFile(file.read()))
        
        # NUOVO: Conversione Office → PDF per preview
        # 🔐 MODIFICA E2E: Salta conversione per file cifrati
        preview_pdf_path = None
        office_extensions = ['docx', 'xlsx', 'pptx', 'doc', 'xls', 'ppt']  # 🆕 Aggiunti formati vecchi
        
        logger.info(f"🔍 Controllo conversione Office: is_encrypted={is_encrypted}, file_extension={file_extension}")
        
        if not is_encrypted and file_extension in office_extensions:
            try:
                logger.info(f"🔄 Conversione Office → PDF per preview: {file.name}")
                
                # Ottieni il percorso completo del file caricato
                full_file_path = default_storage.path(file_path)
                
                # Converti in PDF per preview
                logger.info(f"🏢 OFFICE - Tentativo conversione: {full_file_path}")
                logger.info(f"🏢 OFFICE - File esiste: {os.path.exists(full_file_path)}")
                
                pdf_preview_path = office_converter.convert_to_pdf_preview(
                    input_file_path=full_file_path,
                    output_filename=f"{os.path.splitext(file.name)[0]}_preview"
                )
                
                logger.info(f"🏢 OFFICE - Risultato conversione: {pdf_preview_path}")
                if pdf_preview_path:
                    logger.info(f"🏢 OFFICE - PDF esiste: {os.path.exists(pdf_preview_path)}")
                
                if pdf_preview_path and os.path.exists(pdf_preview_path):
                    # Salva il PDF di preview nel storage
                    with open(pdf_preview_path, 'rb') as pdf_file:
                        pdf_content = pdf_file.read()
                        preview_filename = f"{uuid.uuid4()}_preview_{os.path.splitext(file.name)[0]}.pdf"
                        preview_pdf_path = default_storage.save(f"previews/{preview_filename}", ContentFile(pdf_content))
                        logger.info(f"✅ PDF preview salvato: {preview_pdf_path}")
                else:
                    logger.warning(f"⚠️ Conversione PDF fallita per: {file.name}")
                    # NUOVO: Crea un PDF informativo di fallback
                    try:
                        fallback_pdf_path = office_converter._create_fallback_pdf(
                            f"{os.path.splitext(file.name)[0]}_preview",
                            f"Documento {file_extension.upper()}"
                        )
                        if fallback_pdf_path and os.path.exists(fallback_pdf_path):
                            with open(fallback_pdf_path, 'rb') as pdf_file:
                                pdf_content = pdf_file.read()
                                preview_filename = f"{uuid.uuid4()}_fallback_{os.path.splitext(file.name)[0]}.pdf"
                                preview_pdf_path = default_storage.save(f"previews/{preview_filename}", ContentFile(pdf_content))
                                logger.info(f"✅ PDF fallback salvato: {preview_pdf_path}")
                    except Exception as fallback_error:
                        logger.error(f"❌ Errore creazione PDF fallback: {fallback_error}")
                    
            except Exception as e:
                logger.error(f"❌ Errore conversione Office → PDF: {e}", exc_info=True)
        else:
            if is_encrypted:
                logger.info(f"⚠️ File Office cifrato: conversione PDF saltata (file_extension={file_extension})")
            elif file_extension not in office_extensions:
                logger.info(f"ℹ️ File non-Office: conversione PDF non necessaria (file_extension={file_extension})")
        
        # Determina tipo di messaggio
        message_type = _get_message_type_from_file(file_extension)
        
        # 🔐 CORREZIONE FINALE: Costruisci URL assoluto come per le immagini (che funzionano)
        base_url = request.build_absolute_uri('/')
        # Rimuovi il trailing slash se presente per evitare doppie slash
        if base_url.endswith('/'):
            base_url = base_url[:-1]
        file_url = f"{base_url}/api/media/download/{file_path}"
        
        logger.info(f"📄 BACKEND CORREZIONE - Base URL: {base_url}")
        logger.info(f"📄 BACKEND CORREZIONE - File path: {file_path}")
        logger.info(f"📄 BACKEND CORREZIONE - File URL generato: {file_url}")
        
        # Salva metadati (include PDF preview se disponibile)
        metadata = {
            'fileName': original_file_name,  # 🔐 CORREZIONE: Usa il nome originale anche per file cifrati
            'fileType': file_extension,  # 🔐 CORREZIONE: Usa l'estensione originale (pdf, docx, ecc.)
            'file_extension': file_extension,  # 🔐 AGGIUNTO: Per compatibilità con FileViewerScreen
            'fileUrl': file_url,  # 🔐 CORREZIONE: Usa URL assoluto come le immagini
            'fileSize': file.size,
            'mimeType': SUPPORTED_FILE_TYPES.get(file_extension, 'application/octet-stream')  # 🔐 CORREZIONE: Usa 'get' per file cifrati
        }
        
        # 🔐 CRITICO: Leggi e aggiungi metadati di cifratura se presenti
        if is_encrypted:
            metadata['encrypted'] = True
            iv = request.POST.get('iv')
            mac = request.POST.get('mac')
            original_size = request.POST.get('original_size')
            local_file_name = request.POST.get('local_file_name')
            original_file_extension = request.POST.get('original_file_extension')
            
            if iv:
                metadata['iv'] = iv
                logger.info(f"🔐 File cifrato: IV ricevuto durante upload")
            if mac:
                metadata['mac'] = mac
                logger.info(f"🔐 File cifrato: MAC ricevuto durante upload")
            if original_size:
                try:
                    metadata['original_size'] = int(original_size)
                except ValueError:
                    logger.warning(f"⚠️ original_size non valido: {original_size}")
            if local_file_name:
                metadata['local_file_name'] = local_file_name
            if original_file_extension:
                metadata['original_file_extension'] = original_file_extension
            
            logger.info(f"🔐 File cifrato: metadata completi: iv={'presente' if iv else 'assente'}, mac={'presente' if mac else 'assente'}")
        
        # 🔐 NUOVO: Aggiungi URL PDF preview per documenti Office (con URL assoluto)
        if preview_pdf_path:
            pdf_preview_url = f"{base_url}/api/media/download/{preview_pdf_path}"
            metadata['pdfPreviewUrl'] = pdf_preview_url
            logger.info(f"✅ PDF preview URL: {pdf_preview_url}")
        else:
            metadata['pdfPreviewUrl'] = None
            if file_extension in office_extensions:
                logger.warning(f"⚠️ Nessun PDF preview generato per file Office: {original_file_name}")
        
        # 🔍 Log finale dei metadata
        logger.info(f"📦 Metadata finali per {original_file_name}:")
        logger.info(f"   - fileName: {metadata['fileName']}")
        logger.info(f"   - fileType: {metadata['fileType']}")
        logger.info(f"   - file_extension: {metadata['file_extension']}")
        logger.info(f"   - pdfPreviewUrl: {metadata.get('pdfPreviewUrl', 'None')}")
        logger.info(f"   - encrypted: {metadata.get('encrypted', False)}")
        
        return JsonResponse({
            'success': True,
            'message': 'File caricato con successo',
            'data': {
                'fileId': file_path,
                'messageType': message_type,
                'metadata': metadata
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Errore upload file: {str(e)}", exc_info=True)  # 🆕 Aggiungi stack trace completo
        return JsonResponse({
            'error': 'Errore interno del server',
            'details': str(e)  # 🆕 Includi dettagli errore nella risposta
        }, status=500)

@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def upload_image(request):
    """
    Endpoint per upload di immagini (foto dalla galleria)
    """
    try:
        # Gestisci richieste OPTIONS per CORS
        if request.method == 'OPTIONS':
            response = HttpResponse()
            response['Access-Control-Allow-Origin'] = '*'
            response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
            response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
            return response
            
        logger.info(f"📸 Upload immagine - FILES: {list(request.FILES.keys())}")
        logger.info(f"📸 Upload immagine - POST: {dict(request.POST)}")
        
        if 'image' not in request.FILES:
            logger.error("❌ Nessuna immagine fornita")
            return JsonResponse({'error': 'Nessuna immagine fornita'}, status=400)
        
        image = request.FILES['image']
        user_id = request.POST.get('user_id')
        chat_id = request.POST.get('chat_id')
        caption = request.POST.get('caption', '')
        
        logger.info(f"📸 Immagine: {image.name}, size: {image.size}, type: {image.content_type}")
        logger.info(f"📸 user_id: {user_id}, chat_id: {chat_id}")
        
        if not user_id or not chat_id:
            logger.error(f"❌ Parametri mancanti - user_id: {user_id}, chat_id: {chat_id}")
            return JsonResponse({'error': 'user_id e chat_id richiesti'}, status=400)
        
        # 🔐 MODIFICA E2E: Accetta anche file cifrati (application/octet-stream)
        is_encrypted = image.content_type == 'application/octet-stream'
        
        if not is_encrypted and not image.content_type.startswith('image/'):
            return JsonResponse({'error': 'File non è un\'immagine'}, status=400)
        
        if is_encrypted:
            logger.info("🔐 File cifrato rilevato (application/octet-stream)")
        
        # 🔐 CORREZIONE: Usa original_file_name dal form se disponibile (per file cifrati)
        original_file_name_from_request = request.POST.get('original_file_name')
        
        if is_encrypted and original_file_name_from_request:
            original_file_name = original_file_name_from_request
            logger.info(f"🔐 Immagine cifrata: uso original_file_name dal request: {original_file_name}")
        else:
            original_file_name = image.name
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{image.name}"
        file_path = default_storage.save(f"images/{unique_filename}", ContentFile(image.read()))
        
        # CORREZIONE: Costruisci URL completo e accessibile
        base_url = request.build_absolute_uri('/')
        # Rimuovi il trailing slash se presente per evitare doppie slash
        if base_url.endswith('/'):
            base_url = base_url[:-1]
        image_url = f"{base_url}/api/media/download/{file_path}"
        
        print(f"🖼️ BACKEND CORREZIONE - Base URL: {base_url}")
        print(f"🖼️ BACKEND CORREZIONE - File path: {file_path}")
        print(f"🖼️ BACKEND CORREZIONE - Image URL generato: {image_url}")
        
        metadata = {
            'imageUrl': image_url,
            'caption': caption,
            'fileName': original_file_name,  # 🔐 CORREZIONE: Usa nome originale
            'fileSize': image.size,
            'mimeType': image.content_type
        }
        
        # 🔐 CRITICO: Leggi e aggiungi metadati di cifratura se presenti
        if is_encrypted:
            metadata['encrypted'] = True
            iv = request.POST.get('iv')
            mac = request.POST.get('mac')
            original_size = request.POST.get('original_size')
            local_file_name = request.POST.get('local_file_name')
            original_file_extension = request.POST.get('original_file_extension')
            
            if iv:
                metadata['iv'] = iv
                logger.info(f"🔐 Immagine cifrata: IV ricevuto durante upload")
            if mac:
                metadata['mac'] = mac
                logger.info(f"🔐 Immagine cifrata: MAC ricevuto durante upload")
            if original_size:
                try:
                    metadata['original_size'] = int(original_size)
                except ValueError:
                    logger.warning(f"⚠️ original_size non valido: {original_size}")
            if local_file_name:
                metadata['local_file_name'] = local_file_name
            if original_file_extension:
                metadata['original_file_extension'] = original_file_extension
            
            logger.info(f"🔐 Immagine cifrata: metadata completi: iv={'presente' if iv else 'assente'}, mac={'presente' if mac else 'assente'}")
        
        response = JsonResponse({
            'success': True,
            'message': 'Immagine caricata con successo',
            'data': {
                'imageId': file_path,
                'messageType': 'image',
                'url': image_url,  # URL diretto per compatibilità
                'imageUrl': image_url,  # CORREZIONE: Aggiungi anche imageUrl direttamente
                'metadata': metadata
            }
        })
        
        # Aggiungi headers CORS
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        
        return response
        
    except Exception as e:
        logger.error(f"Errore upload immagine: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def upload_video(request):
    """
    Endpoint per upload di video
    """
    try:
        if 'video' not in request.FILES:
            return JsonResponse({'error': 'Nessun video fornito'}, status=400)
        
        video = request.FILES['video']
        user_id = request.POST.get('user_id')
        chat_id = request.POST.get('chat_id')
        caption = request.POST.get('caption', '')
        
        if not user_id or not chat_id:
            return JsonResponse({'error': 'user_id e chat_id richiesti'}, status=400)
        
        # 🔐 MODIFICA E2E: Accetta anche file cifrati (application/octet-stream)
        is_encrypted = video.content_type == 'application/octet-stream'
        
        if not is_encrypted and not video.content_type.startswith('video/'):
            return JsonResponse({'error': 'File non è un video'}, status=400)
        
        if is_encrypted:
            logger.info("🔐 Video cifrato rilevato (application/octet-stream)")
        
        # 🔐 CORREZIONE: Usa original_file_name dal form se disponibile (per file cifrati)
        original_file_name_from_request = request.POST.get('original_file_name')
        
        if is_encrypted and original_file_name_from_request:
            original_file_name = original_file_name_from_request
            logger.info(f"🔐 Video cifrato: uso original_file_name dal request: {original_file_name}")
        else:
            original_file_name = video.name
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{video.name}"
        file_path = default_storage.save(f"videos/{unique_filename}", ContentFile(video.read()))
        
        # 🔐 CORREZIONE FINALE: Usa URL assoluto + endpoint dedicato video per range request iOS
        base_url = request.build_absolute_uri('/')
        # Rimuovi il trailing slash se presente per evitare doppie slash
        if base_url.endswith('/'):
            base_url = base_url[:-1]
        # 🎥 USA ENDPOINT DEDICATO: /api/media/video/ (gestisce meglio range request iOS)
        # Rimuovi prefisso videos/ perché l'endpoint lo aggiunge automaticamente
        clean_file_path = file_path.replace('videos/', '') if file_path.startswith('videos/') else file_path
        video_url = f"{base_url}/api/media/video/{clean_file_path}"
        thumbnail_url = f"{base_url}/api/media/thumbnail/{file_path}"
        
        print(f"🎥 BACKEND CORREZIONE - Base URL: {base_url}")
        print(f"🎥 BACKEND CORREZIONE - File path: {file_path}")
        print(f"🎥 BACKEND CORREZIONE - Video URL generato: {video_url}")
        print(f"🎥 BACKEND CORREZIONE - Thumbnail URL generato: {thumbnail_url}")
        
        metadata = {
            'videoUrl': video_url,
            'thumbnailUrl': thumbnail_url,
            'caption': caption,
            'fileName': original_file_name,  # 🔐 CORREZIONE: Usa nome originale
            'fileSize': video.size,
            'mimeType': video.content_type
        }
        
        # 🔐 CRITICO: Leggi e aggiungi metadati di cifratura se presenti
        if is_encrypted:
            metadata['encrypted'] = True
            iv = request.POST.get('iv')
            mac = request.POST.get('mac')
            original_size = request.POST.get('original_size')
            local_file_name = request.POST.get('local_file_name')
            original_file_extension = request.POST.get('original_file_extension')
            
            if iv:
                metadata['iv'] = iv
                logger.info(f"🔐 Video cifrato: IV ricevuto durante upload")
            if mac:
                metadata['mac'] = mac
                logger.info(f"🔐 Video cifrato: MAC ricevuto durante upload")
            if original_size:
                try:
                    metadata['original_size'] = int(original_size)
                except ValueError:
                    logger.warning(f"⚠️ original_size non valido: {original_size}")
            if local_file_name:
                metadata['local_file_name'] = local_file_name
            if original_file_extension:
                metadata['original_file_extension'] = original_file_extension
            
            logger.info(f"🔐 Video cifrato: metadata completi: iv={'presente' if iv else 'assente'}, mac={'presente' if mac else 'assente'}")
        
        return JsonResponse({
            'success': True,
            'message': 'Video caricato con successo',
            'data': {
                'videoId': file_path,
                'messageType': 'video',
                'url': video_url,  # URL diretto per compatibilità
                'videoUrl': video_url,  # CORREZIONE: Aggiungi anche videoUrl direttamente
                'thumbnailUrl': thumbnail_url,  # CORREZIONE: Aggiungi anche thumbnailUrl direttamente
                'metadata': metadata
            }
        })
        
    except Exception as e:
        logger.error(f"Errore upload video: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def upload_audio(request):
    """
    Endpoint per upload di messaggi audio
    """
    try:
        if 'audio' not in request.FILES:
            return JsonResponse({'error': 'Nessun audio fornito'}, status=400)
        
        audio = request.FILES['audio']
        user_id = request.POST.get('user_id')
        chat_id = request.POST.get('chat_id')
        duration = request.POST.get('duration', '00:00')
        
        if not user_id or not chat_id:
            return JsonResponse({'error': 'user_id e chat_id richiesti'}, status=400)
        
        # 🔐 MODIFICA E2E: Accetta anche file cifrati (application/octet-stream)
        is_encrypted = audio.content_type == 'application/octet-stream'
        
        # Verifica tipo audio (salta per file cifrati)
        if not is_encrypted and not audio.content_type.startswith('audio/'):
            return JsonResponse({'error': 'File non è un audio'}, status=400)
        
        if is_encrypted:
            logger.info("🔐 Audio cifrato rilevato (application/octet-stream)")
        
        # 🔐 CORREZIONE: Usa original_file_name dal form se disponibile (per file cifrati)
        original_file_name_from_request = request.POST.get('original_file_name')
        
        if is_encrypted and original_file_name_from_request:
            original_file_name = original_file_name_from_request
            logger.info(f"🔐 Audio cifrato: uso original_file_name dal request: {original_file_name}")
        else:
            original_file_name = audio.name
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{audio.name}"
        file_path = default_storage.save(f"audio/{unique_filename}", ContentFile(audio.read()))
        
        # 🔐 CORREZIONE FINALE: Costruisci URL assoluto come per le immagini (che funzionano)
        base_url = request.build_absolute_uri('/')
        # Rimuovi il trailing slash se presente per evitare doppie slash
        if base_url.endswith('/'):
            base_url = base_url[:-1]
        audio_url = f"{base_url}/api/media/download/{file_path}"
        
        logger.info(f"🎵 BACKEND CORREZIONE - Base URL: {base_url}")
        logger.info(f"🎵 BACKEND CORREZIONE - File path: {file_path}")
        logger.info(f"🎵 BACKEND CORREZIONE - Audio URL generato: {audio_url}")
        
        metadata = {
            'audioUrl': audio_url,  # 🔐 CORREZIONE: Usa URL assoluto come le immagini
            'duration': duration,
            'fileName': original_file_name,  # 🔐 CORREZIONE: Usa nome originale
            'fileSize': audio.size,
            'mimeType': audio.content_type
        }
        
        # 🔐 CRITICO: Leggi e aggiungi metadati di cifratura se presenti
        if is_encrypted:
            metadata['encrypted'] = True
            iv = request.POST.get('iv')
            mac = request.POST.get('mac')
            original_size = request.POST.get('original_size')
            local_file_name = request.POST.get('local_file_name')
            original_file_extension = request.POST.get('original_file_extension')
            
            if iv:
                metadata['iv'] = iv
                logger.info(f"🔐 Audio cifrato: IV ricevuto durante upload")
            if mac:
                metadata['mac'] = mac
                logger.info(f"🔐 Audio cifrato: MAC ricevuto durante upload")
            if original_size:
                try:
                    metadata['original_size'] = int(original_size)
                except ValueError:
                    logger.warning(f"⚠️ original_size non valido: {original_size}")
            if local_file_name:
                metadata['local_file_name'] = local_file_name
            if original_file_extension:
                metadata['original_file_extension'] = original_file_extension
            
            logger.info(f"🔐 Audio cifrato: metadata completi: iv={'presente' if iv else 'assente'}, mac={'presente' if mac else 'assente'}")
        
        return JsonResponse({
            'success': True,
            'message': 'Audio caricato con successo',
            'data': {
                'audioId': file_path,
                'messageType': 'voice',
                'metadata': metadata
            }
        })
        
    except Exception as e:
        logger.error(f"Errore upload audio: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def save_location(request):
    """
    Endpoint per salvare posizione geografica
    """
    try:
        data = json.loads(request.body)
        
        user_id = data.get('user_id')
        chat_id = data.get('chat_id')
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        address = data.get('address', '')
        city = data.get('city', '')
        country = data.get('country', '')
        
        if not all([user_id, chat_id, latitude, longitude]):
            return JsonResponse({'error': 'Parametri richiesti mancanti'}, status=400)
        
        metadata = {
            'latitude': float(latitude),
            'longitude': float(longitude),
            'address': address,
            'city': city,
            'country': country
        }
        
        return JsonResponse({
            'success': True,
            'message': 'Posizione salvata con successo',
            'data': {
                'locationId': f"{uuid.uuid4()}",
                'messageType': 'location',
                'metadata': metadata
            }
        })
        
    except Exception as e:
        logger.error(f"Errore salvataggio posizione: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def save_contact(request):
    """
    Endpoint per salvare contatto
    """
    try:
        data = json.loads(request.body)
        
        user_id = data.get('user_id')
        chat_id = data.get('chat_id')
        name = data.get('name')
        phone = data.get('phone')
        email = data.get('email', '')
        organization = data.get('organization', '')
        
        if not all([user_id, chat_id, name, phone]):
            return JsonResponse({'error': 'Nome e telefono richiesti'}, status=400)
        
        metadata = {
            'name': name,
            'phone': phone,
            'email': email,
            'organization': organization
        }
        
        return JsonResponse({
            'success': True,
            'message': 'Contatto salvato con successo',
            'data': {
                'contactId': f"{uuid.uuid4()}",
                'messageType': 'contact',
                'metadata': metadata
            }
        })
        
    except Exception as e:
        logger.error(f"Errore salvataggio contatto: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

def _handle_range_request(request, file, content_type, file_path):
    """
    Gestisce HTTP Range Requests per video e audio (richiesto da iOS)
    """
    import re
    
    # Ottieni la dimensione del file
    file.seek(0, 2)  # Vai alla fine
    file_size = file.tell()
    file.seek(0)  # Torna all'inizio
    
    # Controlla se c'è un header Range
    range_header = request.META.get('HTTP_RANGE')
    
    if range_header:
        # Parse del range header (es: "bytes=0-1023")
        range_match = re.match(r'bytes=(\d+)-(\d*)', range_header)
        if range_match:
            start = int(range_match.group(1))
            end = int(range_match.group(2)) if range_match.group(2) else file_size - 1
            
            # Assicurati che end non superi la dimensione del file
            end = min(end, file_size - 1)
            content_length = end - start + 1
            
            # Leggi solo il range richiesto
            file.seek(start)
            data = file.read(content_length)
            
            # Crea risposta con status 206 (Partial Content)
            response = HttpResponse(data, content_type=content_type, status=206)
            response['Content-Range'] = f'bytes {start}-{end}/{file_size}'
            response['Content-Length'] = str(content_length)
            response['Accept-Ranges'] = 'bytes'
            
            print(f'🎥 RANGE REQUEST - File: {file_path}')
            print(f'🎥 RANGE REQUEST - Range: {start}-{end}/{file_size} ({content_length} bytes)')
            
        else:
            # Range header malformato, restituisci tutto il file
            data = file.read()
            response = HttpResponse(data, content_type=content_type)
            response['Content-Length'] = str(file_size)
            response['Accept-Ranges'] = 'bytes'
    else:
        # Nessun range header, restituisci tutto il file
        data = file.read()
        response = HttpResponse(data, content_type=content_type)
        response['Content-Length'] = str(file_size)
        response['Accept-Ranges'] = 'bytes'
    
    # Headers CORS
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Range'
    response['Access-Control-Expose-Headers'] = 'Content-Range, Accept-Ranges, Content-Length'
    
    # Per video, usa inline invece di attachment
    response['Content-Disposition'] = f'inline; filename="{os.path.basename(file_path)}"'
    
    return response

@require_http_methods(["GET", "OPTIONS"])
def download_video_with_range(request, file_path):
    """
    NUOVO ENDPOINT DEDICATO per video con supporto Range Requests iOS
    🔐 SICUREZZA E2E: Gli admin NON possono vedere contenuti cifrati end-to-end
    """
    import re
    import os
    from django.http import HttpResponse
    from django.core.files.storage import default_storage
    from .models import ChatMessage
    
    print(f'🎬 NUOVO ENDPOINT VIDEO - File: {file_path}')
    print(f'🎬 Range Header: {request.META.get("HTTP_RANGE", "NONE")}')
    
    try:
        # Gestisci CORS
        if request.method == 'OPTIONS':
            response = HttpResponse()
            response['Access-Control-Allow-Origin'] = '*'
            response['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
            response['Access-Control-Allow-Headers'] = 'Range, Content-Type, Authorization'
            response['Access-Control-Expose-Headers'] = 'Content-Range, Accept-Ranges, Content-Length'
            return response
        
        # Aggiungi prefisso se necessario
        if not file_path.startswith('videos/'):
            file_path = f"videos/{file_path}"
        
        if not default_storage.exists(file_path):
            print(f'🎬 ERRORE: File non trovato: {file_path}')
            return HttpResponse("Video non trovato", status=404)
        
        # 🔐 SICUREZZA E2E: Verifica se il video è cifrato E2E e blocca admin
        # IMPORTANTE: Questo controllo non deve bloccare gli utenti normali
        try:
            # Cerca il messaggio associato a questo file solo se l'utente è autenticato
            if request.user.is_authenticated and (request.user.is_staff or request.user.is_superuser):
                file_name = os.path.basename(file_path)
                print(f'🔐 Verifica E2E per admin: file_name={file_name}')
                # Cerca nei messaggi video che contengono questo file
                video_messages = ChatMessage.objects.filter(
                    message_type='video',
                    metadata__videoUrl__icontains=file_name
                ) | ChatMessage.objects.filter(
                    message_type='video',
                    metadata__url__icontains=file_name
                )
                
                # Verifica se almeno un messaggio con questo video è cifrato E2E
                is_e2e_encrypted = False
                for msg in video_messages[:5]:  # Limita a 5 messaggi per performance
                    metadata = msg.metadata or {}
                    # Verifica se ci sono metadata di cifratura E2E
                    if (metadata.get('encrypted') is True or 
                        metadata.get('iv') is not None or 
                        metadata.get('mac') is not None):
                        is_e2e_encrypted = True
                        print(f'🔐 Video cifrato E2E rilevato per file: {file_name}')
                        break
                
                # Se è cifrato E2E e l'utente è admin/staff, blocca l'accesso
                if is_e2e_encrypted:
                    print(f'🚫 ACCESSO BLOCCATO: Admin non può vedere contenuti cifrati E2E')
                    return HttpResponse(
                        "Accesso negato: I contenuti cifrati end-to-end non sono accessibili agli amministratori per preservare la sicurezza della cifratura.",
                        status=403
                    )
        except Exception as e:
            # Se c'è un errore nel controllo, logga ma NON bloccare il download
            # (gli utenti normali devono sempre poter accedere)
            print(f'⚠️ Errore controllo E2E per admin (ignorato): {e}')
            # Procedi con il download normale
        
        file = default_storage.open(file_path)
        
        # Ottieni dimensione file
        file.seek(0, 2)
        file_size = file.tell()
        file.seek(0)
        
        print(f'🎬 File size: {file_size} bytes')
        
        # Controlla header Range
        range_header = request.META.get('HTTP_RANGE')
        
        if range_header:
            print(f'🎬 Processing range: {range_header}')
            
            # Parse range (es: "bytes=0-1")
            range_match = re.match(r'bytes=(\d+)-(\d*)', range_header)
            if range_match:
                start = int(range_match.group(1))
                end = int(range_match.group(2)) if range_match.group(2) else file_size - 1
                end = min(end, file_size - 1)
                content_length = end - start + 1
                
                # Leggi range
                file.seek(start)
                data = file.read(content_length)
                
                print(f'🎬 Range: {start}-{end}/{file_size} ({content_length} bytes)')
                
                # Response 206
                response = HttpResponse(data, content_type='video/mp4', status=206)
                response['Content-Range'] = f'bytes {start}-{end}/{file_size}'
                response['Content-Length'] = str(content_length)
                response['Accept-Ranges'] = 'bytes'
                
            else:
                print('🎬 Range malformato, restituisco tutto')
                data = file.read()
                response = HttpResponse(data, content_type='video/mp4')
                response['Content-Length'] = str(file_size)
                response['Accept-Ranges'] = 'bytes'
        else:
            print('🎬 Nessun range, restituisco tutto')
            data = file.read()
            response = HttpResponse(data, content_type='video/mp4')
            response['Content-Length'] = str(file_size)
            response['Accept-Ranges'] = 'bytes'
        
        # Headers CORS
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Range, Content-Type, Authorization'
        response['Access-Control-Expose-Headers'] = 'Content-Range, Accept-Ranges, Content-Length'
        response['Content-Disposition'] = f'inline; filename="{os.path.basename(file_path)}"'
        
        file.close()
        print(f'🎬 Response: {response.status_code} - {len(data)} bytes')
        return response
        
    except Exception as e:
        print(f'🎬 ERRORE: {e}')
        return HttpResponse(f"Errore video: {e}", status=500)

@require_http_methods(["GET", "OPTIONS"])
def download_file(request, file_path):
    """
    Endpoint per download di file
    🔐 SICUREZZA E2E: Gli admin NON possono vedere contenuti cifrati end-to-end
    """
    from .models import ChatMessage
    
    print(f'🚨🚨🚨 DOWNLOAD_FILE CHIAMATO - File: {file_path} - Range: {request.META.get("HTTP_RANGE", "NONE")} 🚨🚨🚨')
    try:
        # Gestisci richieste OPTIONS per CORS
        if request.method == 'OPTIONS':
            response = HttpResponse()
            response['Access-Control-Allow-Origin'] = '*'
            response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
            response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
            return response
            
        # Il file_path dovrebbe già includere il prefisso 'images/' dal salvataggio
        # Non aggiungere il prefisso se è già presente
        if not file_path.startswith('images/') and not file_path.startswith('videos/') and not file_path.startswith('audio/'):
            file_path = f"images/{file_path}"
            
        if default_storage.exists(file_path):
            # 🔐 SICUREZZA E2E: Verifica se il file è cifrato E2E e blocca admin
            # IMPORTANTE: Questo controllo non deve bloccare gli utenti normali
            try:
                # Cerca il messaggio associato a questo file solo se l'utente è admin
                if request.user.is_authenticated and (request.user.is_staff or request.user.is_superuser):
                    file_name = os.path.basename(file_path)
                    # Determina il tipo di messaggio in base al percorso
                    message_type = None
                    if 'images/' in file_path:
                        message_type = 'image'
                        metadata_key = 'imageUrl'
                    elif 'videos/' in file_path:
                        message_type = 'video'
                        metadata_key = 'videoUrl'
                    elif 'audio/' in file_path:
                        message_type = 'audio'
                        metadata_key = 'audioUrl'
                    else:
                        message_type = 'file'
                        metadata_key = 'fileUrl'
                    
                    # Cerca il messaggio associato a questo file
                    file_messages = ChatMessage.objects.filter(
                        message_type=message_type
                    ).filter(
                        **{f'metadata__{metadata_key}__icontains': file_name}
                    )
                    
                    # Verifica se almeno un messaggio con questo file è cifrato E2E
                    is_e2e_encrypted = False
                    for msg in file_messages[:5]:  # Limita a 5 messaggi per performance
                        metadata = msg.metadata or {}
                        # Verifica se ci sono metadata di cifratura E2E
                        if (metadata.get('encrypted') is True or 
                            metadata.get('iv') is not None or 
                            metadata.get('mac') is not None):
                            is_e2e_encrypted = True
                            print(f'🔐 File cifrato E2E rilevato per file: {file_name}')
                            break
                    
                    # Se è cifrato E2E e l'utente è admin/staff, blocca l'accesso
                    if is_e2e_encrypted:
                        print(f'🚫 ACCESSO BLOCCATO: Admin non può vedere contenuti cifrati E2E')
                        return HttpResponse(
                            "Accesso negato: I contenuti cifrati end-to-end non sono accessibili agli amministratori per preservare la sicurezza della cifratura.",
                            status=403
                        )
            except Exception as e:
                # Se c'è un errore nel controllo, logga ma NON bloccare il download
                # (gli utenti normali devono sempre poter accedere)
                print(f'⚠️ Errore controllo E2E per admin (ignorato): {e}')
                # Procedi con il download normale
            file = default_storage.open(file_path)
            
            # Determina il content type basato sull'estensione
            file_extension = os.path.splitext(file_path)[1].lower()
            content_type = 'application/octet-stream'
            
            print(f'🎥 DEBUG DOWNLOAD - File: {file_path}')
            print(f'🎥 DEBUG DOWNLOAD - Extension: {file_extension}')
            print(f'🔥 FORCE RELOAD - Timestamp: {__import__("time").time()}')
            
            if file_extension in ['.jpg', '.jpeg']:
                content_type = 'image/jpeg'
            elif file_extension == '.png':
                content_type = 'image/png'
            elif file_extension == '.gif':
                content_type = 'image/gif'
            elif file_extension == '.webp':
                content_type = 'image/webp'
            elif file_extension in ['.mp4', '.mov']:
                content_type = 'video/mp4'
            elif file_extension in ['.mp3', '.wav']:
                content_type = 'audio/mpeg'
            
            # CORREZIONE: Supporto HTTP Range Requests per video iOS
            if content_type.startswith('video/') or content_type.startswith('audio/'):
                print(f'🎥 DEBUG - Chiamando _handle_range_request per {file_path}')
                print(f'🎥 DEBUG - Content type: {content_type}')
                return _handle_range_request(request, file, content_type, file_path)
            
            # Per immagini e altri file, usa il metodo normale
            response = HttpResponse(file.read(), content_type=content_type)
            
            # Aggiungi headers CORS per permettere il caricamento delle immagini
            response['Access-Control-Allow-Origin'] = '*'
            response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
            response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, Range'
            
            # Per le immagini, non forzare il download
            if content_type.startswith('image/'):
                response['Content-Disposition'] = f'inline; filename="{os.path.basename(file_path)}"'
            else:
                response['Content-Disposition'] = f'attachment; filename="{os.path.basename(file_path)}"'
                
            return response
        else:
            return JsonResponse({'error': 'File non trovato'}, status=404)
            
    except Exception as e:
        logger.error(f"Errore download file: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

@require_http_methods(["GET"])
def get_thumbnail(request, file_path):
    """
    Endpoint per ottenere thumbnail di video
    """
    try:
        # Qui implementeresti la logica per generare/recuperare thumbnail
        # Per ora restituiamo un placeholder
        return JsonResponse({
            'thumbnailUrl': f"/api/media/download/{file_path}",
            'message': 'Thumbnail generato'
        })
        
    except Exception as e:
        logger.error(f"Errore generazione thumbnail: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def convert_office_to_pdf(request):
    """
    🆕 Endpoint per convertire file Office decifrati in PDF on-the-fly
    Riceve un file Office, lo converte in PDF, lo restituisce senza salvarlo
    """
    logger.info("╔═══════════════════════════════════════════════════════════╗")
    logger.info("║ 🔄 convert_office_to_pdf - Conversione temporanea        ║")
    logger.info("╚═══════════════════════════════════════════════════════════╝")
    
    try:
        # Verifica che sia stato inviato un file
        if 'file' not in request.FILES:
            return JsonResponse({'error': 'Nessun file fornito'}, status=400)
        
        file = request.FILES['file']
        original_filename = file.name
        
        logger.info(f"📄 File ricevuto: {original_filename}")
        logger.info(f"📄 Dimensione: {file.size} bytes")
        
        # Verifica estensione
        file_extension = os.path.splitext(original_filename)[1][1:].lower()
        office_extensions = ['docx', 'xlsx', 'pptx', 'doc', 'xls', 'ppt']
        
        if file_extension not in office_extensions:
            return JsonResponse({
                'error': f'Tipo file non supportato: {file_extension}. Supportati: {", ".join(office_extensions)}'
            }, status=400)
        
        logger.info(f"✅ Estensione valida: {file_extension}")
        
        # Salva temporaneamente il file Office
        temp_dir = os.path.join(settings.MEDIA_ROOT, 'temp_conversions')
        os.makedirs(temp_dir, exist_ok=True)
        
        temp_office_path = os.path.join(temp_dir, f"{uuid.uuid4()}_{original_filename}")
        
        with open(temp_office_path, 'wb+') as temp_file:
            for chunk in file.chunks():
                temp_file.write(chunk)
        
        logger.info(f"💾 File salvato temporaneamente: {temp_office_path}")
        
        # Converti in PDF
        logger.info(f"🔄 Avvio conversione Office → PDF...")
        pdf_path = office_converter.convert_to_pdf(temp_office_path)
        
        if not pdf_path or not os.path.exists(pdf_path):
            # Rimuovi file temporaneo
            if os.path.exists(temp_office_path):
                os.remove(temp_office_path)
            
            return JsonResponse({
                'error': 'Conversione PDF fallita',
                'details': 'LibreOffice non è riuscito a convertire il file'
            }, status=500)
        
        logger.info(f"✅ PDF generato: {pdf_path}")
        
        # Leggi il PDF e restituiscilo
        with open(pdf_path, 'rb') as pdf_file:
            pdf_content = pdf_file.read()
        
        logger.info(f"✅ PDF letto: {len(pdf_content)} bytes")
        
        # Rimuovi file temporanei
        try:
            if os.path.exists(temp_office_path):
                os.remove(temp_office_path)
                logger.info(f"🗑️ File Office temporaneo eliminato")
            
            if os.path.exists(pdf_path):
                os.remove(pdf_path)
                logger.info(f"🗑️ PDF temporaneo eliminato")
        except Exception as e:
            logger.warning(f"⚠️ Errore pulizia file temporanei: {e}")
        
        # Restituisci il PDF
        response = HttpResponse(pdf_content, content_type='application/pdf')
        response['Content-Disposition'] = f'inline; filename="{os.path.splitext(original_filename)[0]}.pdf"'
        response['Access-Control-Allow-Origin'] = '*'
        
        logger.info("✅ PDF restituito con successo")
        logger.info("═══════════════════════════════════════════════════════════")
        
        return response
        
    except Exception as e:
        logger.error(f"❌ Errore conversione Office → PDF: {str(e)}")
        import traceback
        logger.error(f"❌ Stack trace: {traceback.format_exc()}")
        logger.info("═══════════════════════════════════════════════════════════")
        
        return JsonResponse({
            'error': 'Errore interno del server',
            'details': str(e)
        }, status=500)


def _get_message_type_from_file(file_extension):
    """
    Determina il tipo di messaggio basato sull'estensione del file
    """
    if file_extension in ['png', 'jpeg', 'jpg']:
        return 'image'
    elif file_extension in ['mp4', 'avi', 'mov']:
        return 'video'
    elif file_extension in ['mp3', 'wav', 'm4a']:
        return 'voice'
    else:
        return 'attachment'
