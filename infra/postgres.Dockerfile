FROM postgres:14@sha256:ceef4a62198b562d6fe3e51be67362f72a0abf0aaa255f54f0c0e55be9768ed2
RUN apt-get update -qq && apt-get install -y --no-install-recommends postgresql-14-pgvector && rm -rf /var/lib/apt/lists/*
