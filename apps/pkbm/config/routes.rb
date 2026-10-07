Rails.application.routes.draw do
  get "/api/v1/catalog", to: "catalog#index"
  get "/api/v1/catalog/:collection", to: "catalog#collection"
end

Rails.application.routes.draw do
  post "/api/v1/session", to: "operations#login"
  get "/api/v1/me", to: "operations#me"
  get "/api/v1/operations/:collection", to: "operations#index"
  get "/api/v1/operations/:collection/:id", to: "operations#show"
  post "/api/v1/operations/:collection", to: "operations#create"
  patch "/api/v1/operations/:collection/:id", to: "operations#update"
end

Rails.application.routes.draw do
  get "/api/v1/integration", to: "integration#index"
  put "/api/v1/integration", to: "integration#configure"
  post "/api/v1/integration/jobs", to: "integration#enqueue"
  post "/api/v1/integration/jobs/:id/retry", to: "integration#retry_job"
  post "/api/v1/integration/resources", to: "integration#select_resource"
  get "/api/v1/integration/links", to: "integration#links"
  get "/api/v1/integration/resources/:id", to: "integration#resource"
  post "/lti/launch", to: "lti#launch"
  post "/api/v1/lti/exchange", to: "lti#exchange"
end

Rails.application.routes.draw do
  get '/api/v1/assessments', to: 'assessments#index'
  patch '/api/v1/assessments/:id', to: 'assessments#update'
  post '/api/v1/assessments/:id/publish', to: 'assessments#publish'
  post '/api/v1/assessments/:id/versions', to: 'assessments#clone_version'
  get '/api/v1/assessments/:id/items/:item_key/submission', to: 'assessments#submission'
  post '/api/v1/assessments/:id/items/:item_key/submission', to: 'assessments#submission'
  post '/api/v1/assessments/:id/items/:item_key/grade', to: 'assessments#grade'
  post '/api/v1/assessments/:id/items/:item_key/release', to: 'assessments#release_tam'
  post '/api/v1/assessments/:id/items/:item_key/retry', to: 'assessments#retry_tam'
end

Rails.application.routes.draw do
  post '/api/v1/assessments/:id/review', to: 'assessments#review_module'
end

Rails.application.routes.draw do
  get '/auth/login', to: 'identity#login'
  get '/auth/callback', to: 'identity#callback'
  get '/api/v1/identity/contexts', to: 'identity#contexts'
  post '/api/v1/identity/context', to: 'identity#context'
end

Rails.application.routes.draw do
  get '/api/v1/identity/configuration', to: 'identity#configuration'
end

Rails.application.routes.draw do
  get '/belajar/:id', to: 'learning_entry#show'
  get '/kelola/canvas', to: 'learning_entry#manage'
end

Rails.application.routes.draw do
  post '/api/v1/identity/logout', to: 'identity#logout'
  post '/auth/backchannel-logout', to: 'identity#backchannel_logout'
end
