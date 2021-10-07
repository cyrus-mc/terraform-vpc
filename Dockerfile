FROM dat-docker.jfrog.io/hashicorp/terraform:1.0.8

# copy in provider.tf to initialize and cache required providers
WORKDIR /src/test
COPY test/provider.tf .

# copy the rest of the source
WORKDIR /src
COPY . .

# run plan (and save)
ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""
ENV AWS_SESSION_TOKEN=""

ENTRYPOINT cd /src/test && terraform init --input=false && terraform get && \
           terraform plan -no-color | tee test.tfplan && \
           diff expected.tfplan test.tfplan && \
           echo "All tests passed!"
