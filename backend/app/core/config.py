import os
from pathlib import Path
from dotenv import load_dotenv

# Cargar .env desde la raíz del proyecto backend
env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

class Settings:
    # Token para verificar el Webhook en el portal de Meta for Developers
    META_VERIFY_TOKEN: str = os.getenv("META_VERIFY_TOKEN", "token_secreto_super_seguro_2026")
    
    # Token de Acceso Permanente generado en Meta Developers / Sistema
    META_ACCESS_TOKEN: str = os.getenv(
        "META_ACCESS_TOKEN", 
        "EAApsPblu44oBSQpHzdxYMokvYqKZBjg3vHiOFJQCqOheURZAntu99nOfsKekukU55KIZAvkzDa2ZAXyqLJBG24jDqaIA07szmHEIPGKZAlyzCMLgQgZCa5a6ydMVSLjvBft6xZCZBrlq4ZA6qFvnarn3NgK5MmzKBoDxNwjoRg3uvRhoqovzMF9Ryl6lFTr8kBhSy3WFdVPxVTELLNOQO3mUcDZB59wuhetEGqVxg3CALN80Wn0lUsD9AB6mxi46wfZAWgqybTqQVM5OgKkPUfhVQUInwZDZD"
    )
    
    # ID del número de teléfono desde el que Meta envía los WhatsApp
    META_PHONE_NUMBER_ID: str = os.getenv("META_PHONE_NUMBER_ID", "1172805419258900")
    
    # Versión de la API de Meta Graph
    META_API_VERSION: str = os.getenv("META_API_VERSION", "v20.0")
    
    # Token de seguridad para la sincronización con iOS
    SYNC_API_TOKEN: str = os.getenv("SYNC_API_TOKEN", "token_ultra_secreto_ios_2026")
    
    # Base de datos SQLite local para persistencia e idempotencia
    SQLITE_DB_PATH: str = os.getenv(
        "SQLITE_DB_PATH",
        str(Path(__file__).resolve().parent.parent.parent / "finanzas_sync.db")
    )

settings = Settings()
