import sqlite3
from datetime import datetime
from typing import Optional, Dict, Any, List
from app.core.config import settings
from app.repositories.base import BaseMessageLogRepository, BaseTransactionRepository

class SQLiteDatabaseManager:
    """Administrador singleton de la conexión y esquemas de SQLite."""
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(SQLiteDatabaseManager, cls).__new__(cls)
            cls._instance._init_db()
        return cls._instance

    def _init_db(self):
        db_path = settings.SQLITE_DB_PATH
        with sqlite3.connect(db_path) as conn:
            cursor = conn.cursor()
            # 1. Tabla de Idempotencia y Logs de Mensajes
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS message_log (
                    message_id TEXT PRIMARY KEY,
                    sender_id TEXT NOT NULL,
                    received_at TEXT NOT NULL,
                    status TEXT NOT NULL,
                    error TEXT,
                    transaction_id TEXT
                )
            """)
            # 2. Tabla de Transacciones para Sincronización con iOS
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS transacciones_sync (
                    transaction_id TEXT PRIMARY KEY,
                    whatsapp_message_id TEXT,
                    fecha_transaccion TEXT NOT NULL,
                    fecha_procesamiento TEXT NOT NULL,
                    monto REAL NOT NULL,
                    moneda TEXT NOT NULL,
                    descripcion TEXT NOT NULL,
                    categoria_id TEXT,
                    categoria_nombre TEXT,
                    metodo_pago TEXT NOT NULL,
                    tipo TEXT NOT NULL,
                    sincronizado_ios INTEGER DEFAULT 0,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
            """)
            conn.commit()

    def get_connection(self):
        conn = sqlite3.connect(settings.SQLITE_DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn


class SQLiteMessageLogRepository(BaseMessageLogRepository):
    def __init__(self):
        self.manager = SQLiteDatabaseManager()

    def get_message(self, message_id: str) -> Optional[Dict[str, Any]]:
        with self.manager.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM message_log WHERE message_id = ?", (message_id,))
            row = cursor.fetchone()
            if row:
                return dict(row)
            return None

    def create_message(self, message_id: str, sender_id: str, status: str) -> None:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self.manager.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT OR IGNORE INTO message_log (message_id, sender_id, received_at, status, error, transaction_id)
                VALUES (?, ?, ?, ?, '', '')
                """,
                (message_id, sender_id, now, status)
            )
            conn.commit()

    def update_status(self, message_id: str, status: str, error: str = "", transaction_id: str = "") -> None:
        with self.manager.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                UPDATE message_log
                SET status = ?, error = ?, transaction_id = ?
                WHERE message_id = ?
                """,
                (status, error, transaction_id, message_id)
            )
            conn.commit()


class SQLiteTransactionRepository(BaseTransactionRepository):
    def __init__(self):
        self.manager = SQLiteDatabaseManager()

    def create_transaction(self, tx: Dict[str, Any]) -> None:
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self.manager.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO transacciones_sync (
                    transaction_id, whatsapp_message_id, fecha_transaccion, fecha_procesamiento,
                    monto, moneda, descripcion, categoria_id, categoria_nombre, metodo_pago,
                    tipo, sincronizado_ios, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
                """,
                (
                    tx["transaction_id"],
                    tx.get("whatsapp_message_id", ""),
                    tx["fecha_transaccion"],
                    now,
                    float(tx["monto"]),
                    tx.get("moneda", "ARS"),
                    tx["descripcion"],
                    tx.get("categoria_id"),
                    tx.get("categoria_nombre", "General"),
                    tx.get("metodo_pago", "mercado_pago"),
                    tx.get("tipo", "gasto"),
                    now,
                    now
                )
            )
            conn.commit()

    def get_pending_transactions(self) -> List[Dict[str, Any]]:
        with self.manager.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM transacciones_sync WHERE sincronizado_ios = 0 ORDER BY fecha_transaccion ASC")
            rows = cursor.fetchall()
            return [dict(r) for r in rows]

    def mark_as_synchronized(self, transaction_ids: List[str]) -> int:
        if not transaction_ids:
            return 0
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with self.manager.get_connection() as conn:
            cursor = conn.cursor()
            placeholders = ",".join("?" for _ in transaction_ids)
            query = f"UPDATE transacciones_sync SET sincronizado_ios = 1, updated_at = ? WHERE transaction_id IN ({placeholders})"
            cursor.execute(query, [now] + transaction_ids)
            conn.commit()
            return cursor.rowcount
