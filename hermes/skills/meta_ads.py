import os
import re
import logging
import requests
from typing import Dict, Any, Optional, List

logger = logging.getLogger("hermes.skills.meta_ads")

class MetaAdsSkill:
    def __init__(self):
        self.access_token = os.getenv("META_PAGE_ACCESS_TOKEN")
        self.ad_account_id = os.getenv("META_AD_ACCOUNT_ID")
        self.page_id = os.getenv("META_PAGE_ID")
        self.instagram_actor_id = os.getenv("META_INSTAGRAM_ACTOR_ID")
        self.app_id = os.getenv("META_APP_ID")
        self.base_url = "https://graph.facebook.com/v21.0"

        # Validaciones de seguridad
        if not self.access_token:
            logger.error("META_PAGE_ACCESS_TOKEN no está configurado.")
        if not self.ad_account_id:
            logger.error("META_AD_ACCOUNT_ID no está configurado.")
        if not self.page_id:
            logger.error("META_PAGE_ID no está configurado.")
        if not self.instagram_actor_id:
            logger.warning("META_INSTAGRAM_ACTOR_ID no está configurado.")
        if not self.app_id:
            logger.warning("META_APP_ID no está configurado (necesario para destination=whatsapp).")

    # ================================================================
    # Destination / objective mapping
    # ================================================================
    # Mapeo canónico por destino — alineado con Meta Marketing API (v25.0) para
    # messaging ads (Click-to-DM / Click-to-WhatsApp / Click-to-Messenger).
    # destination_type / cta_type / app_destination son None para instagram_profile
    # porque NO es un anuncio de mensajería, es tráfico al perfil.
    DESTINATION_CONFIG: Dict[str, Dict[str, Any]] = {
        "instagram_profile": {
            "objective": "OUTCOME_TRAFFIC",
            "optimization_goal": "LINK_CLICKS",
            "build_promoted_object": "default",
            "destination_type": None,
            "cta_type": None,
            "app_destination": None,
        },
        "instagram_dm": {
            "objective": "OUTCOME_TRAFFIC",
            "optimization_goal": "CONVERSATIONS",
            "build_promoted_object": "instagram_dm",
            "destination_type": "INSTAGRAM_DIRECT",
            "cta_type": "INSTAGRAM_MESSAGE",
            "app_destination": "INSTAGRAM_DIRECT",
        },
        "whatsapp": {
            "objective": "OUTCOME_TRAFFIC",
            "optimization_goal": "CONVERSATIONS",
            # Fallback cuando Meta rechaza CONVERSATIONS por restricción regional
            # (error_subcode 2446921 — Venezuela / números no soportados).
            # IMPRESSIONS es válido para Click-to-WhatsApp según Meta Marketing API docs.
            "fallback_optimization_goal": "IMPRESSIONS",
            "build_promoted_object": "whatsapp",
            "destination_type": "WHATSAPP",
            "cta_type": "WHATSAPP_MESSAGE",
            "app_destination": "WHATSAPP",
        },
        "messenger": {
            "objective": "OUTCOME_TRAFFIC",
            "optimization_goal": "CONVERSATIONS",
            "build_promoted_object": "default",
            "destination_type": "MESSENGER",
            "cta_type": "MESSAGE_PAGE",
            "app_destination": "MESSENGER",
        },
    }

    def _resolve_destination_config(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Devuelve (objective, optimization_goal, promoted_object, destination_type,
        cta_type, app_destination) según destination.

        Los campos destination_type / cta_type / app_destination vienen en None para
        destinos no-messaging (ej. instagram_profile) y en su valor canónico para
        destinos de mensajería (instagram_dm / whatsapp / messenger).
        """
        destination = data.get("destination", "instagram_profile")
        cfg = self.DESTINATION_CONFIG.get(destination)

        if not cfg:
            logger.warning(
                f"Destination '{destination}' desconocida, usando defaults (instagram_profile)."
            )
            cfg = self.DESTINATION_CONFIG["instagram_profile"]
            destination = "instagram_profile"

        # Per-client overrides: si el request trae page_id / instagram_actor_id
        # los usamos; si no, caen a los defaults de .env (self.*).
        page_id = data.get("page_id", self.page_id)
        ig_actor_id = data.get("instagram_actor_id", self.instagram_actor_id)

        # El objetivo puede venir forzado desde el request; si no, usamos el del mapping
        objective = data.get("objective") or cfg["objective"]

        # Construir promoted_object según el builder del destino
        builder = cfg["build_promoted_object"]
        promoted_object: Dict[str, Any] = {}

        if builder == "whatsapp":
            if not self.app_id:
                logger.warning(
                    "destination=whatsapp requiere META_APP_ID. "
                    "La campaña puede fallar al activarse sin este ID."
                )
            promoted_object = {
                "page_id": page_id,
            }
            if self.app_id:
                promoted_object["application_id"] = self.app_id
        elif builder == "instagram_dm":
            promoted_object = {"page_id": page_id}
            if not ig_actor_id:
                logger.warning(
                    "destination=instagram_dm: instagram_actor_id vacío. "
                    "Mensajes a DM pueden no enrutar correctamente."
                )
        else:
            promoted_object = {"page_id": page_id}

        return {
            "destination": destination,
            "objective": objective,
            "optimization_goal": cfg["optimization_goal"],
            "fallback_optimization_goal": cfg.get("fallback_optimization_goal"),
            "promoted_object": promoted_object,
            "destination_type": cfg.get("destination_type"),
            "cta_type": cfg.get("cta_type"),
            "app_destination": cfg.get("app_destination"),
        }

    # ================================================================
    # Campaign flow
    # ================================================================
    def create_campaign(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Crear campaña completa en Meta Ads: Campaign → AdSet → AdCreative → Ad"""
        try:
            campaign_id = self._create_campaign_objective(data)
            if not campaign_id:
                return {"error": "Campaign creation failed", "details": "No campaign_id returned"}

            adset_result = self._create_adset(data, campaign_id)
            if not adset_result:
                return {
                    "success": False,
                    "campaign_id": campaign_id,
                    "error": "AdSet creation failed",
                }
            adset_id, optimization_goal_used = adset_result

            creative_id = self._create_ad_creative(data)
            if not creative_id:
                return {
                    "success": False,
                    "campaign_id": campaign_id,
                    "adset_id": adset_id,
                    "optimization_goal_used": optimization_goal_used,
                    "error": "AdCreative creation failed",
                }

            ad_id = self._create_ad(data, adset_id, creative_id)
            if not ad_id:
                return {
                    "success": False,
                    "campaign_id": campaign_id,
                    "adset_id": adset_id,
                    "creative_id": creative_id,
                    "optimization_goal_used": optimization_goal_used,
                    "error": "Ad creation failed",
                }

            logger.info(
                f"¡Campaña de Meta Ads configurada exitosamente! "
                f"campaign_id={campaign_id}, adset_id={adset_id}, "
                f"creative_id={creative_id}, ad_id={ad_id}"
            )
            return {
                "success": True,
                "campaign_id": campaign_id,
                "adset_id": adset_id,
                "creative_id": creative_id,
                "ad_id": ad_id,
                "optimization_goal_used": optimization_goal_used,
                "status": "PAUSED",
                "destination": data.get("destination", "instagram_profile"),
                "objective": data.get("objective", "OUTCOME_TRAFFIC"),
            }

        except Exception as e:
            logger.error(f"Error inesperado al crear campaña en Meta: {str(e)}")
            return {"error": "Unexpected exception", "details": str(e)}

    def _create_campaign_objective(self, data: Dict[str, Any]) -> Optional[str]:
        """Crea solo la campaña y devuelve su ID."""
        dest_cfg = self._resolve_destination_config(data)
        campaign_url = f"{self.base_url}/{self.ad_account_id}/campaigns"
        campaign_data = {
            "name": (
                f"AdsVzla-[{data.get('client_psid', 'unknown')}]-"
                f"{data.get('client_name', 'client')}-{data.get('plan', 'plan')}"
            ),
            "objective": dest_cfg["objective"],
            "status": "PAUSED",
            "special_ad_categories": [],
            "daily_budget": data.get("daily_budget", 100),  # centavos
            "bid_strategy": "LOWEST_COST_WITHOUT_CAP",
            "access_token": self.access_token,
        }

        logger.info(
            f"Creando Campaña en Meta para {data.get('client_name')} "
            f"(objective={dest_cfg['objective']}, destination={dest_cfg['destination']})"
        )
        campaign_res = requests.post(campaign_url, json=campaign_data, timeout=15).json()
        campaign_id = campaign_res.get("id")

        if not campaign_id:
            logger.error(f"Fallo al crear campaña: {campaign_res}")
            return None

        logger.info(f"Campaña creada exitosamente. ID: {campaign_id}")
        return campaign_id

    def _create_adset(self, data: Dict[str, Any], campaign_id: str) -> Optional[tuple]:
        """Crea el AdSet con promoted_object correcto.

        Devuelve (adset_id, optimization_goal_used) en éxito, o None en fallo.
        Si Meta rechaza el optimization_goal primario por restricción regional
        (error_subcode 2446921 — ej. CONVERSATIONS no disponible para números
        de WhatsApp de Venezuela), reintenta automáticamente con el fallback
        configurado en DESTINATION_CONFIG.
        """
        dest_cfg = self._resolve_destination_config(data)
        adset_url = f"{self.base_url}/{self.ad_account_id}/adsets"
        targeting = data.get("targeting", {})

        # Formatear segmentación geográfica
        geo_locations: Dict[str, Any] = {}
        if targeting.get("cities"):
            geo_locations["cities"] = [{"key": c} for c in targeting.get("cities", [])]
        if targeting.get("countries"):
            geo_locations["countries"] = targeting.get("countries")

        if not geo_locations:
            geo_locations["countries"] = ["VE"]

        targeting_spec: Dict[str, Any] = {
            "geo_locations": geo_locations,
            "age_min": targeting.get("age_min", 18),
            "age_max": targeting.get("age_max", 65),
        }
        if targeting.get("interests"):
            targeting_spec["interests"] = [
                {"id": i} for i in targeting.get("interests", [])
            ]
        # targeting_automation va NIDADO dentro de targeting según Meta Marketing API docs.
        # Estar top-level en el AdSet es deprecado/ignorado y puede causar advertencias.
        targeting_spec["targeting_automation"] = {"advantage_audience": 0}

        adset_data: Dict[str, Any] = {
            "name": f"AdSet-{data.get('client_name', 'client')}",
            "campaign_id": campaign_id,
            "billing_event": "IMPRESSIONS",
            "optimization_goal": dest_cfg["optimization_goal"],
            "targeting": targeting_spec,
            "status": "PAUSED",
            "promoted_object": dest_cfg["promoted_object"],
            "access_token": self.access_token,
        }

        # destination_type es OBLIGATORIO para ads de mensajería (DM / WhatsApp / Messenger)
        # y debe ir al top-level del AdSet. Para instagram_profile queda omitido.
        if dest_cfg.get("destination_type"):
            adset_data["destination_type"] = dest_cfg["destination_type"]

        logger.info(
            f"Creando AdSet para campaign_id={campaign_id} "
            f"optimization_goal={dest_cfg['optimization_goal']} "
            f"destination_type={dest_cfg.get('destination_type')} "
            f"promoted_object={dest_cfg['promoted_object']}"
        )
        adset_res = requests.post(adset_url, json=adset_data, timeout=15).json()
        adset_id = adset_res.get("id")

        # Fallback: si Meta rechaza CONVERSATIONS por restricción regional
        # (error_subcode 2446921), reintentamos con el optimization_goal alternativo
        # configurado en DESTINATION_CONFIG.
        if not adset_id:
            error_subcode = (
                adset_res.get("error", {}).get("error_subcode")
            )
            fallback = dest_cfg.get("fallback_optimization_goal")

            if error_subcode == 2446921 and fallback:
                logger.warning(
                    f"CONVERSATIONS rechazado por región (error_subcode=2446921). "
                    f"Reintentando con optimization_goal={fallback}"
                )
                adset_data["optimization_goal"] = fallback
                adset_res = requests.post(adset_url, json=adset_data, timeout=15).json()
                adset_id = adset_res.get("id")

                if adset_id:
                    logger.info(
                        f"AdSet creado exitosamente con fallback. "
                        f"ID: {adset_id}, optimization_goal={fallback}"
                    )
                    return adset_id, fallback

            logger.error(f"Fallo al crear AdSet: {adset_res}")
            return None

        logger.info(f"AdSet creado exitosamente. ID: {adset_id}")
        return adset_id, dest_cfg["optimization_goal"]

    # ================================================================
    # Creative dispatch
    # ================================================================
    def _create_ad_creative(self, data: Dict[str, Any]) -> Optional[str]:
        """Despacha al path A (existing_post) o B (new_creative)."""
        source = data.get("creative_source", "new_creative")
        if source == "existing_post":
            return self._create_ad_creative_from_post(data)
        return self._create_ad_creative_new(data)

    @staticmethod
    def _extract_instagram_post_id(post_url: str) -> Optional[str]:
        """
        Extrae el ID de un post de Instagram desde su URL.
        Soporta formatos:
          - https://www.instagram.com/p/<shortcode>/
          - https://instagram.com/p/<shortcode>/
          - https://www.instagram.com/reel/<shortcode>/
        Para shortcodes de IG, Meta provee un endpoint /instagram_media_lookup,
        pero como el cliente puede pasar el ID directamente, también aceptamos
        URLs con ?id= o que ya contengan el post_id numérico.
        """
        if not post_url:
            return None

        m = re.search(r"instagram\.com/(?:p|reel)/([A-Za-z0-9_-]+)", post_url)
        if not m:
            # Quizás ya viene el ID puro
            return post_url.strip().rstrip("/")
        return m.group(1)

    def _resolve_existing_post_id(self, post_url: str) -> Optional[str]:
        """
        Resuelve el ID numérico real de un post de Instagram a partir de su URL.
        Meta Ads requiere el ID numérico, no el shortcode. Usamos el endpoint
        /{page_id}/media para encontrar la coincidencia, o el endpoint genérico
        de oEmbed como fallback.
        """
        shortcode_or_id = self._extract_instagram_post_id(post_url)
        if not shortcode_or_id:
            return None

        # Si ya es numérico, devolverlo tal cual
        if shortcode_or_id.isdigit():
            return shortcode_or_id

        # Si es shortcode, buscar el media id real en los medios de la página IG
        if not self.instagram_actor_id:
            logger.warning(
                "No se puede resolver shortcode → media_id sin META_INSTAGRAM_ACTOR_ID. "
                "Pasa el post_id numérico en instagram_post_url o configura META_INSTAGRAM_ACTOR_ID."
            )
            # Devolvemos el shortcode igualmente; Meta puede rechazarlo, pero el caller lo verá
            return shortcode_or_id

        try:
            url = f"{self.base_url}/{self.instagram_actor_id}/media"
            params = {
                "fields": "id,permalink",
                "access_token": self.access_token,
                "limit": 50,
            }
            logger.info(f"Resolviendo shortcode '{shortcode_or_id}' contra {url}")
            resp = requests.get(url, params=params, timeout=15).json()
            for item in resp.get("data", []):
                permalink = item.get("permalink", "")
                if shortcode_or_id in permalink:
                    return item.get("id")
            logger.warning(
                f"No se encontró media_id para shortcode '{shortcode_or_id}' en los "
                f"últimos 50 medios del IG actor."
            )
        except Exception as e:
            logger.error(f"Error resolviendo shortcode de Instagram: {str(e)}")

        return shortcode_or_id  # fallback

    def _create_ad_creative_from_post(self, data: Dict[str, Any]) -> Optional[str]:
        """
        Path A: crea un AdCreative que referencia un post de Instagram existente
        (el cliente ya publicó en su feed y quiere boost).
        """
        # Per-client overrides con fallback a .env
        page_id = data.get("page_id", self.page_id)
        ig_actor_id = data.get("instagram_actor_id", self.instagram_actor_id)

        post_url = data.get("instagram_post_url")
        if not post_url:
            logger.error("creative_source=existing_post pero falta instagram_post_url")
            return None

        post_id = self._resolve_existing_post_id(post_url)
        if not post_id:
            logger.error(f"No se pudo extraer post_id de la URL: {post_url}")
            return None

        logger.info(f"Creando AdCreative Path A (existing_post): post_id={post_id}")

        creative_url = f"{self.base_url}/{self.ad_account_id}/adcreatives"

        # Para referenciar un post IG existente en v21.0, la forma más estable es
        # usar object_story_spec con link_data cuando el post es del feed IG
        # del actor. Meta también soporta instagram_permalink_url directo.
        story_spec: Dict[str, Any] = {
            "page_id": page_id,
            "link_data": {
                "link": data.get("creative_link")
                or f"https://www.instagram.com/p/{post_id}/",
                "message": (
                    f"Boost de publicación existente "
                    f"(cliente: {data.get('client_name', 'client')})"
                ),
            },
        }
        if ig_actor_id:
            story_spec["instagram_actor_id"] = ig_actor_id

        creative_data = {
            "name": f"Creative-ExistingPost-{data.get('client_name', 'client')}",
            "object_story_spec": story_spec,
            "access_token": self.access_token,
        }

        creative_res = requests.post(creative_url, json=creative_data, timeout=15).json()
        creative_id = creative_res.get("id")

        if not creative_id:
            logger.error(f"Fallo al crear AdCreative (existing_post): {creative_res}")
            return None

        logger.info(f"AdCreative Path A creado exitosamente. ID: {creative_id}")
        return creative_id

    def _create_ad_creative_new(self, data: Dict[str, Any]) -> Optional[str]:
        """
        Path B: crea un AdCreative con copy optimizado por IA + imágenes subidas.
        El message ya viene optimizado desde main.py (ai_engine.optimize_creative_copy).

        Para destinos de mensajería (instagram_dm / whatsapp / messenger) inyecta
        call_to_action con app_destination dentro de link_data + page_welcome_message,
        y agrega instagram_actor_id a story_spec cuando es instagram_dm. Sin estos
        campos Meta crea el anuncio pero NO renderiza el botón de mensaje.
        """
        # Per-client overrides con fallback a .env
        page_id = data.get("page_id", self.page_id)
        ig_actor_id = data.get("instagram_actor_id", self.instagram_actor_id)

        creative = data.get("creative", {}) or {}
        message = (
            data.get("creative_message")
            or creative.get("message")
            or "¡Visita nuestra página!"
        )
        link = (
            data.get("creative_link")
            or creative.get("link")
            or "https://instagram.com/ads_vnzla"
        )

        # Aceptar image_urls (lista) o image_url (string, retro-compat)
        image_urls: List[str] = []
        raw_urls = data.get("image_urls")
        if isinstance(raw_urls, list) and raw_urls:
            image_urls = [u for u in raw_urls if u]
        elif isinstance(raw_urls, str) and raw_urls:
            image_urls = [raw_urls]
        if not image_urls and creative.get("image_url"):
            image_urls = [creative["image_url"]]
        # Filtrar vacíos
        image_urls = [u for u in image_urls if u]

        picture = image_urls[0] if image_urls else None

        # Resolver destination config para saber si es messaging y aplicar campos extra
        dest_cfg = self._resolve_destination_config(data)
        destination = dest_cfg["destination"]
        cta_type = dest_cfg.get("cta_type")
        app_destination = dest_cfg.get("app_destination")

        logger.info(
            f"Creando AdCreative Path B (new_creative) con {len(image_urls)} imagen(es) "
            f"destination={destination} cta_type={cta_type} app_destination={app_destination}"
        )

        creative_url = f"{self.base_url}/{self.ad_account_id}/adcreatives"
        link_data: Dict[str, Any] = {
            "message": message,
            "link": link,
        }
        if picture:
            link_data["picture"] = picture

        # Para destinos de mensajería: CTA + app_destination + welcome message.
        # Sin esto Meta crea el anuncio pero NO muestra el botón de mensaje al usuario.
        if cta_type and app_destination:
            link_data["call_to_action"] = {
                "type": cta_type,
                "value": {"app_destination": app_destination},
            }
            # Mensaje de bienvenida que verá el usuario al iniciar la conversación.
            # Solo aplica a destinos con inbox (DM, Messenger, WhatsApp Business).
            link_data["page_welcome_message"] = (
                "¡Hola! Gracias por tu interés en Ads Vzla. ¿En qué podemos ayudarte?"
            )

        story_spec: Dict[str, Any] = {
            "page_id": page_id,
            "link_data": link_data,
        }

        # instagram_actor_id es OBLIGATORIO para instagram_dm (sino Meta no sabe
        # a qué cuenta IG enrutar el DM). Se loguea warning si falta.
        if destination == "instagram_dm":
            if ig_actor_id:
                story_spec["instagram_actor_id"] = ig_actor_id
            else:
                logger.warning(
                    "instagram_dm requiere instagram_actor_id — "
                    "configuralo en .env o pasalo en el request, sino los DMs no van a rutear correctamente."
                )
        elif ig_actor_id:
            # Para los otros destinos lo agregamos si está disponible (boost IG opcional)
            story_spec["instagram_actor_id"] = ig_actor_id

        creative_data = {
            "name": f"Creative-New-{data.get('client_name', 'client')}",
            "object_story_spec": story_spec,
            "access_token": self.access_token,
        }

        creative_res = requests.post(creative_url, json=creative_data, timeout=15).json()
        creative_id = creative_res.get("id")

        if not creative_id:
            logger.error(f"Fallo al crear AdCreative (new_creative): {creative_res}")
            return None

        logger.info(f"AdCreative Path B creado exitosamente. ID: {creative_id}")
        return creative_id

    def _create_ad(
        self, data: Dict[str, Any], adset_id: str, creative_id: str
    ) -> Optional[str]:
        """Crea el Ad final vinculando AdSet y AdCreative."""
        ad_url = f"{self.base_url}/{self.ad_account_id}/ads"
        ad_data = {
            "name": f"Ad-{data.get('client_name', 'client')}",
            "adset_id": adset_id,
            "creative": {"creative_id": creative_id},
            "status": "PAUSED",
            "access_token": self.access_token,
        }

        logger.info(f"Creando Anuncio final (Ad) adset_id={adset_id}")
        ad_res = requests.post(ad_url, json=ad_data, timeout=15).json()
        ad_id = ad_res.get("id")

        if not ad_id:
            logger.error(f"Fallo al crear Ad: {ad_res}")
            return None

        logger.info(f"Ad creado exitosamente. ID: {ad_id}")
        return ad_id

    # ================================================================
    # Métodos existentes sin tocar
    # ================================================================
    def verify_page_access(self) -> Dict[str, Any]:
        """Verificar acceso a página e Instagram vinculado"""
        try:
            url = f"{self.base_url}/me/accounts"
            params = {
                "fields": "name,id,instagram_business_account{id,username}",
                "access_token": self.access_token
            }
            logger.info(f"Verificando acceso a páginas en Meta Graph API")
            response = requests.get(url, params=params, timeout=15)
            return response.json()
        except Exception as e:
            logger.error(f"Error al verificar acceso a Meta: {str(e)}")
            return {"error": "Connection failed", "details": str(e)}

    def get_campaign_stats(self, campaign_id: str) -> Dict[str, Any]:
        """Obtener métricas de rendimiento en tiempo real (Insights)"""
        try:
            url = f"{self.base_url}/{campaign_id}/insights"
            params = {
                "fields": "impressions,clicks,spend,reach,ctr,cpp",
                "access_token": self.access_token
            }
            logger.info(f"Consultando estadísticas de campaña ID: {campaign_id}")
            response = requests.get(url, params=params, timeout=15)
            return response.json()
        except Exception as e:
            logger.error(f"Error al obtener métricas de Meta: {str(e)}")
            return {"error": "Connection failed", "details": str(e)}

    def activate_campaign(self, campaign_id: str) -> Dict[str, Any]:
        """Activar campaña (de PAUSED a ACTIVE)"""
        try:
            url = f"{self.base_url}/{campaign_id}"
            data = {
                "status": "ACTIVE",
                "access_token": self.access_token
            }
            logger.info(f"Activando campaña ID: {campaign_id}")
            response = requests.post(url, json=data, timeout=15)
            return response.json()
        except Exception as e:
            logger.error(f"Error al activar campaña en Meta: {str(e)}")
            return {"error": "Connection failed", "details": str(e)}
