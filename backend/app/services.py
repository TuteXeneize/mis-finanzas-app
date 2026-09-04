import json
import os
import re
from datetime import datetime, timedelta
from typing import Optional, List
from app.schemas import TransaccionRequest, RespuestaAPI, TransaccionDTO

# Soporte para Google GenAI SDK
try:
    from google import genai
    from google.genai import types
    GEMINI_AVAILABLE = True
except ImportError:
    try:
        import google.generativeai as genai
        GEMINI_AVAILABLE = True
    except ImportError:
        GEMINI_AVAILABLE = False

# Soporte para OpenAI SDK
try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False


SYSTEM_PROMPT = """Eres un asistente financiero experto en procesar lenguaje natural (especialmente modismos argentinos y latinoamericanos) y convertirlo en transacciones financieras estructuradas.

Instrucciones:
1. Analiza el texto del usuario, la fecha actual de referencia ({fecha_actual}) y la lista de categorías disponibles: {categorias_json}.
2. Extrae:
   - monto (número float > 0). Comprende modismos: "15 lucas" = 15000, "1 palo / 1 millón" = 1000000, "20k" = 20000, "3 gambas" = 300.
   - moneda ("ARS", "USD", etc. Por defecto "ARS").
   - descripcion (breve y concisa, exclusivamente el concepto, comercio o producto, ej. "Carne", "Verdulería", "Nafta", "Sueldo", "Luz". NUNCA incluir el monto ni el método de pago dentro de la descripción).
   - tipo ("gasto" o "ingreso"). Si es confuso o es un gasto explícito, clasifícalo como "gasto". Si dice "me pagaron", "cobré", "ingreso", "sueldo", clasifícalo como "ingreso".
   - categoria_id: El ID exacto de la categoría más adecuada de la lista proporcionada. Si ninguna coincide claramente, devuelve null.
   - metodo_pago: Uno de los siguientes: "mercado_pago", "efectivo". Por defecto debe ser SIEMPRE "mercado_pago", a menos que el usuario mencione explícitamente "efectivo", "cash", "billete" o "en mano".
   - fecha: Formato YYYY-MM-DD. Si menciona "ayer", "hoy", "hace 2 días", calcula la fecha exacta respecto a {fecha_actual}.

3. Casos de respuesta:
   - Si se extrae una transacción válida: estado = "ok", transaccion = {monto, moneda, descripcion, tipo, categoria_id, metodo_pago, fecha}.
   - Si parece una intención de registrar pero falta el monto: estado = "requiere_aclaracion", campos_faltantes = ["monto"], mensaje_aclaratorio = "Por favor indica el monto del movimiento.".
   - Si el texto no es una transacción (ej. "hola", "¿cómo estás?", "probando"): estado = "no_transaccion", mensaje_aclaratorio = "No detecté ningún gasto o ingreso en tu mensaje.".

Responde ÚNICAMENTE un objeto JSON válido con la siguiente estructura (sin formato Markdown ni bloques de código extraños):
{{
  "estado": "ok" | "requiere_aclaracion" | "no_transaccion",
  "transaccion": {{
    "monto": float,
    "moneda": "ARS",
    "descripcion": "string",
    "tipo": "gasto" | "ingreso",
    "categoria_id": "string o null",
    "metodo_pago": "string",
    "fecha": "YYYY-MM-DD"
  }} | null,
  "campos_faltantes": ["string"] | null,
  "mensaje_aclaratorio": "string" | null
}}
"""


def _procesar_con_reglas_locales(payload: TransaccionRequest) -> RespuestaAPI:
    """
    Parser determinista inteligente con soporte para modismos argentinos.
    Se utiliza como fallback instantáneo y para pruebas sin necesidad de API keys.
    """
    texto = payload.texto.strip().lower()

    # 1. Detección de no transacción
    saludos = ["hola", "buenas", "chau", "gracias", "test", "ayuda", "ok", "que tal", "cómo estás", "como estas", "que onda"]
    es_saludo_o_charla = any(s in texto for s in saludos) and not any(char.isdigit() for char in texto)
    if es_saludo_o_charla or len(texto) < 3:
        return RespuestaAPI(
            estado="no_transaccion",
            mensaje_aclaratorio="No detecté ningún gasto o ingreso en tu mensaje. Probá algo como: 'Gasté 15 lucas en súper con débito'."
        )

    # 2. Detección de tipo
    palabras_ingreso = ["cobre", "cobré", "sueldo", "ingreso", "recibi", "recibí", "me transfirieron", "deposito", "depósito", "gane", "gané"]
    es_ingreso = any(p in texto for p in palabras_ingreso)
    tipo = "ingreso" if es_ingreso else "gasto"

    # 3. Detección de monto
    monto: Optional[float] = None

    # Patrón "X lucas" o "X luca" (1 luca = 1000)
    match_lucas = re.search(r'(\d+(?:[.,]\d+)?)\s*(?:lucas?|lukas?)', texto)
    if match_lucas:
        val = float(match_lucas.group(1).replace(',', '.'))
        monto = val * 1000.0

    # Patrón "X k" (1k = 1000)
    if monto is None:
        match_k = re.search(r'(\d+(?:[.,]\d+)?)\s*k\b', texto)
        if match_k:
            val = float(match_k.group(1).replace(',', '.'))
            monto = val * 1000.0

    # Patrón "X palos" o "X palo / millón / millones"
    if monto is None:
        match_palos = re.search(r'(\d+(?:[.,]\d+)?)\s*(?:palos?|millones?|millon|millón)', texto)
        if match_palos:
            val = float(match_palos.group(1).replace(',', '.'))
            monto = val * 1000000.0

    # Patrón número estándar (ej: 1500, 1253, 15000, 15.000, $5000)
    if monto is None:
        # 1. Separador de miles con punto (ej: 15.000 o 15.000,50)
        m1 = re.search(r'[$]?\s*(\d{1,3}(?:\.\d{3})+(?:,\d+)?)', texto)
        if m1:
            monto = float(m1.group(1).replace('.', '').replace(',', '.'))
        else:
            # 2. Separador de miles con coma (ej: 15,000 o 15,000.50)
            m2 = re.search(r'[$]?\s*(\d{1,3}(?:,\d{3})+(?:\.\d+)?)', texto)
            if m2:
                monto = float(m2.group(1).replace(',', ''))
            else:
                # 3. Número entero o decimal estándar (ej: 1500, 1253, 15000, 150.50)
                m3 = re.search(r'[$]?\s*(\d+(?:[.,]\d+)?)', texto)
                if m3:
                    monto = float(m3.group(1).replace(',', '.'))

    # Si no tiene monto, verificar si al menos tenía intención de transacción
    if monto is None or monto <= 0:
        palabras_intencion = ["gast", "pagu", "compr", "cobr", "ingres", "transfer", "plata", "pesos", "dolares", "dólares", "factura", "ticket"]
        if any(p in texto for p in palabras_intencion):
            return RespuestaAPI(
                estado="requiere_aclaracion",
                campos_faltantes=["monto"],
                mensaje_aclaratorio="Entendí la intención pero no pude identificar el monto. ¿Cuánto gastaste o ingresaste?"
            )
        return RespuestaAPI(
            estado="no_transaccion",
            mensaje_aclaratorio="No identifiqué un gasto o ingreso claro. Intentá indicar el monto y qué compraste o cobraste."
        )

    # 4. Detección de método de pago (por defecto mercado_pago, solo efectivo si se menciona)
    palabras_efectivo = ["efectivo", "cash", "billete", "billetes", "en mano", "plata en mano"]
    if any(p in texto for p in palabras_efectivo):
        metodo_pago = "efectivo"
    else:
        metodo_pago = "mercado_pago"

    # 5. Detección de fecha
    fecha_base = payload.fecha_actual.split("T")[0]
    fecha_transaccion = fecha_base
    try:
        dt_base = datetime.fromisoformat(payload.fecha_actual.replace("Z", "+00:00"))
        if "ayer" in texto:
            fecha_transaccion = (dt_base - timedelta(days=1)).strftime("%Y-%m-%d")
        elif "anteayer" in texto or "antes de ayer" in texto:
            fecha_transaccion = (dt_base - timedelta(days=2)).strftime("%Y-%m-%d")
        else:
            fecha_transaccion = dt_base.strftime("%Y-%m-%d")
    except Exception:
        fecha_transaccion = fecha_base

    # 6. Detección de categoría
    categoria_id: Optional[str] = None
    for cat in payload.categorias:
        nombre_cat = cat.nombre.lower()
        if nombre_cat in texto:
            categoria_id = cat.id
            break

    if categoria_id is None:
        keywords_cat = {
            "comida": ["carne", "asado", "pollo", "pescado", "milanesa", "milanesas", "hamburguesa", "hamburguesas", "pizza", "empanadas", "comida", "almuerzo", "cena", "desayuno", "merienda", "restaurante", "resto", "bar", "helado", "cafe", "café", "verduleria", "verdulería", "carniceria", "carnicería", "panaderia", "panadería"],
            "super": ["super", "súper", "coto", "dia", "carrefour", "vea", "chango", "almacen", "almacén", "chino", "kiosco", "fruteria", "frutería"],
            "servicios": ["luz", "gas", "agua", "internet", "fibertel", "edenor", "edesur", "metrogas", "telecentro", "personal", "flow", "impuesto", "patente", "abl", "expensas", "alquiler"],
            "transporte": ["uber", "cabify", "didi", "nafta", "ypf", "shell", "axion", "sube", "colectivo", "peaje", "estacionamiento", "remis"],
            "sueldo": ["sueldo", "salario", "honorarios", "quincena", "aguinaldo"],
            "salud": ["farmacia", "remedio", "remedios", "medico", "médico", "dentista", "osde", "swiss"],
            "ocio": ["cine", "teatro", "boliche", "salida", "juego", "steam", "playstation", "recital"]
        }
        for cat in payload.categorias:
            nom = cat.nombre.lower()
            for key, kws in keywords_cat.items():
                if (key in nom or nom in key) and any(kw in texto for kw in kws):
                    categoria_id = cat.id
                    break
            if categoria_id:
                break

    if categoria_id is None and payload.categorias and len(payload.categorias) == 1:
        categoria_id = payload.categorias[0].id

    # 7. Construcción de descripción limpia y concisa (ej: "Carne", "Nafta", "Verdulería")
    desc = payload.texto.strip()
    # a. Quitar menciones temporales (ayer, hoy, anoche, etc.)
    desc = re.sub(r'\b(ayer|hoy|anteayer|anoche|esta mañana|esta tarde|este mediodia)\b', '', desc, flags=re.IGNORECASE).strip()
    # b. Quitar verbos de acción
    desc = re.sub(r'^\s*(gast[eé]|pagu[eé]|compr[eé]|cobr[eé]|ingres[eé]|transfer[ií]|mand[eé]|recib[ií])\s+', '', desc, flags=re.IGNORECASE).strip()
    # c. Quitar método de pago explícito
    desc = re.sub(r'\b(con|en|por)\s+(el\s+|la\s+)?(efectivo|debito|débito|credito|crédito|mercado pago|mercadopago|mp|transferencia|cash|en mano)\b', '', desc, flags=re.IGNORECASE)
    desc = re.sub(r'\b(efectivo|debito|débito|credito|crédito|mercado pago|mercadopago|mp|transferencia|cash|en mano)\b', '', desc, flags=re.IGNORECASE)
    # d. Quitar montos, multiplicadores y monedas
    desc = re.sub(r'\b\d+(?:[.,]\d+)?\s*(?:lucas?|lukas?|palos?|millones?|millon|millón|mil|k)\b', '', desc, flags=re.IGNORECASE)
    desc = re.sub(r'[$]?\s*\b\d{1,3}(?:[.]\d{3})+(?:,\d+)?\b', '', desc)
    desc = re.sub(r'[$]?\s*\b\d{1,3}(?:,\d{3})+(?:\.\d+)?\b', '', desc)
    desc = re.sub(r'[$]?\s*\b\d+(?:[.,]\d+)?\b', '', desc)
    desc = re.sub(r'[$]', '', desc)
    desc = re.sub(r'\b(pesos|dolares|dólares|lucas?|lukas?|palos?|millones?|millon|millón|mil|ars|usd)\b', '', desc, flags=re.IGNORECASE)
    # e. Quitar conectores iniciales comunes
    desc = re.sub(r'^\s*(en\s+(la\s+|el\s+|los\s+|las\s+)?|de\s+(la\s+|el\s+|los\s+|las\s+)?|del\s+|al\s+|para\s+(la\s+|el\s+|los\s+|las\s+)?|por\s+(la\s+|el\s+|los\s+|las\s+)?|el\s+|la\s+|los\s+|las\s+|un\s+|una\s+|unos\s+|unas\s+)', '', desc, flags=re.IGNORECASE).strip()
    # f. Limpiar espacios y signos sobrantes
    desc = re.sub(r'\s+', ' ', desc).strip(' .,-:')

    if not desc or len(desc) <= 1:
        desc = "Gasto" if tipo == "gasto" else "Ingreso"

    desc_limpia = desc[:1].upper() + desc[1:]

    return RespuestaAPI(
        estado="ok",
        transaccion=TransaccionDTO(
            monto=monto,
            moneda="ARS",
            descripcion=desc_limpia,
            tipo=tipo,
            categoria_id=categoria_id,
            metodo_pago=metodo_pago,
            fecha=fecha_transaccion
        )
    )


def procesar_transaccion_con_ia(payload: TransaccionRequest) -> RespuestaAPI:
    """
    Función orquestadora que procesa la transacción utilizando el LLM configurado
    (Google Gemini Free Tier o OpenAI), con fallback automático al parser local.
    """
    gemini_key = os.getenv("GEMINI_API_KEY")
    openai_key = os.getenv("OPENAI_API_KEY")

    # 1. Opción Gemini (Google AI Studio Free Tier)
    if gemini_key and GEMINI_AVAILABLE:
        try:
            cats_json = json.dumps([{"id": c.id, "nombre": c.nombre} for c in payload.categorias], ensure_ascii=False)
            prompt = SYSTEM_PROMPT.format(
                fecha_actual=payload.fecha_actual,
                categorias_json=cats_json
            ) + f"\n\nTexto del usuario: \"{payload.texto}\""

            if hasattr(genai, 'Client'):
                client = genai.Client(api_key=gemini_key)
                model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json"
                    )
                )
                data = json.loads(response.text)
                return RespuestaAPI(**data)
            elif hasattr(genai, 'GenerativeModel'):
                genai.configure(api_key=gemini_key)
                model_name = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
                model = genai.GenerativeModel(
                    model_name=model_name,
                    generation_config={"response_mime_type": "application/json"}
                )
                response = model.generate_content(prompt)
                data = json.loads(response.text)
                return RespuestaAPI(**data)
        except Exception as e:
            print(f"[Warning] Error llamando a Gemini API: {e}. Usando parser determinista local.")

    # 2. Opción OpenAI
    if openai_key and OPENAI_AVAILABLE:
        try:
            client = OpenAI(api_key=openai_key)
            cats_json = json.dumps([{"id": c.id, "nombre": c.nombre} for c in payload.categorias], ensure_ascii=False)
            prompt = SYSTEM_PROMPT.format(
                fecha_actual=payload.fecha_actual,
                categorias_json=cats_json
            )

            response = client.chat.completions.create(
                model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": payload.texto}
                ],
                response_format={"type": "json_object"},
                temperature=0.1
            )
            data = json.loads(response.choices[0].message.content)
            return RespuestaAPI(**data)
        except Exception as e:
            print(f"[Warning] Error llamando a OpenAI API: {e}. Usando parser determinista local.")

    # 3. Fallback inteligente determinista local
    return _procesar_con_reglas_locales(payload)
