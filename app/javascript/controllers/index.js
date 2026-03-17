// Import and register all Stimulus controllers from ./controllers/**/*_controller.js
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Explicit registration for inventory grid controllers
// (eagerLoadControllersFrom can miss new files until server restart)
import InventoryGridController from "controllers/inventory_grid_controller"
import InventorySetupController from "controllers/inventory_setup_controller"
import InlineCellController from "controllers/inline_cell_controller"
application.register("inventory-grid", InventoryGridController)
application.register("inventory-setup", InventorySetupController)
application.register("inline-cell", InlineCellController)
