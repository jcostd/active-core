// Importa e registra tutti i controller di controllers/**/*_controller dall'importmap
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
