import time
import httpx
from typing import Dict, List, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Query

router = APIRouter(prefix="", tags=["Inversiones"])

class CotizacionDTO(BaseModel):
    ticker: str
    nombre: Optional[str] = None
    precio: float
    moneda: str = "USD"
    cambio_porcentual_dia: Optional[float] = None
    ultimo_cierre: Optional[float] = None
    fecha_actualizacion: float

# Memoria caché simple para evitar sobrecargar Yahoo Finance (30 segundos de validez)
CACHE_COTIZACIONES: Dict[str, CotizacionDTO] = {}
CACHE_TTL_SEGUNDOS = 30


def obtener_cotizacion_yahoo(ticker: str) -> Optional[CotizacionDTO]:
    ticker_clean = ticker.strip().upper()
    ahora = time.time()
    
    # Revisar caché
    if ticker_clean in CACHE_COTIZACIONES:
        cached = CACHE_COTIZACIONES[ticker_clean]
        if ahora - cached.fecha_actualizacion < CACHE_TTL_SEGUNDOS:
            return cached
            
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker_clean}"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    try:
        with httpx.Client(timeout=6.0) as client:
            resp = client.get(url, headers=headers)
            if resp.status_code != 200:
                return None
            data = resp.json()
            result = data.get("chart", {}).get("result")
            if not result:
                return None
                
            meta = result[0].get("meta", {})
            precio = meta.get("regularMarketPrice")
            if precio is None:
                return None
                
            ultimo_cierre = meta.get("chartPreviousClose") or meta.get("previousClose")
            cambio_pct = None
            if ultimo_cierre and ultimo_cierre > 0:
                cambio_pct = round(((precio - ultimo_cierre) / ultimo_cierre) * 100.0, 2)
                
            nombre = meta.get("shortName") or meta.get("longName") or ticker_clean
            moneda = meta.get("currency", "USD")
            
            dto = CotizacionDTO(
                ticker=ticker_clean,
                nombre=nombre,
                precio=round(float(precio), 4),
                moneda=moneda,
                cambio_porcentual_dia=cambio_pct,
                ultimo_cierre=round(float(ultimo_cierre), 4) if ultimo_cierre else None,
                fecha_actualizacion=ahora
            )
            CACHE_COTIZACIONES[ticker_clean] = dto
            return dto
    except Exception as e:
        print(f"[Warning] Error consultando cotización para {ticker_clean}: {e}")
        # Si falla pero teníamos en caché vieja, devolverla
        return CACHE_COTIZACIONES.get(ticker_clean)


@router.get("/cotizaciones", response_model=Dict[str, Optional[CotizacionDTO]])
def obtener_cotizaciones(tickers: str = Query(..., description="Tickers separados por coma, ej: AAPL,TSLA,NVDA")):
    """
    Obtiene las cotizaciones en tiempo real del mercado de EE.UU. (NYSE/NASDAQ)
    utilizado por ARQ / DolarApp y Yahoo Finance.
    """
    lista_tickers = [t.strip().upper() for t in tickers.split(",") if t.strip()]
    resultado: Dict[str, Optional[CotizacionDTO]] = {}
    
    for t in lista_tickers:
        resultado[t] = obtener_cotizacion_yahoo(t)
        
    return resultado


@router.get("/cotizacion/{ticker}", response_model=Optional[CotizacionDTO])
def obtener_una_cotizacion(ticker: str):
    """Obtiene la cotización de un ticker individual."""
    return obtener_cotizacion_yahoo(ticker)
