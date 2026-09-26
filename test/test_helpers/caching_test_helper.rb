module CachingTestHelper
  # fragment caching is off in test env; enable it for one block
  def with_fragment_caching
    store = ActiveSupport::Cache::MemoryStore.new
    previous = [ ActionController::Base.perform_caching, ActionController::Base.cache_store, ActionView::PartialRenderer.collection_cache ]

    ActionController::Base.perform_caching = true
    ActionController::Base.cache_store = store
    ActionView::PartialRenderer.collection_cache = store
    yield
  ensure
    ActionController::Base.perform_caching, ActionController::Base.cache_store, ActionView::PartialRenderer.collection_cache = previous
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include CachingTestHelper
end
