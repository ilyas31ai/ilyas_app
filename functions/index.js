const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({region: "us-central1", maxInstances: 10});

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Renvoie un libellé lisible pour l'aperçu de notification selon le type
 * de message (aligné sur MessagerieService.sendMessage côté client).
 */
function previewFor(message) {
  const type = message.type || "text";
  if (type === "text") return message.text || "";
  if (type === "voice") return "🎤 Message vocal";
  if (type === "image") return "🖼️ Image";
  return "📎 Fichier";
}

/**
 * Envoie une notification push FCM à chaque participant d'une conversation
 * (hors expéditeur) dès qu'un nouveau message est créé — y compris quand
 * l'app destinataire est en arrière-plan ou totalement fermée, ce que le
 * simple listener Firestore côté client ne permet pas.
 */
exports.onMessageCreated = onDocumentCreated(
    "conversations/{convId}/messages/{msgId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;
      const message = snap.data();
      const {convId} = event.params;
      const senderId = message.senderId;
      if (!senderId) return;

      const convSnap = await db.collection("conversations").doc(convId).get();
      if (!convSnap.exists) return;
      const conv = convSnap.data();
      const participantIds = conv.participantIds || [];
      const recipientIds = participantIds.filter((id) => id !== senderId);
      if (recipientIds.length === 0) return;

      const userDocs = await db.getAll(
          ...recipientIds.map((id) => db.collection("users").doc(id)),
      );
      const tokens = [];
      for (const doc of userDocs) {
        const token = doc.exists ? doc.data().fcmToken : null;
        if (token) tokens.push(token);
      }
      if (tokens.length === 0) return;

      const title = conv.type === "group" ?
        `${message.senderNom || "Quelqu'un"} (${conv.name || "Groupe"})` :
        message.senderNom || "Nouveau message";
      const body = previewFor(message);

      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: {title, body},
        data: {
          type: "messagerie",
          convId,
        },
        android: {
          priority: "high",
          notification: {channelId: "messagerie"},
        },
      });

      // Nettoie les tokens invalides/expirés pour éviter de les re-tenter
      // indéfiniment (l'app les réécrit de toute façon à chaque connexion).
      const invalidTokens = [];
      response.responses.forEach((r, i) => {
        if (!r.success) {
          const code = r.error && r.error.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            invalidTokens.push(tokens[i]);
          }
        }
      });
      if (invalidTokens.length > 0) {
        const cleanups = userDocs
            .filter((doc) => invalidTokens.includes(doc.data() &&
              doc.data().fcmToken))
            .map((doc) => doc.ref.update({
              fcmToken: admin.firestore.FieldValue.delete(),
            }));
        await Promise.all(cleanups);
      }
    },
);
