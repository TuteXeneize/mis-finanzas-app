# 📱 FinanzasApp (iOS 17+ / SwiftUI / SwiftData / Swift Charts)

Aplicación nativa de finanzas personales diseñada bajo los principios de **Offline-First**, **Precisión Decimal Estricta** y **Procesamiento Inteligente con IA**.

---

## 🏛️ Arquitectura del Proyecto

```plaintext
ios/FinanzasApp/
├── App/
│   └── FinanzasApp.swift        # Entry point y ModelContainer con auto-seed de categorías
├── Models/
│   ├── Enums.swift              # TipoTransaccion, MetodoPago, EstadoRespuestaAPI
│   ├── CategoriaUsuario.swift   # Modelo SwiftData (@Model) con soporte para baja lógica (activa: Bool)
│   └── Transaccion.swift        # Modelo SwiftData (@Model) con montos en Decimal y UUID desacoplado
├── Services/
│   ├── DTOs.swift               # Estructuras Codable para comunicación HTTP
│   └── IAService.swift          # Cliente de red asíncrono con autenticación Bearer y manejo de errores
├── Helpers/
│   └── Formatters.swift         # Formateo monetario seguro y parseo de fechas
└── Views/
    ├── MainTabView.swift        # Contenedor principal con pestañas
    ├── DashboardView.swift      # Balance, tarjetas de ingresos/gastos, historial e input de IA
    ├── NuevaTransaccionView.swift# Formulario manual offline con validación y #Predicate de categorías activas
    ├── GestorCategoriasView.swift# CRUD de categorías con edición inline (@Bindable) y baja lógica
    ├── EstadisticasView.swift   # Gráfico de Dona con Swift Charts (SectorMark) y sumas deterministas
    └── ConfiguracionView.swift  # Ajustes de URL del servidor y botón de prueba de conexión
```

---

## 🚀 Cómo abrir y correr la app en Xcode

1. Abrí **Xcode** en tu Mac.
2. Seleccioná **"Create New Project"** -> **iOS App** -> Nombre: `FinanzasApp` (usar SwiftUI y SwiftData).
3. Arrastrá la carpeta de archivos creados dentro de tu proyecto en Xcode.
4. Para correr en tu **iPhone físico gratis**:
   - Conectá tu iPhone por cable o en la misma red Wi-Fi.
   - En Xcode, seleccioná el target `FinanzasApp` -> pestaña **"Signing & Capabilities"**.
   - En **"Team"**, iniciá sesión con tu **Apple ID gratuito** (*Personal Team*).
   - Seleccioná tu iPhone en la barra superior de dispositivos y dale a **Run (Cmd + R)**.
5. En tu iPhone, si es la primera vez, andá a **Ajustes > General > VPN y gestión de dispositivos** y dale a *"Confiar en la app"*.
