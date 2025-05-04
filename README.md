# 🌱 Insofarma

**Sistema integral de riego automatizado con Flutter, Arduino, Firebase y Spring Boot**

---

## 🧠 Descripción

Insofarma es una solución IoT desarrollada por Insoftech para la automatización del riego en invernaderos inteligentes. Permite el control preciso de humedad ambiental y de suelo en múltiples macetas, utilizando sensores DHT11 y YL69, junto con un sistema de notificaciones y control en tiempo real mediante una aplicación Flutter.

---

## 📦 Tecnologías utilizadas

- ⚙️ **Arduino UNO R4 WiFi** – Sensores y control de riego  
- 📲 **Flutter** – Aplicación móvil para configuración y monitoreo  
- ☁️ **Firebase Realtime Database** – Almacenamiento de datos y configuración  
- 🧪 **Spring Boot** – Backend REST para comunicación con Arduino y app  
- 📡 **RabbitMQ (opcional)** – Intermediación entre servicios (modo distribuido)  

---

## 🔧 Estructura del repositorio

```
insofarma/
│
├── arduino/                     # Código del Arduino UNO R4 WiFi
├── sistema_riego_invernadero/  # App Flutter
├── control-riego/              # Backend en Spring Boot
├── rabbitmq/                   # Integración de mensajería
├── README.md
├── LICENSE
└── .gitignore
```

---

## 🚀 Funcionalidades principales

- Registro de humedad en tiempo real por maceta  
- Configuración de riego por horarios o de forma manual  
- Umbrales personalizados de riego por planta  
- Alertas visuales y por notificación en caso de fallos  
- Conexión WiFi del Arduino configurable desde la app  

---

## 🧑‍💼 Autores

Desarrollado por [MAXEL599](https://github.com/MAXEL599) y la empresa **Insoftech**  
🔒 Derechos reservados – Licencia Apache 2.0

---

## 📜 Licencia

Este proyecto está licenciado bajo los términos de la [Apache License 2.0](LICENSE).
