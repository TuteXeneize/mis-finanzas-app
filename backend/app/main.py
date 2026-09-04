import os
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.schemas import TransaccionRequest, RespuestaAPI
from app.services import procesar_transaccion_con_ia
from app.investments import router as investments_router

# Cargar variables de entorno desde .env
load_dotenv()

API_SECRET_TOKEN = os.getenv("API_SECRET_TOKEN", "token_secreto_temporal_mvp")
BASE_DIR = Path(__file__).resolve().parent

app = FastAPI(
    title="Finanzas AI Backend",
    version="1.0.0",
    description="Backend oficial para procesamiento NLP y clasificación inteligente de transacciones financieras."
)

# Habilitar CORS para permitir llamadas desde dispositivos móviles, emuladores y navegadores
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Montar carpeta estática
static_dir = BASE_DIR / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/", include_in_schema=False)
def serve_home():
    """Sirve la interfaz web móvil responsiva."""
    index_file = BASE_DIR / "static" / "index.html"
    if index_file.exists():
        return FileResponse(str(index_file))
    return {"message": "Finanzas AI Backend is running. Go to /docs for API documentation."}


def verificar_token(authorization: str = Header(...)):
    """Verifica que la petición incluya el Bearer token correcto."""
    try:
        scheme, token = authorization.split(" ")
        if scheme.lower() != "bearer" or token != API_SECRET_TOKEN:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token de autorización inválido"
            )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Formato de autorización inválido. Usar 'Bearer <token>'"
        )


# Incluir router de inversiones y cotizaciones
app.include_router(investments_router)


@app.get("/health", tags=["Control"])
def health_check():
    """Endpoint de control para verificar que el servidor está activo y respondiendo."""
    return {
        "status": "healthy",
        "service": "finanzas-ai-backend",
        "version": "1.0.0"
    }


@app.post(
    "/procesar-transaccion",
    response_model=RespuestaAPI,
    dependencies=[Depends(verificar_token)],
    tags=["Transacciones"]
)
def procesar_transaccion(payload: TransaccionRequest):
    """
    Recibe el texto del usuario y la lista de categorías activas.
    Procesa la directiva con IA (o parser local inteligente) y devuelve el contrato validado.
    """
    # 1. Validación preliminar de texto vacío
    if not payload.texto or not payload.texto.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El texto no puede estar vacío"
        )

    # 2. Log para debugging en consola
    print(f"\n[NLP Request] Texto: '{payload.texto}'")
    print(f"[NLP Request] Categorías disponibles: {[c.nombre for c in payload.categorias]}")
    print(f"[NLP Request] Fecha actual recibida: {payload.fecha_actual}")

    # 3. Procesamiento estructurado
    resultado = procesar_transaccion_con_ia(payload)
    print(f"[NLP Response] Estado: {resultado.estado} | Data: {resultado.transaccion}\n")

    return resultado
