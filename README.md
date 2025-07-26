Remote Device Monitor
Una aplicación cliente simple para recolectar y enviar datos de un dispositivo a un sistema de monitoreo remoto.

📝 Descripción
Remote Device Monitor es una aplicación diseñada para actuar como un agente de recolección de datos en un dispositivo específico. Su propósito principal es conectarse a un servicio de backend, autenticarse y enviar métricas o información relevante para su monitoreo en tiempo real.

La aplicación presenta una interfaz minimalista para que el usuario pueda iniciar y detener el proceso de recolección de datos de manera sencilla y directa.

✨ Características Principales
Interfaz Sencilla: Toda la funcionalidad se concentra en una sola pantalla para una máxima facilidad de uso.

Control de Recolección: Permite al usuario iniciar y detener el envío de datos con un solo toque.

Autenticación Segura: Utiliza un Token de API para asegurar que solo los dispositivos autorizados puedan enviar datos al sistema central.

Identificación Única: Asigna un ID de Dispositivo único para diferenciar cada cliente en el sistema de monitoreo.

🚀 Uso
La aplicación está diseñada para ser intuitiva:

Iniciar la Aplicación: Al abrirla, la pantalla principal mostrará la información de identificación del dispositivo.

ID Dispositivo: Identificador único del agente.

Token API: Clave de acceso para la comunicación con el servidor.

Iniciar Monitoreo: Presiona el botón ▶️ Iniciar Recolección para que el dispositivo comience a capturar y enviar datos al servidor.

Detener Monitoreo: Presiona el botón ⏹️ Detener Recolección para pausar o finalizar el envío de datos.

🛠️ Configuración
La aplicación está preconfigurada para mostrar el ID del Dispositivo y el Token API necesarios para la conexión con el backend. Esta información es fundamental para registrar y autenticar el dispositivo en el sistema de monitoreo central.

Nota: La etiqueta DEBUG visible en la captura indica que esta es una versión de desarrollo. Las credenciales y la funcionalidad podrían variar en la versión de producción.