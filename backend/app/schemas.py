from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date


class CategoriaInput(BaseModel):
    """Estructura de categoría enviada por el cliente iOS."""
    id: str
    nombre: str


class TransaccionRequest(BaseModel):
    """Payload recibido desde el cliente con el texto natural a procesar."""
    texto: str = Field(..., min_length=1, description="Texto libre ingresado por el usuario")
    fecha_actual: str = Field(..., description="Fecha y hora actual en el dispositivo (ISO 8601)")
    timezone: str = Field(default="America/Argentina/Buenos_Aires", description="Zona horaria del usuario")
    categorias: List[CategoriaInput] = Field(default_factory=list, description="Lista de categorías activas del usuario")


class TransaccionDTO(BaseModel):
    """Contrato de datos de la transacción validada y limpia para iOS."""
    monto: float = Field(..., gt=0, description="El monto debe ser estrictamente positivo")
    moneda: str = Field(default="ARS", description="Moneda de la transacción (ej. ARS, USD)")
    descripcion: str = Field(..., description="Descripción breve y concisa del movimiento")
    tipo: str = Field(..., pattern="^(gasto|ingreso)$", description="Tipo de movimiento: gasto o ingreso")
    categoria_id: Optional[str] = Field(default=None, description="ID de la categoría elegida entre las disponibles")
    metodo_pago: str = Field(
        default="no_especificado",
        description="Método de pago (efectivo, debito, credito, mercado_pago, transferencia, no_especificado)"
    )
    fecha: str = Field(..., description="Fecha de la transacción en formato YYYY-MM-DD")


class RespuestaAPI(BaseModel):
    """Respuesta unificada devuelta al cliente iOS."""
    estado: str = Field(
        ...,
        pattern="^(ok|requiere_aclaracion|no_transaccion)$",
        description="Estado del procesamiento: ok, requiere_aclaracion o no_transaccion"
    )
    transaccion: Optional[TransaccionDTO] = Field(
        default=None,
        description="Transacción estructurada cuando el estado es 'ok'"
    )
    campos_faltantes: Optional[List[str]] = Field(
        default=None,
        description="Lista de campos necesarios si requiere aclaración (ej. ['monto', 'tipo'])"
    )
    mensaje_aclaratorio: Optional[str] = Field(
        default=None,
        description="Mensaje amigable para el usuario si faltan datos o no es una transacción válida"
    )
