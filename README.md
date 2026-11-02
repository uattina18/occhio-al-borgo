# Occhio al Borgo

App mobile per scoprire i borghi italiani come in un gioco: fotografi un borgo e un'intelligenza artificiale lo riconosce, aiutata da posizione e bussola, poi l'app ti mostra informazioni ed eventi del luogo.

> Progetto personale di Marta Righetti, in sviluppo.


## Perché

I borghi minori sono spesso poco conosciuti e a rischio abbandono, e le informazioni su cosa vedere e su quali eventi ci sono sono sparse. L'app punta a renderne la scoperta più semplice e motivante per i giovani e per gli appassionati di fotografia, con badge e inviti agli amici.

## Cosa fa

- **Riconoscimento dei borghi con l'AI**: scatti una foto e un modello di intelligenza artificiale (Google Gemini) la confronta con i borghi vicini per capire quale stai guardando. GPS e bussola restringono i candidati e fanno da ripiego quando l'AI non è sicura.
- **Esplora**: ricerca dei borghi e dettaglio di ogni borgo.
- **Eventi**: elenco degli eventi collegati ai borghi e segnalazione di nuovi eventi.
- **Profilo e gamification**: borghi riconosciuti, salvati e visitati, badge, invito di amici con codice referral.
- **Community**: chat con gli amici.
- **Sicurezza**: pagina SOS che apre il telefono con il 112 già composto.
- **Doppia lingua**: italiano e inglese.

## Come funziona il riconoscimento con l'AI

1. L'app invia al backend la foto, la posizione e la direzione della bussola.
2. Il backend seleziona i borghi vicini e li ordina per distanza e direzione, così l'AI deve scegliere tra pochi candidati e non tra tutta Italia.
3. Il modello Google Gemini riceve la foto e i candidati e risponde se la scena è un borgo, quale candidato corrisponde e con quale sicurezza.
4. Se la sicurezza è sopra una soglia, il borgo è confermato; altrimenti l'app usa la sola posizione come ripiego.

Il riconoscimento è nato con Google Cloud Vision, che etichettava la scena in modo generico, ed è passato a Gemini per confrontare la foto con i borghi reali della zona.

Il backend è in un repository separato: [occhio-al-borgo-backend](https://github.com/uattina18/occhio-al-borgo-backend).

## Tecnologie

- Flutter e Dart
- Firebase: Authentication, Cloud Firestore, Storage e Cloud Functions (in TypeScript)
- Fotocamera, geolocalizzazione e sensori del telefono
- Intelligenza artificiale: Google Gemini, tramite un backend FastAPI (repository separato)
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
