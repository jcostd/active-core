# ActiveCore 🏋️‍♂️

ActiveCore è il gestionale pensato per le **Associazioni Sportive Dilettantistiche (ASD) italiane**. Semplifica gli adempimenti burocratici e operativi della riforma dello sport, rispettando le regole istituzionali senza complicare il lavoro della segreteria.

È costruito sullo **"Solid Stack" di Rails 8**: stabilità, integrità dei dati e deploy semplice.

## 🇮🇹 Fatto per le ASD italiane

-   **Quota Associativa**: il vincolo associativo è sempre verificato.

-   **Anno Sportivo**: tesseramenti allineati all'anno sportivo (settembre - agosto).

-   **Certificato Medico**: scadenze del certificato agonistico/non agonistico con avvisi.

-   **Ricevute**: numerazione progressiva per registro e dati fiscali non modificabili dopo l'emissione. Niente "storni": le ASD non vendono, tesserano.


## ✨ Funzionalità principali

### 🔄 Abbonamenti

-   **Allineamento automatico**: i corsi istituzionali si allineano ai mesi di calendario o all'anno sportivo.

-   **Rinnovi senza buchi**: il rinnovo riparte dal giorno dopo la scadenza se il socio rientra entro 30 giorni.

-   **Controllo Quota**: non si può vendere un corso a chi non ha una Quota Associativa valida.

-   **Rate libere**: pagamenti progressivi di qualsiasi importo, sempre entro il residuo dovuto.


### 🚪 Accessi non bloccanti (kiosk iPad)

-   **Verifica in tempo reale**: certificato medico, abbonamento attivo e pagamenti al momento dell'ingresso.

-   **Nessun blocco**: l'ingresso viene sempre registrato con un esito (OK/Avviso/Errore) e la segreteria gestisce i casi con calma.

-   **Doppio tocco**: un secondo check-in ravvicinato viene ignorato.


### 📄 Ricevute

-   **PDF** generati con Prawn, pronti da consegnare al socio.

-   **Numerazione sicura** anche con più operatori contemporanei.


## 🔐 Utenti e sicurezza

-   **Due ruoli**: lo **staff** gestisce soci, vendite e kiosk; l'**admin** ha anche prodotti, discipline, report, utenti e il registro accessi.

-   **Correzione degli errori**: lo staff può annullare **solo i propri** pagamenti e abbonamenti entro **15 minuti**; l'admin qualsiasi pagamento entro **24 ore**. Annullare un abbonamento annulla anche i pagamenti collegati.

-   **Vendite a 0 €**: solo l'admin.

-   **Sessione**: si chiude dopo **1 ora di inattività**. Il kiosk resta collegato.

-   **Protezioni**: Content Security Policy, dati personali esclusi dai log, limite ai tentativi di accesso.


## 🛠 Tecnologie

-   **Backend**: [Rails 8.1](https://rubyonrails.org/) su **Ruby 4.0.5**

-   **Frontend**: [Hotwire](https://hotwired.dev/) (Turbo 8 / Stimulus), import map senza build JavaScript

-   **Interfaccia**: [Tailwind CSS 4](https://tailwindcss.com/) + [daisyUI 5](https://daisyui.com/)

-   **Database**: SQLite (modalità WAL), backup con Litestream

-   **Infrastruttura**: [Solid Cache](https://github.com/rails/solid_cache), [Solid Queue](https://github.com/rails/solid_queue) (job ricorrenti in `config/recurring.yml`), [Solid Cable](https://github.com/rails/solid_cable)

-   **Deploy**: [Kamal](https://kamal-deploy.org/) (Docker)


## 🚀 Installazione

```
# Clona il repository
git clone https://github.com/jcostd/active-core.git
cd active-core

# Setup automatico (gem, database, dati di esempio)
bin/setup

# Avvia l'ambiente di sviluppo (Rails + Tailwind)
bin/dev
```

### Produzione in rete locale

L'app gira nella rete della palestra, in HTTP. Variabili d'ambiente utili:

| Variabile   | Esempio                        | Uso                                             |
| ----------- | ------------------------------ | ----------------------------------------------- |
| `APP_HOST`  | `palestra.lan`                 | indirizzo usato nei link delle email            |
| `APP_HOSTS` | `palestra.lan,192.168.1.10`    | nomi/IP accettati (protezione DNS rebinding)    |


## 🛡 Qualità

Ogni modifica deve superare `bin/ci`:

-   **Minitest**: test di modelli, controller e integrazione.

-   **Brakeman**: analisi statica di sicurezza.

-   **Bundler-Audit** e **importmap audit**: dipendenze senza vulnerabilità note.

-   **Rubocop**: stile Omakase.

Per verificare i casi di calendario (capodanno, cambio anno sportivo, ora legale) la suite si può eseguire in una data qualsiasi:

```
TEST_NOW="2027-01-01 10:00" bin/rails test
```


## 📄 Licenza

Progetto rilasciato con licenza **GPLv3**.

----------

Sviluppato con ❤️ per lo sport dilettantistico italiano.
