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
