# ==========================================
# 1. INFRAESTRUCTURA BASE (DATOS Y MENSAJERÍA)
# ==========================================
module "storage" {
  source       = "./modules/storage"
  project_name = var.project_name
  environment  = var.environment
}

module "messaging" {
  source       = "./modules/messaging"
  project_name = var.project_name
  environment  = var.environment
}

# ==========================================
# 2. CAPA DE SEGURIDAD (IAM)
# ==========================================
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  environment  = var.environment

  # Dependencias de Storage
  frontend_bucket_id     = module.storage.frontend_bucket_id
  frontend_bucket_arn    = module.storage.frontend_bucket_arn
  tickets_bucket_arn     = module.storage.tickets_bucket_arn
  reservations_table_arn = module.storage.reservations_table_arn
  inventory_table_arn    = module.storage.inventory_table_arn
  
  # Dependencias de Messaging
  reservation_queue_arn  = module.messaging.reservation_queue_arn
  pdf_queue_arn          = module.messaging.pdf_queue_arn # Ahora sí existe el output
}

# ==========================================
# 3. CAPA DE CÓMPUTO Y LÓGICA
# ==========================================
module "compute" {
  source       = "./modules/compute"
  project_name = var.project_name
  environment  = var.environment

  # Inyectamos Roles de Security
  lambda_ingestion_role_arn = module.security.lambda_ingestion_role_arn
  sfn_role_arn              = module.security.sfn_role_arn

  # Inyectamos Recursos de Storage
  inventory_table_name      = module.storage.inventory_table_name
  reservations_table_name   = module.storage.reservations_table_name
  tickets_bucket_name    = module.storage.tickets_bucket_name

  # Inyectamos Recursos de Messaging
  event_bus_name            = module.messaging.event_bus_name 
  event_bus_arn             = module.messaging.event_bus_arn
  reservation_queue_arn     = module.messaging.reservation_queue_arn
  notification_queue_arn = module.messaging.notification_queue_arn
  pdf_queue_arn          = module.messaging.pdf_queue_arn
}