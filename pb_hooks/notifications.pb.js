/**
 * pb_hooks/notifications.pb.js
 * -------------------------------------------------------------
 * Hook de PocketBase para enviar Notificaciones Push (APNs / FCM)
 * a los clientes cuando el entrenador realiza cambios en el panel.
 *
 * Colocar este archivo en la carpeta 'pb_hooks/' de tu servidor PocketBase.
 * PocketBase lo cargará automáticamente al arrancar.
 * -------------------------------------------------------------
 */

// Configuración opcional de proveedor Push (APNs / FCM / OneSignal / Gateway HTTP)
const PUSH_GATEWAY_URL = $os.getenv("PUSH_GATEWAY_URL") || ""; // Ej: "https://tu-gateway.com/send"
const APNS_TOPIC = "com.aurasteps.app"; // Bundle ID de AuraSteps

/**
 * Envía una notificación push al token del dispositivo del usuario.
 * @param {string} userId - ID del usuario en la colección 'users'
 * @param {string} title - Título de la notificación
 * @param {string} body - Mensaje o cuerpo de la notificación
 * @param {object} customData - Metadatos adicionales opcionales
 */
function sendPushToUser(userId, title, body, customData = {}) {
    try {
        if (!userId) return;
        
        // Buscar el usuario y obtener su token de dispositivo
        const user = $app.dao().findRecordById("users", userId);
        if (!user) return;
        
        const deviceToken = user.getString("apns_token") || user.getString("device_token");
        if (!deviceToken) {
            console.log(`[Push] Usuario ${userId} (${user.getString("email")}) no tiene token APNs registrado.`);
            return;
        }

        console.log(`[Push] Enviando notificación a usuario ${userId} [Token: ${deviceToken.substring(0, 10)}...]: "${title}" - "${body}"`);

        // Si tienes configurado un Gateway o servicio HTTP (ej. FCM / OneSignal / Cloudflare Worker APNs)
        if (PUSH_GATEWAY_URL) {
            $http.send({
                url: PUSH_GATEWAY_URL,
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    token: deviceToken,
                    topic: APNS_TOPIC,
                    title: title,
                    body: body,
                    data: customData,
                    sound: "default"
                }),
                timeout: 10
            });
        }
    } catch (err) {
        console.log(`[Push Error] No se pudo enviar push a ${userId}:`, err);
    }
}

// =========================================================================
// 1. Hook para Nuevas Notas del Entrenador (Colección: client_notes)
// =========================================================================
onRecordAfterCreateRequest((e) => {
    try {
        const userId = e.record.getString("user") || e.record.getString("user_id") || e.record.getString("client");
        const title = e.record.getString("title") || "Nota de tu Entrenador";
        const content = e.record.getString("content") || e.record.getString("note") || "Tienes una nueva recomendación o nota de tu entrenador.";

        sendPushToUser(
            userId,
            `💬 ${title}`,
            content,
            { type: "client_note", id: e.record.id }
        );
    } catch (err) {
        console.log("[Hook Error client_notes create]:", err);
    }
}, "client_notes");

// =========================================================================
// 2. Hook para Actualización de Rutina (Colección: workout_routines)
// =========================================================================
onRecordAfterUpdateRequest((e) => {
    try {
        const userId = e.record.getString("user") || e.record.getString("user_id") || e.record.getString("client");
        const routineName = e.record.getString("name") || "Rutina Activa";

        sendPushToUser(
            userId,
            "🏋️ ¡Rutina Actualizada!",
            `Tu entrenador ha actualizado "${routineName}". Revisa tus nuevos ejercicios y series.`,
            { type: "routine_update", id: e.record.id }
        );
    } catch (err) {
        console.log("[Hook Error workout_routines update]:", err);
    }
}, "workout_routines");

// =========================================================================
// 3. Hook para Revisión de Vídeo / Foto (Colección: progress_uploads)
// =========================================================================
onRecordAfterUpdateRequest((e) => {
    try {
        const userId = e.record.getString("user") || e.record.getString("user_id") || e.record.getString("client");
        const adminResponse = e.record.getString("admin_response");
        const seenByAdmin = e.record.getBool("seen_by_admin");

        if (adminResponse && adminResponse.length > 0) {
            sendPushToUser(
                userId,
                "✅ Entrega de Progreso Revisada",
                `Tu entrenador ha comentado tu entrega: "${adminResponse}"`,
                { type: "progress_feedback", id: e.record.id }
            );
        } else if (seenByAdmin) {
            sendPushToUser(
                userId,
                "👁️ Entrega Vista por tu Entrenador",
                "Tu entrenador ha visualizado tu foto/vídeo de progreso.",
                { type: "progress_seen", id: e.record.id }
            );
        }
    } catch (err) {
        console.log("[Hook Error progress_uploads update]:", err);
    }
}, "progress_uploads");
