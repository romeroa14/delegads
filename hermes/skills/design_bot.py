import os
import json
import logging
import requests
from typing import Dict, Any, Optional

import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger("hermes.skills.design_bot")

VALID_STATUSES = {"requested", "in_progress", "review", "approved", "rejected", "fallback_ai"}


class DesignBotSkill:
    """Skill para el DesignBot: generación de diseños con IA y asignación
    a diseñadores humanos con fallback automático a IA tras N días."""

    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.image_model = os.getenv("OPENROUTER_IMAGE_MODEL", "google/imagen-3")
        self.fallback_image_model = os.getenv("OPENROUTER_FALLBACK_IMAGE_MODEL", "openai/gpt-5-image")
        self.ai_price = float(os.getenv("DESIGN_AI_PRICE", "5"))
        self.human_price = float(os.getenv("DESIGN_HUMAN_PRICE", "15"))
        self.fallback_days = int(os.getenv("DESIGN_FALLBACK_DAYS", "7"))
        self.base_url = "https://openrouter.ai/api/v1"
        # DB connection (Laravel postgres container)
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

    def _exec(self, sql: str, params: tuple = ()) -> None:
        with self._conn() as c, c.cursor() as cur:
            cur.execute(sql, params)

    def _fetchone(self, sql: str, params: tuple = ()) -> Optional[Dict[str, Any]]:
        with self._conn() as c, c.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
            return dict(row) if row else None

    def _fetchall(self, sql: str, params: tuple = ()):
        with self._conn() as c, c.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

    def _pick_designer(self, preferred_id: Optional[int]) -> Optional[Dict[str, Any]]:
        if preferred_id:
            return self._fetchone(
                "SELECT id, name, current_workload, max_workload "
                "FROM designers WHERE id = %s AND is_active = true",
                (preferred_id,),
            )
        return self._fetchone(
            "SELECT id, name, current_workload, max_workload FROM designers "
            "WHERE is_active = true AND current_workload < max_workload "
            "ORDER BY current_workload ASC, rating DESC LIMIT 1",
        )

    def _adjust_workload(self, designer_id: Optional[int], delta: int) -> None:
        if not designer_id or delta == 0:
            return
        self._exec(
            "UPDATE designers SET current_workload = GREATEST(0, current_workload + %s), "
            "updated_at = NOW() WHERE id = %s",
            (delta, designer_id),
        )

    # ---- OpenRouter image generation ----
    def _call_openrouter_images(self, prompt: str, style_preferences: Optional[Dict[str, Any]]) -> Optional[str]:
        if not self.api_key:
            logger.error("Intento de generación de imagen sin OPENROUTER_API_KEY.")
            return None
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://adsvnzla.admetricas.com",
            "X-Title": "Hermes DesignBot",
        }
        full_prompt = prompt
        if style_preferences:
            hints = ", ".join(f"{k}: {v}" for k, v in style_preferences.items() if v)
            if hints:
                full_prompt = f"{prompt}. Style: {hints}"
        for model in (self.image_model, self.fallback_image_model):
            if not model:
                continue
            try:
                resp = requests.post(
                    f"{self.base_url}/images/generations",
                    headers=headers, json={"model": model, "prompt": full_prompt, "n": 1},
                    timeout=60,
                )
                if resp.status_code == 200:
                    items = (resp.json().get("data") or [])
                    if items and items[0].get("url"):
                        return items[0]["url"]
                else:
                    logger.warning(f"OpenRouter {model} → {resp.status_code}: {resp.text[:200]}")
            except Exception as e:
                logger.warning(f"Excepción con {model}: {e}")
        return None

    # ---- Public API ----
    def generate_design(self, prompt: str, style_preferences: Optional[Dict[str, Any]] = None,
                        lead_id: Optional[int] = None) -> Dict[str, Any]:
        style_json = json.dumps(style_preferences) if style_preferences else None
        with self._conn() as c, c.cursor() as cur:
            cur.execute(
                "INSERT INTO design_jobs (lead_id, type, status, prompt, style_preferences, price) "
                "VALUES (%s, 'ai_generated', 'requested', %s, %s::jsonb, %s) RETURNING id",
                (lead_id, prompt, style_json, self.ai_price),
            )
            job_id = cur.fetchone()[0]

        try:
            image_url = self._call_openrouter_images(prompt, style_preferences)
        except Exception as e:
            logger.error(f"Error generando imagen: {e}")
            image_url = None

        if image_url:
            self._exec(
                "UPDATE design_jobs SET status='review', result_url=%s, updated_at=NOW() WHERE id=%s",
                (image_url, job_id),
            )
            return {"success": True, "job_id": job_id, "image_url": image_url,
                    "price": self.ai_price, "status": "review"}

        logger.error("No se pudo generar la imagen. Configurá un modelo de OpenRouter con soporte de imágenes.")
        return {"success": False, "job_id": job_id, "image_url": None,
                "price": self.ai_price, "status": "requested",
                "error": "Image generation not available with the configured OpenRouter models."}

    def create_human_task(self, prompt: str, lead_id: int,
                          designer_id: Optional[int] = None) -> Dict[str, Any]:
        designer = self._pick_designer(designer_id)
        if not designer:
            return {"success": False, "error": "No hay diseñadores activos disponibles."}
        overloaded = designer["current_workload"] >= designer["max_workload"] and not designer_id
        with self._conn() as c, c.cursor() as cur:
            cur.execute(
                "INSERT INTO design_jobs (lead_id, type, status, prompt, designer_id, price) "
                "VALUES (%s, 'human_designer', 'requested', %s, %s, %s) RETURNING id",
                (lead_id, prompt, designer["id"], self.human_price),
            )
            job_id = cur.fetchone()[0]
        self._adjust_workload(designer["id"], +1)
        return {"success": True, "job_id": job_id, "designer_id": designer["id"],
                "designer_name": designer["name"], "price": self.human_price,
                "status": "requested", "warning": "Diseñador en capacidad máxima" if overloaded else None}

    def check_fallback_jobs(self) -> Dict[str, Any]:
        rows = self._fetchall(
            "SELECT id, prompt, style_preferences FROM design_jobs "
            "WHERE type='human_designer' AND status='requested' "
            "AND created_at < NOW() - (%s || ' days')::interval",
            (self.fallback_days,),
        )
        processed = 0
        for job_id, prompt, style_raw in rows:
            style = style_raw if isinstance(style_raw, dict) else _safe_json(style_raw)
            self._exec(
                "UPDATE design_jobs SET status='fallback_ai', fallback_at=NOW(), "
                "updated_at=NOW() WHERE id=%s", (job_id,),
            )
            image_url = self._call_openrouter_images(prompt, style)
            if image_url:
                self._exec(
                    "UPDATE design_jobs SET type='ai_generated', result_url=%s, "
                    "updated_at=NOW() WHERE id=%s", (image_url, job_id),
                )
            processed += 1
        return {"processed": processed}

    def get_job_status(self, job_id: int) -> Optional[Dict[str, Any]]:
        return self._fetchone("SELECT * FROM design_jobs WHERE id = %s", (job_id,))

    def update_job_status(self, job_id: int, status: str,
                          result_url: Optional[str] = None,
                          rejected_reason: Optional[str] = None) -> Dict[str, Any]:
        if status not in VALID_STATUSES:
            return {"success": False, "error": f"Status inválido '{status}'."}
        job = self.get_job_status(job_id)
        if not job:
            return {"success": False, "error": f"Job {job_id} no existe."}
        # Workload: solo se baja cuando un human_designer aprueba o rechaza
        if job.get("type") == "human_designer" and job.get("designer_id") and status in ("approved", "rejected"):
            self._adjust_workload(job["designer_id"], -1)

        fields = {"status": status}
        if result_url is not None:
            fields["result_url"] = result_url
        if rejected_reason is not None:
            fields["rejected_reason"] = rejected_reason
        if status == "approved":
            fields["approved_at"] = "NOW()"

        sets, values = [], []
        for k, v in fields.items():
            sets.append(f"{k} = NOW()" if v == "NOW()" else f"{k} = %s")
            if v != "NOW()":
                values.append(v)
        sets.append("updated_at = NOW()")
        values.append(job_id)
        self._exec(f"UPDATE design_jobs SET {', '.join(sets)} WHERE id = %s", tuple(values))
        return {"success": True, "job_id": job_id, "status": status}


def _safe_json(raw):
    try:
        return json.loads(raw)
    except Exception:
        return None
