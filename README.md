# ActiveCore 🏋️‍♂️

ActiveCore is a high-performance ERP engine specifically engineered for **Italian Sports Associations (ASD)**. It streamlines the complex bureaucratic and operational requirements of the Italian sports reform, ensuring compliance with institutional rules while maintaining a friction-free experience for the front-desk.

Built on the **Rails 8 "Solid Stack"**, ActiveCore is designed for stability, data integrity, and rapid deployment.

## 🇮🇹 Built for Italian ASD

ActiveCore is designed with the unique logic of Italian sports associations in mind:

-   **Quota Associativa (Membership Fee)**: Strict enforcement of the associative bond.

-   **Sport Year Alignment**: Support for the Italian "Anno Sportivo" (September - August) logic.

-   **Medical Certificate Management**: Built-in tracking for "Certificato Medico Agonistico/Non Agonistico" with expiration alerts.

-   **Fiscal Compliance**: Receipt (Ricevuta) generation with sequential numbering and fiscal locking.


## ✨ Key Features

### 🔄 Intelligent Subscription Engine

-   **Institutional Snap**: Automatically aligns institutional course subscriptions to calendar months or the sports year.

-   **Smart Renewal Logic**: Detects existing subscriptions to eliminate gaps in coverage and calculate "Smart Start Dates".

-   **Membership Guard**: A core safety mechanism that prevents selling any sports course if the member does not have a valid, active _Quota Associativa_.


### 🚪 Non-Blocking Access Control

-   **Real-time Policy Evaluation**: Instant check on medical certificates, active subscriptions, and payments at the point of entry.

-   **Soft Enforcement**: Unlike rigid turnstile systems, ActiveCore logs entries with specific statuses (OK/Warning/Error), allowing staff to handle issues (like an expiring certificate) with empathy rather than blocking the member.

-   **Double-tap Prevention**: Cooldown logic to prevent duplicate check-ins within the same training session.


### 📄 Document & Fiscal Engine

-   **PDF Receipts**: Automated generation of receipts via Prawn, ready for delivery to members.

-   **Sequential Integrity**: Robust handling of receipt sequences to meet accounting standards.


## 🛠 Tech Stack

-   **Backend**: [Rails 8.1](https://rubyonrails.org/) running on **Ruby 4.0.3**

-   **Frontend**: [Hotwire](https://hotwired.dev/) (Turbo 8 / Stimulus)

-   **UI & Styling**: [Tailwind CSS 4](https://tailwindcss.com/) + [daisyUI 5](https://daisyui.com/)

-   **Database**: SQLite (optimized for production with WAL mode and immediate transactions)

-   **Infrastructure**: [Solid Cache](https://github.com/rails/solid_cache), [Solid Queue](https://github.com/rails/solid_queue), [Solid Cable](https://github.com/rails/solid_cable)

-   **Deployment**: [Kamal](https://kamal-deploy.org/) (Docker-based)


## 🚀 Installation & Setup

```
# Clone the repository
git clone https://github.com/jcostd/active-core.git
cd active-core

# Automated setup (install gems, prepare DB, seed data)
bin/setup

# Start the development environment (Rails + Tailwind + DaisyUI)
bin/dev

```

## 🛡 Quality & Security

Data integrity is our top priority. Every build must pass the comprehensive `bin/ci` suite:

-   **Minitest**: Full unit and integration testing coverage.

-   **Brakeman**: Static analysis for security vulnerabilities.

-   **Bundler-Audit**: Verification of dependencies against known CVEs.

-   **Rubocop**: Omakase-style code linting for maintainable Ruby.


## 📄 License

This project is released under the **GPLv3 License**.

----------

Developed with ❤️ for the Italian sports community.
