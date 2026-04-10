<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## Lagos Dent API

API para agenda de citas médicas (Laravel 12), con autenticación por tokens (Sanctum), agenda compartida por consultorio y separación de identidades (`people`), pacientes y doctores.

### Push Notifications (Firebase Cloud Messaging)
El backend ya incluye integración base con Firebase Cloud Messaging (FCM) para notificaciones push en Android.

- Autenticación real de la app: `people`, con abilities `patient` y `doctor` en Sanctum.
- Los tokens FCM se guardan por `person_id` en la tabla `device_tokens`.
- Los eventos de citas despachan notificaciones por cola usando `SendAppointmentPushJob`.
- El envío se hace con Firebase Admin SDK vía Kreait.

#### Configuración requerida
1. Descargar la llave privada del proyecto Firebase.
2. Guardarla en `storage/app/private/`.
3. Configurar una de estas variables en `.env`:
	- Opción recomendada:
		```env
		FIREBASE_CREDENTIALS_FILE=lagos-dent-v1-firebase-adminsdk-xxxxx.json
		```
	- O ruta absoluta completa:
		```env
		FIREBASE_CREDENTIALS=C:\Users\PC\Documents\Git\lagos-dent-app\backend\storage\app\private\lagos-dent-v1-firebase-adminsdk-xxxxx.json
		```
4. Limpiar caché de configuración:
	```bash
	php artisan config:clear
	```

Si ejecutas el backend con Docker Compose, la credencial no se lee desde tu `.env` local dentro del contenedor. En ese caso, `app` y `queue` montan el JSON como archivo de solo lectura y usan internamente:

```env
FIREBASE_CREDENTIALS=/var/www/storage/app/private/firebase-admin.json
```

Importante: el `source` del bind mount en `docker-compose.yml` debe coincidir con el nombre real del archivo JSON en `storage/app/private/`.

#### Worker de cola
Las notificaciones de citas no se envían dentro del request HTTP; se encolan en base de datos.

En desarrollo debes dejar corriendo:

```bash
php artisan queue:work
```

En Docker Compose el worker ya corre como servicio separado (`queue`), que es la opción recomendada para producción y staging porque separa el proceso HTTP del proceso de cola.

```bash
docker compose up -d --build
```

Ver logs del worker:

```bash
docker compose logs -f queue
```

Eventos que actualmente generan push:
- Paciente agenda cita: notifica al doctor.
- Doctor agenda cita: notifica al paciente.
- Doctor reprograma: notifica al paciente.
- Doctor confirma: notifica al paciente.
- Doctor rechaza: notifica al paciente.
- Doctor marca ausencia: notifica al paciente.

### Autenticación
Los endpoints protegidos usan `Authorization: Bearer <token>` con abilities de Sanctum.

- Paciente: `POST /api/auth/patients/validate`
	- Body JSON: `{ "phone": "string", "birthdate": "YYYY-MM-DD" }`
	- Respuestas:
		- `200 OK` → `{ "token": "...", "patient_id": "uuid", "person_id": "uuid" }`
		- `404 Not Found` → `{ "message": "Paciente no encontrado" }`
		- `422 Unprocessable Entity` → `{ "message": "Datos inválidos" }`

- Doctor: `POST /api/auth/doctors/validate`
	- Body JSON: `{ "phone": "string", "password": "string" }`
	- Respuestas:
		- `200 OK` → `{ "token": "...", "doctor_id": "uuid", "person_id": "uuid" }`
		- `404 Not Found` → `{ "message": "Doctor no encontrado" }`
		- `403 Forbidden` → `{ "message": "Doctor inactivo" }`
		- `422 Unprocessable Entity` → `{ "message": "Credenciales inválidas" }`

### Referencia de Endpoints

Notas:
- Formatos de fecha de entrada: `scheduled_at` y `new_scheduled_at` aceptan `Y-m-d H:i:s`.
- Fechas en respuestas se entregan en ISO 8601.
- En `AppointmentResource`, `status` se devuelve como objeto: `{ "value": int, "descriptor": string }`.
- Abilities requeridas: "patient" para rutas de paciente, "doctor" para rutas de doctor, o ambas según corresponda.

#### Pacientes
- Registrar paciente: `POST /api/patients` (público)
	- Body JSON:
		```json
		{
			"phone": "string",
			"name": "string",
			"birthdate": "YYYY-MM-DD",
			"titular_patient_id": "uuid (opcional)"
		}
		```
	- Respuestas:
		- `201 Created` →
			```json
			{
				"id": "uuid",
				"name": "string",
				"phone": "string",
				"birthdate": "YYYY-MM-DD"
			}
			```
		- `422 Unprocessable Entity` → `{ "message": "El número de celular ya está registrado.", "errors": { "phone": ["El número de celular ya está registrado."] } }`

- Ver paciente: `GET /api/patients/{id}` (token con ability "patient")
	- `200 OK` → igual al recurso de arriba
	- `404 Not Found` si no existe

- Alergias: `GET /api/patients/{id}/allergies` (ability "patient")
	- `200 OK` → `[{ "id": "uuid", "name": "string", ... }]`

- Diagnósticos: `GET /api/patients/{id}/diagnoses` (ability "patient")
	- `200 OK` →
		```json
		[
			{
				"id": "uuid",
				"description": "string",
				"doctor": { "id": "uuid", "name": "string" },
				"created_at": "ISO-8601"
			}
		]
		```

- Citas del paciente: `GET /api/patients/{id}/appointments?order=desc|asc` (ability "patient")
	- `200 OK` → lista de `AppointmentResource`

- Asociados del titular: `GET /api/patients/{id}/associates` (ability "patient")
	- `200 OK` → lista de `PatientResource`
	- Notas: `id` es el `titular_patient_id`

- Buscar pacientes por nombre: `GET /api/patients/search?name=<texto>&limit=7` (ability "doctor")
	- Query:
		- `name` (requerido) texto a buscar en `person.name`
		- `limit` (opcional) máx `7` (por defecto `7`)
	- `200 OK` → lista de `PatientResource`

- Registrar alergia (doctor): `POST /api/patients/{id}/allergies` (ability "doctor")
	- Body JSON:
		```json
		{ "name": "string", "severity": "string (opcional)", "notes": "string (opcional)" }
		```
	- Respuestas:
		- `201 Created` → `{ "id": "uuid", "patient_id": "uuid", "name": "string", "severity": "string|null", "notes": "string|null" }`

#### Citas
- Detalle de cita: `GET /api/appointments/{id}` (abilities "patient" o "doctor")
	- `200 OK` →
		```json
		{
			"id": "uuid",
			"scheduled_at": "ISO-8601",
			"status": {
				"value": 1,
				"descriptor": "Por confirmar"
			},
			"doctor": { "id": "uuid", "name": "string" },
			"patient": { "id": "uuid", "name": "string" },
			"diagnosis": "string|null",
			"deposit_slip_attachment_id": "uuid|null",
			"deposit_slip_attachment": {
				"id": "uuid",
				"path": "attachments/...",
				"url": "http://localhost:8000/storage/attachments/...",
				"type": "string",
				"mime": "string",
				"size": 12345,
				"disk": "public"
			} | null,
			"recipe_attachment_id": "uuid|null",
			"rejection_reason": "string|null"
		}
		```

- Agendar cita (paciente): `POST /api/appointments` (ability "patient")
	- Body JSON:
		```json
		{
			"patient_id": "uuid",
			"doctor_id": "uuid",
			"scheduled_at": "YYYY-MM-DD HH:MM:SS",
			"deposit_slip_attachment_id": "uuid"
		}
		```
	- Respuestas:
		- `201 Created` → `AppointmentResource`
		- `403 Forbidden` → `{ "message": "No autorizado" }`
		- `401 Unauthorized` → `{ "message": "No autenticado" }`
		- `422 Unprocessable Entity` → `{ "message": "El horario ya está ocupado" }`

- Agendar por titular (paciente): `POST /api/appointments/by-titular` (ability "patient")
	- Body igual a `POST /api/appointments`
	- Respuestas adicionales:
		- `401 Unauthorized` → `{ "message": "No autenticado como paciente titular" }`
		- `422 Unprocessable Entity` → `{ "message": "El paciente no está asociado al titular" }`

- Agendar por doctor: `POST /api/appointments/by-doctor` (ability "doctor")
	- Body JSON:
		```json
		{
			"patient_id": "uuid",
			"scheduled_at": "YYYY-MM-DD HH:MM:SS",
			"deposit_slip_attachment_id": "uuid (opcional)"
		}
		```
	- Respuestas:
		- `201 Created` → `AppointmentResource` (con `status.value = 2`, `status.descriptor = "Confirmada"` y `confirmed_at`)
		- `403 Forbidden` → `{ "message": "No autorizado" }` o `{ "message": "Doctor inactivo o no válido" }`
		- `422 Unprocessable Entity` → `{ "message": "El horario ya está ocupado" }`

- Listado de agenda (doctor): `GET /api/appointments` (ability "doctor")
	- Query:
		- `date` (requerido) `YYYY-MM-DD`
		- `state` (opcional) `int` (ver estados)
		- `doctor_id` (opcional) `uuid`
		- `patient_id` (opcional) `uuid`
		- `order` (opcional) `asc|desc` (por `scheduled_at`)
	- `200 OK` → lista de `AppointmentResource`
	- `403 Forbidden` si token sin ability

- Reprogramar (doctor): `PATCH /api/appointments/{id}/reschedule` (ability "doctor")
	- Body JSON:
		```json
		{ "new_scheduled_at": "YYYY-MM-DD HH:MM:SS", "reason": "string (opcional)" }
		```
	- Respuestas:
		- `200 OK` → `AppointmentResource`
		- `422 Unprocessable Entity` → `{ "message": "El nuevo horario ya está ocupado" }`

- Confirmar (doctor): `PATCH /api/appointments/{id}/confirm`
	- `200 OK` → `AppointmentResource`
	- `422 Unprocessable Entity` → `{ "message": "Solo citas Por confirmar pueden confirmarse" }`

- Rechazar (doctor): `PATCH /api/appointments/{id}/reject`
	- Body JSON: `{ "reason": "string" }`
	- `200 OK` → `AppointmentResource`
	- `422 Unprocessable Entity` → `{ "message": "Solo citas Por confirmar pueden rechazarse" }`

- Atender (doctor): `PATCH /api/appointments/{id}/attend`
	- Body JSON:
		```json
		{ "diagnosis_text": "string", "recipe_attachment_id": "uuid (opcional)" }
		```
	- `200 OK` → `AppointmentResource`

- Inasistencia (doctor): `PATCH /api/appointments/{id}/absent`
	- `200 OK` → `AppointmentResource`

- Disponibilidad por horas redondas: `GET /api/appointments/availability?date=YYYY-MM-DD&from=HH:MM&to=HH:MM` (abilities "patient" o "doctor")
	- Query:
		- `date` (requerido) día a consultar
		- `from` (opcional) inicio del rango (por defecto `08:00`)
		- `to` (opcional) fin del rango (por defecto `18:00`)
	- `200 OK` →
		```json
		{
			"date": "2026-03-19",
			"from": "08:00:00",
			"to": "18:00:00",
			"available": [
				"2026-03-19T08:00:00+00:00",
				"2026-03-19T09:00:00+00:00",
				"2026-03-19T11:00:00+00:00"
			]
		}
		```

#### Doctores
- Doctores activos: `GET /api/doctors` (público)
	- `200 OK` →
		```json
		[
			{ "id": "uuid", "name": "string", "phone": "string" }
		]
		```

#### Adjuntos
- Subir adjunto: `POST /api/attachments` (abilities "patient" o "doctor")
	- `multipart/form-data`: `file` (máx 5MB), `type` (string)
	- `201 Created` → `{ "id": "uuid", "path": "attachments/...", "url": "http://localhost:8000/storage/attachments/..." }`

#### Push Notifications
- Registrar token FCM: `POST /api/device-tokens` (abilities "patient" o "doctor")
	- Body JSON:
		```json
		{
			"token": "fcm-device-token",
			"platform": "android"
		}
		```
	- `200 OK` → `{ "message": "Token registered" }`

- Desactivar token FCM: `DELETE /api/device-tokens` (abilities "patient" o "doctor")
	- Body JSON:
		```json
		{
			"token": "fcm-device-token"
		}
		```
	- `200 OK` → `{ "message": "Token deactivated" }`

- Prueba manual de push: `POST /api/push-test` (token autenticado)
	- Body JSON:
		```json
		{
			"token": "fcm-device-token",
			"title": "Prueba",
			"body": "Hola desde Laravel",
			"data": {
				"appointment_id": "uuid-opcional",
				"event": "test"
			}
		}
		```
	- `200 OK` → `{ "message": "Notification sent successfully" }`
	- Nota: este endpoint es solo para pruebas internas; debe restringirse o eliminarse en producción.

#### Flujo Android → Backend
Flujo recomendado para la app Android:

1. El usuario inicia sesión en la app con el flujo normal de paciente o doctor.
2. La app recibe el token Sanctum del backend.
3. Firebase Messaging entrega un token FCM del dispositivo.
4. La app envía ese token al backend usando `POST /api/device-tokens` con `Authorization: Bearer <token>`.
5. El backend guarda el token asociado al `person_id` autenticado.
6. Cuando cambie el token FCM, la app debe volver a registrar el nuevo valor.
7. En logout, la app debe llamar `DELETE /api/device-tokens` para desactivar el token actual.

Casos que Android debe implementar:
- Registro inicial del token después del login.
- Re-registro del token cuando Firebase lo refresque.
- Desactivación del token en logout.
- Manejo de `data payload` para navegar a la pantalla de detalle de cita cuando aplique.

Payload esperado desde Android al registrar token:

```json
{
	"token": "fcm-device-token",
	"platform": "android"
}
```

Payload típico enviado por el backend en notificaciones de citas:

```json
{
	"appointment_id": "uuid",
	"event": "confirmed"
}
```

Valores actuales de `event` usados por el backend:
- `pending_confirmation`
- `confirmed`
- `rescheduled`
- `rejected`
- `absent`

Momento recomendado para llamar el registro de token en Android:
- Después de un login exitoso.
- Después de restaurar sesión si ya existe token Sanctum válido.
- Dentro del callback de refresco de token de Firebase.

Secuencia resumida:

```text
Login -> obtener bearer token -> obtener FCM token -> POST /api/device-tokens -> recibir pushes
Logout -> DELETE /api/device-tokens -> invalidar sesión local
```

### Estados de Cita
- 1 Por confirmar, 2 Confirmada, 3 Atendida, 4 Ausente, 5 Rechazada, 6 Cancelada.

### Instalación y Arranque
```bash
composer install
php artisan migrate
php artisan db:seed
php artisan config:clear
php artisan queue:work
php artisan serve
```

Arranque con Docker:

```bash
docker compose up -d --build
```

### Pruebas
- Feature tests en `tests/Feature`:
	- `AuthTest`: login paciente/doctor
	- `AppointmentFlowTest`: paciente agenda y doctor confirma
```bash
php artisan test
```

### Notas de Seguridad
- Tokens Sanctum con abilities (`patient`/`doctor`)
- Rutas por habilidad y validaciones en controladores
- Adjuntos en disco local; usar almacenamiento privado + URLs firmadas en producción

### Ejemplos de uso rápido
Autenticación paciente y listado de sus citas:

```bash
# Login paciente
curl -sX POST http://localhost:8000/api/auth/patients/validate \
	-H "Content-Type: application/json" \
	-d '{"phone":"555-000","birthdate":"1990-01-01"}'

# Usar el token obtenido
TOKEN="<token>"
PATIENT_ID="<uuid>"

curl -s "http://localhost:8000/api/patients/$PATIENT_ID/appointments?order=desc" \
	-H "Authorization: Bearer $TOKEN"
```

### Arquitectura
- Modelos Eloquent con UUIDs, SoftDeletes y enums
- Requests/Resources y servicios aplicando SOLID
- Agenda compartida: `appointments.scheduled_at` único global
