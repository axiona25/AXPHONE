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
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'pdf': 'application/pdf',
    'zip': 'application/zip',
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
        
        # Verifica dimensione file
        if file.size > MAX_FILE_SIZE:
            return JsonResponse({'error': 'File troppo grande (max 50MB)'}, status=400)
        
        # Verifica tipo file
        file_extension = os.path.splitext(file.name)[1][1:].lower()
        if file_extension not in SUPPORTED_FILE_TYPES:
            return JsonResponse({'error': f'Tipo file non supportato: {file_extension}'}, status=400)
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{file.name}"
        file_path = default_storage.save(f"uploads/{unique_filename}", ContentFile(file.read()))
        
        # NUOVO: Conversione Office → PDF per preview
        preview_pdf_path = None
        if file_extension in ['docx', 'xlsx', 'pptx']:
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
                logger.error(f"❌ Errore conversione Office → PDF: {e}")
        
        # Determina tipo di messaggio
        message_type = _get_message_type_from_file(file_extension)
        
        # Salva metadati (include PDF preview se disponibile)
        metadata = {
            'fileName': file.name,
            'fileType': file_extension,
            'fileUrl': f"/api/media/download/{file_path}",
            'fileSize': file.size,
            'mimeType': SUPPORTED_FILE_TYPES[file_extension]
        }
        
        # NUOVO: Aggiungi URL PDF preview per documenti Office
        if preview_pdf_path:
            metadata['pdfPreviewUrl'] = f"/api/media/download/{preview_pdf_path}"
            logger.info(f"📄 PDF preview URL: {metadata['pdfPreviewUrl']}")
        else:
            metadata['pdfPreviewUrl'] = None
        
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
        logger.error(f"Errore upload file: {str(e)}")
        return JsonResponse({'error': 'Errore interno del server'}, status=500)

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
        
        # Verifica tipo immagine
        if not image.content_type.startswith('image/'):
            return JsonResponse({'error': 'File non è un\'immagine'}, status=400)
        
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
            'fileName': image.name,
            'fileSize': image.size,
            'mimeType': image.content_type
        }
        
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
        
        # Verifica tipo video
        if not video.content_type.startswith('video/'):
            return JsonResponse({'error': 'File non è un video'}, status=400)
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{video.name}"
        file_path = default_storage.save(f"videos/{unique_filename}", ContentFile(video.read()))
        
        # CORREZIONE: Costruisci URL completo e accessibile per video
        base_url = request.build_absolute_uri('/')
        # Rimuovi il trailing slash se presente per evitare doppie slash
        if base_url.endswith('/'):
            base_url = base_url[:-1]
        # CORREZIONE: Rimuovi prefisso videos/ per evitare doppio prefisso
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
            'fileName': video.name,
            'fileSize': video.size,
            'mimeType': video.content_type
        }
        
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
        
        # Verifica tipo audio
        if not audio.content_type.startswith('audio/'):
            return JsonResponse({'error': 'File non è un audio'}, status=400)
        
        # Genera nome file univoco
        unique_filename = f"{uuid.uuid4()}_{audio.name}"
        file_path = default_storage.save(f"audio/{unique_filename}", ContentFile(audio.read()))
        
        metadata = {
            'audioUrl': f"/api/media/download/{file_path}",
            'duration': duration,
            'fileName': audio.name,
            'fileSize': audio.size,
            'mimeType': audio.content_type
        }
        
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
    """
    import re
    import os
    from django.http import HttpResponse
    from django.core.files.storage import default_storage
    
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
            return HttpResponse("Video non trovato", status=404)
        
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
    """
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
