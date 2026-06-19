import os
import logging
import requests
from typing import Dict, Any, List, Optional

logger = logging.getLogger("hermes.skills.ai_engine")

class AIEngineSkill:
    """Skill para interactuar con la API de OpenRouter para la optimización cognitiva de campañas"""

    def __init__(self):
        self.api_key = os.getenv("OPENROUTER_API_KEY")
        self.gemini_key = os.getenv("GEMINI_API_KEY")
        self.base_url = "https://openrouter.ai/api/v1"
        self.default_model = "google/gemini-2.5-flash"  # Modelo rápido, económico y excelente para estructuración

        if not self.api_key:
            logger.warning("OPENROUTER_API_KEY no está configurada en las variables de entorno.")
        if not self.gemini_key:
            logger.warning("GEMINI_API_KEY no está configurada en las variables de entorno.")

    def _call_openrouter(self, messages: List[Dict[str, str]], json_mode: bool = False) -> str:
        """Llamada interna a la API de OpenRouter"""
        if not self.api_key:
            logger.error("Intento de llamada a OpenRouter sin API Key configurada.")
            raise ValueError("OPENROUTER_API_KEY no configurada.")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://adsvnzla.admetricas.com",
            "X-Title": "Hermes Ads Agent"
        }

        payload = {
            "model": self.default_model,
            "messages": messages,
            "temperature": 0.3
        }

        if json_mode:
            payload["response_format"] = {"type": "json_object"}

        try:
            url = f"{self.base_url}/chat/completions"
            logger.info(f"Enviando petición a OpenRouter ({self.default_model})...")
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            if response.status_code != 200:
                logger.error(f"Error de OpenRouter (Status {response.status_code}): {response.text}")
            response.raise_for_status()
            
            result = response.json()
            choices = result.get("choices", [])
            if not choices:
                logger.error(f"Respuesta vacía de OpenRouter: {result}")
                raise ValueError("Respuesta de modelo vacía")
                
            return choices[0]["message"]["content"].strip()

        except Exception as e:
            logger.error(f"Error al llamar a OpenRouter: {str(e)}")
            raise e

    def _call_openrouter_multimodal(self, prompt: str, base64_data: str, mime_type: str, json_mode: bool = False) -> str:
        """Llamada multimodal a OpenRouter enviando texto y un archivo en base64 (imagen, audio, etc.)"""
        if not self.api_key:
            logger.error("Intento de llamada a OpenRouter sin API Key configurada.")
            raise ValueError("OPENROUTER_API_KEY no configurada.")

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://adsvnzla.admetricas.com",
            "X-Title": "Hermes Ads Agent"
        }

        # Estructura compatible con OpenRouter Multimodal (data URI)
        payload = {
            "model": self.default_model,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": prompt
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64_data}"
                            }
                        }
                    ]
                }
            ],
            "temperature": 0.3
        }

        if json_mode:
            payload["response_format"] = {"type": "json_object"}

        try:
            url = f"{self.base_url}/chat/completions"
            logger.info(f"Enviando petición multimodal a OpenRouter ({self.default_model})...")
            response = requests.post(url, headers=headers, json=payload, timeout=30)
            
            if response.status_code != 200:
                logger.error(f"Error de OpenRouter Multimodal (Status {response.status_code}): {response.text}")
                response.raise_for_status()
                
            result = response.json()
            choices = result.get("choices", [])
            if not choices:
                logger.error(f"Respuesta vacía de OpenRouter Multimodal: {result}")
                raise ValueError("Respuesta de modelo vacía")
                
            return choices[0]["message"]["content"].strip()
        except Exception as e:
            logger.error(f"Error en llamada multimodal a OpenRouter: {str(e)}")
            raise e

    def transcribe_audio_url(self, audio_url: str, auth_header: str = None) -> str:
        """Descarga una nota de voz y la transcribe usando la API de OpenRouter con Gemini"""
        try:
            logger.info(f"Descargando nota de voz desde: {audio_url}")
            headers = {}
            if auth_header:
                headers["Authorization"] = auth_header
                logger.info("Usando auth_header para descarga (WhatsApp Cloud API)")
            response = requests.get(audio_url, headers=headers, timeout=20)
            response.raise_for_status()
            
            audio_bytes = response.content
            import base64
            base64_audio = base64.b64encode(audio_bytes).decode("utf-8")
            
            # Detectar MIME type
            mime_type = response.headers.get("Content-Type", "audio/mp4")
            if "octet-stream" in mime_type:
                mime_type = "audio/mp4" # fallback estándar para audios de IG
                
            prompt = (
                "Por favor, transcribe esta nota de voz en español venezolano con precisión palabra por palabra. "
                "No agregues explicaciones, comentarios, notas o introducciones; devuelve ÚNICAMENTE la transcripción del audio. "
                "Si el audio está completamente en silencio o es ilegible, devuelve un string vacío."
            )
            
            transcription = self._call_openrouter_multimodal(
                prompt=prompt,
                base64_data=base64_audio,
                mime_type=mime_type
            )
            
            logger.info(f"Transcripción exitosa: '{transcription}'")
            return transcription
            
        except Exception as e:
            logger.error(f"Error al transcribir audio con OpenRouter: {str(e)}")
            return f"[Error en transcripción de voz: {str(e)}]"

    def _download_or_parse_image(self, image_url: str, auth_header: str = None) -> tuple[str, str]:
        """
        Descarga una imagen desde una URL o la procesa si ya viene codificada en un Data URI.
        Retorna (base64_image, mime_type).
        """
        import base64
        if image_url.startswith("data:"):
            logger.info("Procesando imagen local desde Data URI...")
            # Formato: data:image/png;base64,iVBORw0KGgo...
            header, base64_data = image_url.split(",", 1)
            mime_type = header.split(";")[0].split(":")[1]
            return base64_data, mime_type
        
        logger.info(f"Descargando imagen remota desde: {image_url}")
        headers = {}
        if auth_header:
            headers["Authorization"] = auth_header
            logger.info("Usando auth_header para descargar imagen")
        response = requests.get(image_url, headers=headers, timeout=20)
        response.raise_for_status()
        
        image_bytes = response.content
        base64_image = base64.b64encode(image_bytes).decode("utf-8")
        mime_type = response.headers.get("Content-Type", "image/jpeg")
        if "octet-stream" in mime_type:
            mime_type = "image/jpeg"
        return base64_image, mime_type

    def validate_payment_receipt_url(self, image_url: str, auth_header: str = None) -> Dict[str, Any]:
        """Descarga un comprobante de pago y realiza OCR inteligente usando la API de OpenRouter con Gemini Vision"""
        try:
            base64_image, mime_type = self._download_or_parse_image(image_url, auth_header)
            prompt = (
                "Analizá detenidamente este comprobante de pago móvil o transferencia bancaria en Venezuela.\n"
                "Extraé TODOS los campos visibles y devolvelos estrictamente en formato JSON válido:\n"
                "{\n"
                "  \"is_receipt\": true, // true si es captura de pantalla de un recibo/comprobante de pago, pago móvil, transferencia bancaria legible. false si es otro tipo de imagen.\n"
                "  \"reference\": \"número de referencia o transacción COMPLETO tal cual aparece (puede ser largo, ej: 61619711168) o null\",\n"
                "  \"date\": \"fecha y hora del pago en formato DD/MM/YYYY HH:MM:SS tal cual aparece o null\",\n"
                "  \"sender_account\": \"últimos 4 dígitos de la cuenta origen (ej: ****0453) o null\",\n"
                "  \"sender_bank\": \"nombre completo del banco emisor/origen tal cual aparece o null\",\n"
                "  \"beneficiary_name\": \"nombre completo del beneficiario/destinatario tal cual aparece o null\",\n"
                "  \"beneficiary_account\": \"últimos 4 dígitos de la cuenta destino (ej: ****3602) o null\",\n"
                "  \"beneficiary_bank\": \"nombre del banco destino si es diferente al origen, o null\",\n"
                "  \"amount\": número con decimales extraído sin símbolo Bs ni puntos de miles (ej: 110000.00 para 'Bs 110.000,00') o null,\n"
                "  \"currency\": \"VES\" para bolívares (Bs/BsS/BsF), \"USD\" para dólares, \"USDT\" para tether, o null,\n"
                "  \"concept\": \"texto del concepto/descripción de la operación o null\"\n"
                "}\n\n"
                "Reglas críticas:\n"
                "- Devolvé ÚNICAMENTE el objeto JSON sin formato markdown, sin bloques de código.\n"
                "- El monto en Venezuela usa PUNTO como separador de miles y COMA como decimal. '110.000,00' = 110000.00\n"
                "- Si dice 'Bs' o 'BS' o 'BsS' o 'BsF', la currency es 'VES'.\n"
                "- Extraé la referencia COMPLETA, no la trunces aunque sea larga.\n"
                "- Si los datos no son visibles o legibles, colocá null en los campos correspondientes."
            )
            
            raw_text = self._call_openrouter_multimodal(
                prompt=prompt,
                base64_data=base64_image,
                mime_type=mime_type,
                json_mode=True
            )
            
            logger.info(f"Respuesta OCR recibida de OpenRouter: {raw_text}")
            
            # Limpiar posibles bloques de código markdown
            if raw_text.startswith("```"):
                lines = raw_text.split("\n")
                if lines[0].startswith("```"):
                    lines = lines[1:]
                if lines[-1].startswith("```"):
                    lines = lines[:-1]
                raw_text = "\n".join(lines).strip()
            
            import json
            parsed_data = json.loads(raw_text)

            # Evaluar si la fecha del comprobante es de HOY (zona horaria Venezuela, UTC-4 sin DST)
            from datetime import datetime, timezone, timedelta
            caracas = timezone(timedelta(hours=-4))
            today = datetime.now(caracas).date()
            parsed_data["today_caracas"] = today.isoformat()
            receipt_day = self._parse_receipt_date(parsed_data.get("date"))
            parsed_data["receipt_date"] = receipt_day.isoformat() if receipt_day else None
            parsed_data["is_today"] = bool(receipt_day and receipt_day == today)

            logger.info(f"Comprobante: is_receipt={parsed_data.get('is_receipt')} fecha={parsed_data.get('receipt_date')} hoy={today.isoformat()} is_today={parsed_data['is_today']}")
            return parsed_data
            
        except Exception as e:
            logger.error(f"Error al analizar el comprobante de pago con OpenRouter: {str(e)}")
            return {"is_receipt": False, "error": str(e)}

    @staticmethod
    def _parse_receipt_date(raw):
        """Parsea la fecha del comprobante en varios formatos y devuelve un date (o None)."""
        if not raw:
            return None
        from datetime import datetime
        s = str(raw).strip()
        formatos = (
            "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d",
            "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M", "%d/%m/%Y",
            "%d-%m-%Y %H:%M:%S", "%d-%m-%Y",
            "%d/%m/%Y %I:%M:%S %p", "%d/%m/%Y %I:%M:%S%p",
            "%d/%m/%Y %I:%M %p", "%d/%m/%Y %I:%M%p",
            "%d-%m-%Y %I:%M:%S %p", "%d-%m-%Y %I:%M:%S%p",
        )
        for fmt in formatos:
            try:
                return datetime.strptime(s, fmt).date()
            except ValueError:
                continue
        # Último intento: primeros 10 caracteres como ISO YYYY-MM-DD
        try:
            return datetime.strptime(s[:10], "%Y-%m-%d").date()
        except ValueError:
            return None

    def optimize_creative_copy(self, client_name: str, raw_message: str, plan: str) -> Dict[str, str]:
        """
        Optimizar el copy publicitario usando técnicas de copywriting rioplatense 
        e inyectando persuasión y llamados a la acción claros.
        """
        system_instruction = (
            "Actuás como un redactor publicitario senior y especialista de tráfico pago en Meta Ads para Venezuela.\n"
            "Tu tarea es recibir el mensaje original de un cliente y transformarlo en un copy de anuncio sumamente atractivo, "
            "profesional y persuasivo.\n\n"
            "Reglas clave:\n"
            "1. Adaptá el tono para que sea cálido, empático y natural al estilo Rioplatense ('vos', 'tenés', 'impulsá') sin sobrecargar de modismos vulgares.\n"
            "2. Estructurá el mensaje para facilitar la lectura usando emojis oportunos y saltos de línea estratégicos.\n"
            "3. Incluí un llamado a la acción (CTA) directo y persuasivo para escribir al WhatsApp.\n"
            "4. Devolvé un objeto JSON estrictamente formateado con la estructura: {\"message\": \"texto del anuncio optimizado\"}.\n"
        )

        user_content = (
            f"Cliente: {client_name}\n"
            f"Plan de Ads Vzla: {plan}\n"
            f"Mensaje original: {raw_message}\n"
        )

        messages = [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": user_content}
        ]

        try:
            import json
            response_text = self._call_openrouter(messages, json_mode=True)
            optimized_data = json.loads(response_text)
            return optimized_data
        except Exception as e:
            logger.warning(f"Fallo en la optimización con IA, usando fallback: {str(e)}")
            return {"message": raw_message}

    def describe_image_url(self, image_url: str, auth_header: str = None) -> str:
        """Descarga una imagen y genera una descripción detallada en español para el agente conversacional"""
        try:
            base64_image, mime_type = self._download_or_parse_image(image_url, auth_header)

            prompt = (
                "Describí en español qué hay en esta imagen de forma concisa y útil para un agente de ventas. "
                "Si es un comprobante de pago, mencioná que es un comprobante. "
                "Si es un producto, negocio o local, describilo. "
                "Si es un screenshot, describí qué muestra. "
                "Devolvé SOLO la descripción en 1-3 oraciones, sin formato, sin markdown."
            )

            description = self._call_openrouter_multimodal(
                prompt=prompt,
                base64_data=base64_image,
                mime_type=mime_type
            )

            logger.info(f"Descripción de imagen exitosa: '{description[:100]}...'")
            return description

        except Exception as e:
            logger.error(f"Error al describir imagen con OpenRouter: {str(e)}")
            return f"[No se pudo analizar la imagen: {str(e)}]"

    def recommend_targeting(self, client_name: str, raw_interests: List[str]) -> Dict[str, Any]:
        """
        Analizar la descripción o los intereses entregados y recomendar 
        el set óptimo de targeting para la campaña.
        """
        # En el futuro esta skill se puede enriquecer con mapeos de la API de intereses de Meta.
        # Por ahora actúa como una capa inteligente de validación y enriquecimiento.
        return {
            "countries": ["VE"],
            "age_min": 18,
            "age_max": 65,
            "interests": raw_interests
        }
