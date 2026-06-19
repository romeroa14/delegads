import os
import json
import logging
import requests
from typing import Dict, Any, List, Optional
from datetime import date, timedelta

import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger("hermes.skills.content_bot")

VALID_TYPES = {"feed", "reel", "story"}

_DEFAULT_BRIEFING = [
    {"id": "q1", "question": "¿Cuál es la propuesta de valor única de tu negocio? ¿Qué problema resolvés?",
     "placeholder": "ej: Vendemos comida rápida con delivery en 30 min"},
    {"id": "q2", "question": "¿Quién es tu cliente ideal? Describilo con edad, intereses y dolor principal.",
     "placeholder": "ej: Madres de 25-40 años en Caracas que buscan opciones saludables"},
    {"id": "q3", "question": "¿Qué te diferencia de tu competencia directa?",
     "placeholder": "ej: Atención personalizada, ingredientes importados, delivery gratis"},
    {"id": "q4", "question": "¿Qué tono de marca preferís? (cercano, formal, juvenil, técnico)",
     "placeholder": "ej: Cercano y juvenil, con humor"},
    {"id": "q5", "question": "¿Qué tipo de contenido querés publicado? (promociones, educación, comunidad, behind the scenes)",
     "placeholder": "ej: Mix de promociones y detrás de cámaras"},
]

_FALLBACK_STRATEGY = {
    "tone": "cercano y profesional",
    "topics": ["promociones", "testimonios", "producto"],
    "audience": "clientes venezolanos",
    "pillars": ["educación", "promoción", "comunidad"],
    "hashtags_base": ["#Venezuela", "#Pyme", "#TuNegocio"],
    "best_posting_hours": {"feed": "19:00", "reel": "20:00", "story": "12:00"},
    "summary": "Estrategia genérica (fallback).",
}


class ContentBotSkill:
    """Skill para el ContentBot: briefing, generación de calendario mensual
    (3 posts/sem + 1 reel/sem + 2 stories/día) y scheduling vía Meta Graph API."""

    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.base_url = "https://openrouter.ai/api/v1"
        self.default_model = "google/gemini-2.5-flash"
        self.meta_token = os.getenv("META_PAGE_ACCESS_TOKEN", "")
        self.db_host = os.getenv("DB_HOST", "laravel-postgres")
        self.db_port = os.getenv("DB_PORT", "5432")
        self.db_name = os.getenv("DB_DATABASE", "fb_google")
        self.db_user = os.getenv("DB_USERNAME", "postgres")
        self.db_pass = os.getenv("DB_PASSWORD", "postgres")
        if not self.api_key:
            logger.warning("OPENROUTER_API_KEY no está configurada.")

    # ---- DB helpers ----
    def _conn(self):
        return psycopg2.connect(
            host=self.db_host, port=self.db_port, dbname=self.db_name,
            user=self.db_user, password=self.db_pass,
        )

    def _exec(self, sql, params=()):
        with self._conn() as c, c.cursor() as cur:
            cur.execute(sql, params)

    def _fetchone(self, sql, params=()):
        with self._conn() as c, c.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
            return dict(row) if row else None

    def _fetchall(self, sql, params=()):
        with self._conn() as c, c.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            return [dict(r) for r in cur.fetchall()]

    # ---- OpenRouter (Gemini 2.5 Flash) ----
    def _call_openrouter(self, messages, json_mode=True):
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY no configurada.")
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://adsvnzla.admetricas.com",
            "X-Title": "Hermes ContentBot",
        }
        payload = {"model": self.default_model, "messages": messages, "temperature": 0.7}
        if json_mode:
            payload["response_format"] = {"type": "json_object"}
        resp = requests.post(
            f"{self.base_url}/chat/completions",
            headers=headers, json=payload, timeout=60,
        )
        resp.raise_for_status()
        choices = resp.json().get("choices", [])
        if not choices:
            raise ValueError("Respuesta de modelo vacía")
        return choices[0]["message"]["content"].strip()

    # ---- Public API ----
    def generate_briefing(self, lead_id, business_name=None, business_type=None):
        """Genera 5 preguntas personalizadas en español venezolano para conocer el negocio."""
        ctx_name = business_name or "el cliente"
        ctx_type = business_type or "un negocio local en Venezuela"
        system = (
            "Sos un estratega de contenido social senior especializado en PYMES venezolanas. "
            "Tu tarea es generar 5 preguntas de briefing en español venezolano (usá 'tú' preferentemente) "
            "cortas, claras, accionables, orientadas a descubrir: propuesta de valor, público objetivo, "
            "diferenciadores, tono de marca y tipo de contenido. "
            "Devolvé un objeto JSON con la forma: "
            "{\"questions\": [{\"id\": \"q1\", \"question\": \"...\", \"placeholder\": \"ej: ...\"}, ...]} (exactamente 5)."
        )
        user = f"Negocio: {ctx_name}\nTipo: {ctx_type}\nGenerá las 5 preguntas de briefing."
        try:
            raw = self._call_openrouter(
                [{"role": "system", "content": system},
                 {"role": "user", "content": user}], json_mode=True,
            )
            questions = (json.loads(raw)).get("questions") or []
            return {"success": True, "lead_id": lead_id, "questions": questions[:5]}
        except Exception as e:
            logger.error(f"Error generando briefing: {e}")
            return {"success": True, "lead_id": lead_id, "questions": _DEFAULT_BRIEFING, "fallback": True}

    def process_briefing_answers(self, lead_id, answers):
        """Procesa respuestas del cliente y devuelve una estrategia de contenido (persistida en agent_handoff)."""
        system = (
            "Sos un estratega de contenido senior para PYMES venezolanas. "
            "Recibís respuestas de briefing de un cliente y debés sintetizar una estrategia "
            "para un plan de $180 USD/mes (3 feed/sem + 1 reel/sem + 2 stories/día). "
            "Devolvé JSON con: {\"strategy\": {\"tone\": \"...\", \"topics\": [\"...\"], "
            "\"audience\": \"...\", \"pillars\": [\"...\"], \"hashtags_base\": [\"#...\"], "
            "\"best_posting_hours\": {\"feed\": \"HH:MM\", \"reel\": \"HH:MM\", \"story\": \"HH:MM\"}, "
            "\"summary\": \"...\"}}."
        )
        user = f"Cliente lead_id={lead_id}\nRespuestas:\n{json.dumps(answers, ensure_ascii=False)}"
        try:
            raw = self._call_openrouter(
                [{"role": "system", "content": system},
                 {"role": "user", "content": user}], json_mode=True,
            )
            strategy = (json.loads(raw)).get("strategy") or _FALLBACK_STRATEGY
        except Exception as e:
            logger.error(f"Error generando estrategia: {e}")
            strategy = dict(_FALLBACK_STRATEGY)
        with self._conn() as c, c.cursor() as cur:
            cur.execute(
                "INSERT INTO agent_handoff (lead_id, from_agent, to_agent, context, status, result, completed_at) "
                "VALUES (%s, 'valeria', 'content_bot', %s::jsonb, 'completed', %s::jsonb, NOW())",
                (lead_id, json.dumps({"answers": answers}), json.dumps({"strategy": strategy})),
            )
        return {"success": True, "lead_id": lead_id, "strategy": strategy}

    def generate_monthly_calendar(self, lead_id, strategy, month=None):
        """Genera un calendario mensual (3 feed/sem + 1 reel/sem + 2 stories/día) y lo guarda en content_calendar."""
        today = date.today()
        if month is None:
            month = 1 if today.month == 12 else today.month + 1
        # Ajuste de año si diciembre → enero
        target_year = today.year + (1 if month == 1 and today.month == 12 else 0)
        first_day = date(target_year, month, 1)
        last_day = date(target_year + 1, 1, 1) - timedelta(days=1) if month == 12 \
            else date(target_year, month + 1, 1) - timedelta(days=1)
        days = (last_day - first_day).days + 1

        system = (
            "Sos un planificador de contenido social para Venezuela. "
            f"Recibís una estrategia y debés generar UN calendario para {days} días del mes "
            f"({first_day.isoformat()} a {last_day.isoformat()}) con: "
            "3 posts de feed por semana (lun, mié, vie), 1 reel por semana (sáb), "
            "2 stories por día (mañana y tarde). Cada item debe tener copy en español venezolano "
            "(tono cálido, profesional, sin sobrecargar de jerga), descripción de imagen sugerida, "
            "3-5 hashtags y hora de publicación (HH:MM 24h, hora Venezuela UTC-4). "
            "Devolvé JSON: {\"items\": [{\"date\": \"YYYY-MM-DD\", \"type\": \"feed|reel|story\", "
            "\"text\": \"...\", \"image_description\": \"...\", "
            "\"hashtags\": [\"#...\"], \"scheduled_time\": \"HH:MM\"}, ...]}."
        )
        user = f"Estrategia:\n{json.dumps(strategy, ensure_ascii=False)}\nGenerá el calendario completo."
        try:
            raw = self._call_openrouter(
                [{"role": "system", "content": system},
                 {"role": "user", "content": user}], json_mode=True,
            )
            items = (json.loads(raw)).get("items") or []
        except Exception as e:
            logger.error(f"Error generando calendario: {e}")
            return {"success": False, "error": str(e)}

        inserted = []
        with self._conn() as c, c.cursor() as cur:
            for it in items:
                if it.get("type") not in VALID_TYPES:
                    continue
                cur.execute(
                    "INSERT INTO content_calendar "
                    "(lead_id, post_date, post_type, content_text, media_type, platform, status, scheduled_at) "
                    "VALUES (%s, %s, %s, %s, %s, 'instagram', 'draft', "
                    "    (TIMESTAMP %s::date || ' ' || %s)::timestamp) "
                    "RETURNING id",
                    (lead_id, it.get("date"), it.get("type"), it.get("text"),
                     "video" if it.get("type") == "reel" else "image",
                     it.get("date"), it.get("scheduled_time", "12:00")),
                )
                inserted.append(cur.fetchone()[0])
        return {"success": True, "lead_id": lead_id, "month": month, "year": target_year,
                "items_created": len(inserted), "ids": inserted}

    def schedule_post(self, calendar_id):
        """Marca un post del calendario como scheduled. La publicación real la hace el scheduler
        (n8n → Meta Graph API) usando META_PAGE_ACCESS_TOKEN."""
        item = self._fetchone("SELECT * FROM content_calendar WHERE id = %s", (calendar_id,))
        if not item:
            return {"success": False, "error": f"calendar_id {calendar_id} no existe."}
        if not self.meta_token:
            return {"success": False, "error": "META_PAGE_ACCESS_TOKEN no configurado."}
        placeholder_id = f"pending-{calendar_id}-{date.today().strftime('%Y%m%d')}"
        self._exec(
            "UPDATE content_calendar SET status='scheduled', meta_post_id=%s, updated_at=NOW() WHERE id=%s",
            (placeholder_id, calendar_id),
        )
        return {"success": True, "calendar_id": calendar_id, "status": "scheduled",
                "meta_post_id": placeholder_id,
                "note": "Pendiente de publicación por el scheduler (n8n → Meta Graph API)."}

    def get_calendar(self, lead_id, month=None, year=None):
        """Devuelve el calendario de un cliente, opcionalmente filtrado por mes/año."""
        today = date.today()
        m = month or today.month
        y = year or today.year
        rows = self._fetchall(
            "SELECT id, post_date, post_type, content_text, media_url, media_type, "
            "platform, status, scheduled_at, published_at, meta_post_id "
            "FROM content_calendar "
            "WHERE lead_id = %s AND EXTRACT(YEAR FROM post_date) = %s "
            "AND EXTRACT(MONTH FROM post_date) = %s "
            "ORDER BY post_date ASC, scheduled_at ASC",
            (lead_id, y, m),
        )
        for r in rows:
            for k in ("post_date", "scheduled_at", "published_at"):
                if r.get(k) is not None:
                    r[k] = r[k].isoformat()
        return {"success": True, "lead_id": lead_id, "month": m, "year": y,
                "items": rows, "count": len(rows)}
