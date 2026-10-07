Rails.application.routes.draw do
  get "/api/v1/catalog", to: "catalog#index"
  get "/api/v1/catalog/:collection", to: "catalog#collection"
end
