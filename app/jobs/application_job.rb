class ApplicationJob < ActiveJob::Base
  # Riprova i job finiti in deadlock
  # retry_on ActiveRecord::Deadlocked

  # Scarta i job i cui record non esistono più
  # discard_on ActiveJob::DeserializationError
end
