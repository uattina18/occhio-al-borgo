import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Genera un codice invito univoco per un utente autenticato
 */
export const generateReferralCode = onCall(
  async (request: CallableRequest<any>) => {
    const context = request.auth;
    if (!context) {
      throw new HttpsError("unauthenticated", "Devi essere autenticato.");
    }

    const uid = context.uid;
    const ref = db.collection("users").doc(uid);

    const userDoc = await ref.get();
    if (userDoc.exists && userDoc.data()?.refCode) {
      return { code: userDoc.data()?.refCode };
    }

    // Crea un codice casuale di 6 lettere/numeri
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const code = Array.from(
      { length: 6 },
      () => chars[Math.floor(Math.random() * chars.length)]
    ).join("");

    await ref.set(
      { refCode: code, invitesSent: 0, invitesSuccess: 0 },
      { merge: true }
    );
    return { code };
  }
);

/**
 * Registra un invito inviato (con limite anti-spam)
 */
export const registerInviteSent = onCall(
  async (request: CallableRequest<any>) => {
    const context = request.auth;
    if (!context) throw new HttpsError("unauthenticated", "Accesso negato.");
    const uid = context.uid;

    const ref = db.collection("users").doc(uid);
    const userDoc = await ref.get();

    const now = admin.firestore.Timestamp.now();
    const lastSent =
      userDoc.data()?.lastInviteTime || admin.firestore.Timestamp.fromMillis(0);
    const diffSec = now.seconds - lastSent.seconds;

    if (diffSec < 60) {
      throw new HttpsError(
        "resource-exhausted",
        "Puoi inviare solo 1 invito al minuto."
      );
    }

    await ref.update({
      invitesSent: admin.firestore.FieldValue.increment(1),
      lastInviteTime: now,
    });

    return { ok: true };
  }
);

/**
 * Segna un invito riuscito (quando un nuovo utente si registra con il codice)
 */
export const registerInviteSuccess = onCall(
  async (request: CallableRequest<any>) => {
    const data = request.data;
    const code = data?.code;
    if (!code) throw new HttpsError("invalid-argument", "Codice mancante.");

    const snap = await db
      .collection("users")
      .where("refCode", "==", code)
      .limit(1)
      .get();
    if (snap.empty) throw new HttpsError("not-found", "Codice non valido.");

    const ref = snap.docs[0].ref;
    await ref.update({
      invitesSuccess: admin.firestore.FieldValue.increment(1),
    });

    return { ok: true };
  }
);
