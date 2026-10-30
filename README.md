# Occhio al Borgo

App mobile per scoprire i borghi italiani come in un gioco: fotografi un borgo, l'app lo riconosce da posizione, bussola e immagine, e ti mostra informazioni ed eventi del luogo.

> Progetto personale di Marta Righetti, in sviluppo.

<!-- Aggiungi qui 2-3 screenshot, per esempio:
<p>
  <img src="docs/screenshots/home.png" width="220" alt="Home">
  <img src="docs/screenshots/scatta.png" width="220" alt="Scatta un borgo">
  <img src="docs/screenshots/profilo.png" width="220" alt="Profilo e badge">
</p>
-->

## Perché

I borghi minori sono spesso poco conosciuti e a rischio abbandono, e le informazioni su cosa vedere e su quali eventi ci sono sono sparse. L'app punta a renderne la scoperta più semplice e motivante per i giovani e per gli appassionati di fotografia, con badge e inviti agli amici.

## Cosa fa

- **Scatta un borgo**: fotocamera, GPS e bussola indicano dove ti trovi e verso cosa stai puntando. La foto viene inviata a un backend che sceglie il borgo più probabile tra quelli vicini.
- **Esplora**: ricerca dei borghi e dettaglio di ogni borgo.
- **Eventi**: elenco degli eventi collegati ai borghi e segnalazione di nuovi eventi.
- **Profilo e gamification**: borghi riconosciuti, salvati e visitati, badge, invito di amici con codice referral.
- **Community**: chat con gli amici.
- **Sicurezza**: pagina SOS che apre il telefono con il 112 già composto.
- **Doppia lingua**: italiano e inglese.

## Come funziona il riconoscimento

1. L'app invia al backend la foto, la posizione e la direzione della bussola.
2. Il backend seleziona i borghi vicini e li ordina per distanza e direzione.
3. Un modello di Google (Gemini) confronta la foto con i candidati.
4. Se il modello non è abbastanza sicuro, si usa la sola posizione come ripiego.

Il backend è in un repository separato: [occhio-al-borgo-backend](https://github.com/uattina18/occhio-al-borgo-backend).

## Tecnologie

- Flutter e Dart
- Firebase: Authentication, Cloud Firestore, Storage e Cloud Functions (in TypeScript)
- Fotocamera, geolocalizzazione e sensori del telefono
- Backend FastAPI (repository separato)
- Progettazione in Penpot

## Come avviarlo

Servono Flutter (con Dart 3.9 o superiore) e un telefono Android o un emulatore.

```bash
git clone https://github.com/uattina18/occhio-al-borgo.git
cd occhio-al-borgo
flutter pub get
flutter run
```

Per usare un tuo progetto Firebase al posto di quello del repository, configuralo con `flutterfire configure` e pubblica le regole di Firestore in `firestore.rules`.

L'app chiama un backend online per il riconoscimento delle foto.

## Struttura del progetto

```
lib/
  screens/    schermate dell'app
  services/   chat, amici, sincronizzazione utente, screenshot
  l10n/       traduzioni italiano e inglese
  theme/      colori e stile
  widgets/    componenti condivisi
functions/    Cloud Functions per il sistema di inviti
assets/data/  borghi, eventi e badge
```

## Stato e prossimi passi

- Rifinitura delle schermate e della stabilità
- Mappa dei sentieri e percorsi consigliati
- Portale web per Comuni e Pro Loco
- Accessibilità (WCAG 2.2) e revisione della privacy

## Autrice

Marta Righetti, [martarighetticodeux.it](https://martarighetticodeux.it)
