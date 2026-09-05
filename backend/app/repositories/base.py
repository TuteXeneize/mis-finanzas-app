from abc import ABC, abstractmethod
from typing import Optional, Dict, Any, List

class BaseMessageLogRepository(ABC):
    @abstractmethod
    def get_message(self, message_id: str) -> Optional[Dict[str, Any]]:
        """Busca un mensaje por su ID para verificar idempotencia."""
        pass

    @abstractmethod
    def create_message(self, message_id: str, sender_id: str, status: str) -> None:
        """Registra la recepción inicial de un mensaje."""
        pass

    @abstractmethod
    def update_status(self, message_id: str, status: str, error: str = "", transaction_id: str = "") -> None:
        """Actualiza el estado de procesamiento (PROCESSED o FAILED)."""
        pass


class BaseTransactionRepository(ABC):
    @abstractmethod
    def create_transaction(self, transaccion: Dict[str, Any]) -> None:
        """Inserta una transacción generada por WhatsApp en el repositorio."""
        pass

    @abstractmethod
    def get_pending_transactions(self) -> List[Dict[str, Any]]:
        """Retorna todas las transacciones donde 'sincronizado_ios' sea False."""
        pass

    @abstractmethod
    def mark_as_synchronized(self, transaction_ids: List[str]) -> int:
        """Marca 'sincronizado_ios' como True para los IDs recibidos en el ACK."""
        pass
