import logging
import os
import httpx
from typing import Dict, Any, List, Optional, Union
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel, Field
from skills.meta_ads import MetaAdsSkill
from skills.ai_engine import AIEngineSkill

# WhatsApp config
WHATSAPP_VERIFY_TOKEN = os.getenv('META_VERIFY_TOKEN', 'igbot')
N8N_WHATSAPP_WEBHOOK = 'https://n8n.admetricas.com/webhook/whabot'

# Messenger config
N8N_MESSENGER_WEBHOOK = 'https://n8n.admetricas.com/webhook/messenger'

# Configuración de Logging profesional
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("hermes.main")

app = FastAPI(
    title="Hermes Agent - Motor de Campañas de Ads Vzla",
    description="API interna para la creación, activación y monitoreo automatizado de campañas publicitarias en Meta Ads.",
    version="1.0.0"
)

# Inicializar Skills
meta_ads = MetaAdsSkill()
ai_engine = AIEngineSkill()

# ================================================================
# Modelos de Validación Pydantic
# ================================================================
class TargetingModel(BaseModel):
    cities: List[str] = Field(default=[], description="Lista de keys de ciudades de segmentación en Meta")
    countries: List[str] = Field(default=[], description="Lista de códigos ISO de países (ej: ['VE'])")
    age_min: int = Field(default=18, ge=13, le=65, description="Edad mínima de segmentación")
    age_max: int = Field(default=65, ge=13, le=65, description="Edad máxima de segmentación")
    interests: List[str] = Field(default=[], description="Lista de IDs de intereses de segmentación")


# Modelo legacy — aceptado para retro-compatibilidad con flujos n8n viejos
class CreativeModel(BaseModel):
    message: str = Field(..., description="Copy publicitario o texto del anuncio")
    link: str = Field(..., description="Enlace de destino (ej: link de WhatsApp o Instagram)")
    image_url: str = Field(..., description="URL de la imagen o video del anuncio")


class CreateCampaignRequest(BaseModel):
    client_psid: str = Field(..., description="ID del cliente en la plataforma")
    client_name: str = Field(..., description="Nombre del cliente")
    plan: str = Field(..., description="Nombre del plan elegido")
    objective: str = Field(
        default="OUTCOME_TRAFFIC",
        description="OUTCOME_TRAFFIC o OUTCOME_ENGAGEMENT",
    )
    destination: str = Field(
        default="instagram_profile",
        description="instagram_profile, instagram_dm, whatsapp, messenger",
    )
    daily_budget: int = Field(default=100, ge=100, description="Presupuesto diario en centavos USD")
    duration_days: int = Field(default=3, ge=3, le=15, description="Duración de la campaña en días")
    targeting: TargetingModel = Field(..., description="Objeto de segmentación")
    creative_source: str = Field(
        default="new_creative",
        description="existing_post o new_creative",
    )
    # Path A: existing post
    instagram_post_url: Optional[str] = Field(
        default=None,
        description="URL del post de Instagram existente (solo creative_source=existing_post)",
    )
    # Path B: new creative
    image_urls: Optional[List[str]] = Field(
        default=None,
        description="URLs de imágenes (solo creative_source=new_creative)",
    )
    creative_message: Optional[str] = Field(
        default=None,
        description="Copy publicitario manual del cliente (solo creative_source=new_creative)",
    )
    creative_link: Optional[str] = Field(
        default=None,
        description="Link de destino del anuncio",
    )
    # Legacy (retro-compat): si n8n manda el payload viejo, lo aceptamos.
    # Usamos Dict (no CreativeModel) para que sea claramente opcional sin
    # pelearse con Pydantic v2.
    creative: Optional[Dict[str, Any]] = Field(
        default=None,
        description="(DEPRECATED) Objeto creativo plano — usar creative_message/image_urls en su lugar",
    )

    # Per-client asset IDs (overriden los defaults de .env cuando la campaña
    # es para un cliente específico con su propia página / cuenta IG).
    page_id: str = Field(..., description="Facebook Page ID del cliente")
    instagram_actor_id: Optional[str] = Field(
        default=None,
        description="Instagram Business Account ID del cliente",
    )


class TranscribeAudioRequest(BaseModel):
    audio_url: str = Field(..., description="URL de la nota de voz a transcribir")
    auth_header: Optional[str] = Field(default=None, description="Header de autorización para descargar el audio (ej: 'Bearer TOKEN')")


class ValidateReceiptRequest(BaseModel):
    image_url: str = Field(..., description="URL de la imagen del comprobante de pago")
    auth_header: Optional[str] = Field(default=None, description="Header de autorización para descargar la imagen (ej: 'Bearer TOKEN'). Requerido para WhatsApp Cloud API.")


class DescribeImageRequest(BaseModel):
    image_url: str = Field(..., description="URL de la imagen a describir")
    auth_header: Optional[str] = Field(default=None, description="Header de autorización para descargar la imagen (ej: 'Bearer TOKEN')")


# ================================================================
# Helpers
# ================================================================
ALLOWED_OBJECTIVES = {"OUTCOME_TRAFFIC", "OUTCOME_ENGAGEMENT", "OUTCOME_AWARENESS"}
ALLOWED_DESTINATIONS = {"instagram_profile", "instagram_dm", "whatsapp", "messenger"}
ALLOWED_CREATIVE_SOURCES = {"existing_post", "new_creative"}


def _resolve_effective_payload(payload: CreateCampaignRequest) -> Dict[str, Any]:
    """
    Aplana el payload a un dict que consume MetaAdsSkill.create_campaign.
    También aplica la capa de retro-compatibilidad: si llega el `creative`
    legacy y no vienen los campos nuevos, los hidrata desde ahí.
    """
    data = payload.model_dump()

    # --- Retro-compat: si viene el objeto creative viejo y no hay campos nuevos,
    #     popular image_urls / creative_message / creative_link desde ahí.
    legacy = data.get("creative")
    if legacy:
        if not data.get("creative_message"):
            data["creative_message"] = legacy.get("message")
        if not data.get("creative_link"):
            data["creative_link"] = legacy.get("link")
        if not data.get("image_urls"):
            img = legacy.get("image_url")
            if img:
                data["image_urls"] = [img]
        # Si el payload viejo no traía creative_source, asumimos new_creative
        if not data.get("creative_source"):
            data["creative_source"] = "new_creative"
        logger.info(
            "Retro-compat layer: payload legacy detectado, campos normalizados "
            "desde `creative`."
        )

    # --- Defaults razonables para campos opcionales
    data.setdefault("objective", "OUTCOME_TRAFFIC")
    data.setdefault("destination", "instagram_profile")
    data.setdefault("creative_source", "new_creative")
    data.setdefault("daily_budget", 100)
    data.setdefault("duration_days", 3)

    # --- Retro-compat: OUTCOME_AWARENESS → OUTCOME_TRAFFIC
    if data.get("objective") == "OUTCOME_AWARENESS":
        logger.info("Retro-compat: objective 'OUTCOME_AWARENESS' → 'OUTCOME_TRAFFIC'")
        data["objective"] = "OUTCOME_TRAFFIC"

    return data


def _validate_request(data: Dict[str, Any]) -> Optional[str]:
    """Devuelve un string con el motivo de error, o None si todo OK."""
    if data["objective"] not in ALLOWED_OBJECTIVES:
        return (
            f"objective inválido '{data['objective']}'. "
            f"Permitidos: {sorted(ALLOWED_OBJECTIVES)}"
        )
    if data["destination"] not in ALLOWED_DESTINATIONS:
        return (
            f"destination inválido '{data['destination']}'. "
            f"Permitidos: {sorted(ALLOWED_DESTINATIONS)}"
        )
    if data["creative_source"] not in ALLOWED_CREATIVE_SOURCES:
        return (
            f"creative_source inválido '{data['creative_source']}'. "
            f"Permitidos: {sorted(ALLOWED_CREATIVE_SOURCES)}"
        )

    if data["creative_source"] == "existing_post":
        if not data.get("instagram_post_url"):
            return "creative_source=existing_post requiere 'instagram_post_url'."
    else:  # new_creative
        if not data.get("image_urls"):
            return "creative_source=new_creative requiere al menos una imagen en 'image_urls'."
        if not data.get("creative_message"):
            return "creative_source=new_creative requiere 'creative_message'."

    return None


# ================================================================
# Endpoints
# ================================================================
@app.get("/", tags=["General"])
def root():
    return {
        "app": "Hermes Agent",
        "status": "online",
        "message": "El motor de campañas agénticas está listo para recibir instrucciones."
    }


# ================================================================
# WHATSAPP WEBHOOK ENDPOINTS
# ================================================================
@app.get("/webhook/whatsapp", tags=["WhatsApp"])
async def whatsapp_verify(request: Request):
    """Meta webhook verification endpoint. Returns hub.challenge when token matches."""
    params = dict(request.query_params)
    mode = params.get('hub.mode')
    challenge = params.get('hub.challenge')
    verify_token = params.get('hub.verify_token')

    logger.info(f"WhatsApp webhook verify: mode={mode}, token={verify_token}")

    if mode == 'subscribe' and verify_token == WHATSAPP_VERIFY_TOKEN:
        logger.info(f"Webhook verified! Returning challenge: {challenge}")
        return PlainTextResponse(content=challenge, status_code=200)

    logger.warning("Webhook verification FAILED - token mismatch")
    raise HTTPException(status_code=403, detail="Verification failed")


@app.post("/webhook/whatsapp", tags=["WhatsApp", "Messenger"])
async def whatsapp_receive(request: Request):
    """Receive webhook messages from Meta (WhatsApp + Messenger) and forward to n8n."""
    try:
        payload = await request.json()
        
        # Detect source: Messenger ("page") vs WhatsApp ("whatsapp_business_account")
        obj = payload.get('object', '')
        
        if obj == 'page':
            logger.info(f"Messenger message received — forwarding to n8n messenger workflow")
            target_url = N8N_MESSENGER_WEBHOOK
        else:
            logger.info(f"WhatsApp message received: {payload}")
            target_url = N8N_WHATSAPP_WEBHOOK

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                target_url,
                json=payload,
                headers={'Content-Type': 'application/json'}
            )
            logger.info(f"n8n response: {response.status_code}")

        return {"status": "ok"}

    except Exception as e:
        logger.error(f"Webhook error: {str(e)}")
        return {"status": "ok"}


# ================================================================
# MESSENGER WEBHOOK ENDPOINTS (mismo patrón que WhatsApp)
# ================================================================

@app.get("/webhook/messenger", tags=["Messenger"])
async def messenger_verify(request: Request):
    """Meta Messenger webhook verification endpoint."""
    params = dict(request.query_params)
    mode = params.get('hub.mode')
    challenge = params.get('hub.challenge')
    verify_token = params.get('hub.verify_token')

    logger.info(f"Messenger webhook verify: mode={mode}, token={verify_token}")

    if mode == 'subscribe' and verify_token == WHATSAPP_VERIFY_TOKEN:
        logger.info(f"Messenger webhook verified! Returning challenge: {challenge}")
        return PlainTextResponse(content=challenge, status_code=200)

    logger.warning("Messenger webhook verification FAILED")
    raise HTTPException(status_code=403, detail="Verification failed")


@app.post("/webhook/messenger", tags=["Messenger"])
async def messenger_receive(request: Request):
    """Receive Messenger messages from Meta and forward to n8n for AI processing."""
    try:
        payload = await request.json()
        logger.info(f"Messenger message received")

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                N8N_MESSENGER_WEBHOOK,
                json=payload,
                headers={'Content-Type': 'application/json'}
            )
            logger.info(f"n8n messenger response: {response.status_code}")

        return {"status": "ok"}

    except Exception as e:
        logger.error(f"Messenger webhook error: {str(e)}")
        return {"status": "ok"}


# ================================================================
# Health
# ================================================================
@app.get("/health", tags=["General"])
def health_check():
    verification = meta_ads.verify_page_access()
    if "error" in verification:
        return {
            "status": "degraded",
            "meta_connected": False,
            "details": verification
        }
    return {
        "status": "healthy",
        "meta_connected": True,
        "details": "Conectado correctamente con Meta Ads API"
    }


# ================================================================
# Campaigns
# ================================================================
@app.post("/create-campaign", status_code=status.HTTP_201_CREATED, tags=["Campaigns"])
def create_campaign(payload: CreateCampaignRequest):
    logger.info(
        f"Petición recibida para crear campaña de {payload.client_name} - Plan {payload.plan} "
        f"(objective={payload.objective}, destination={payload.destination}, "
        f"creative_source={payload.creative_source})"
    )

    data = _resolve_effective_payload(payload)

    # Validación semántica (después de aplicar retro-compat)
    err = _validate_request(data)
    if err:
        logger.error(f"Validación fallida: {err}")
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"message": "Validación de payload fallida", "error": err},
        )

    # Optimización con IA solo para new_creative
    if data["creative_source"] == "new_creative":
        raw_message = data.get("creative_message") or ""
        logger.info(f"Mensaje original antes de IA: '{raw_message}'")
        try:
            optimized_creative = ai_engine.optimize_creative_copy(
                client_name=data["client_name"],
                raw_message=raw_message,
                plan=data["plan"],
            )
            optimized_message = optimized_creative.get("message", raw_message)
            data["creative_message"] = optimized_message
            logger.info(f"Mensaje optimizado por IA: '{optimized_message}'")
        except Exception as e:
            logger.warning(f"No se pudo optimizar con IA, usando mensaje original. Error: {str(e)}")
    else:
        logger.info(
            "creative_source=existing_post → se salta la optimización con IA."
        )

    result = meta_ads.create_campaign(data)

    if not result.get("success", False):
        logger.error(f"Fallo en la creación de campaña: {result}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "No se pudo crear la campaña en Meta", "error": result},
        )

    return result


@app.get("/campaign-stats/{campaign_id}", tags=["Campaigns"])
def get_campaign_stats(campaign_id: str):
    logger.info(f"Petición para obtener estadísticas de campaña ID: {campaign_id}")
    stats = meta_ads.get_campaign_stats(campaign_id)

    if "error" in stats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "No se pudieron recuperar las estadísticas de Meta", "error": stats},
        )

    return stats


@app.post("/activate-campaign/{campaign_id}", tags=["Campaigns"])
def activate_campaign(campaign_id: str):
    logger.info(f"Petición para activar campaña ID: {campaign_id}")
    activation = meta_ads.activate_campaign(campaign_id)

    if "error" in activation:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"message": "No se pudo activar la campaña en Meta", "error": activation},
        )

    return {
        "success": True,
        "campaign_id": campaign_id,
        "status": "ACTIVE",
        "meta_response": activation,
    }


# ================================================================
# AI Engine endpoints (sin cambios)
# ================================================================
@app.post("/transcribe-audio", tags=["AI Engine"])
def transcribe_audio(payload: TranscribeAudioRequest):
    logger.info(f"Petición de transcripción recibida para: {payload.audio_url}")
    transcription = ai_engine.transcribe_audio_url(payload.audio_url, auth_header=payload.auth_header)
    return {"transcription": transcription}


@app.post("/validate-receipt", tags=["AI Engine"])
def validate_receipt(payload: ValidateReceiptRequest):
    logger.info(f"Petición de validación de recibo recibida para: {payload.image_url}")
    result = ai_engine.validate_payment_receipt_url(payload.image_url, auth_header=payload.auth_header)
    return result


@app.post("/describe-image", tags=["AI Engine"])
def describe_image(payload: DescribeImageRequest):
    logger.info(f"Petición de descripción de imagen recibida para: {payload.image_url}")
    description = ai_engine.describe_image_url(payload.image_url, auth_header=payload.auth_header)
    return {"description": description}
