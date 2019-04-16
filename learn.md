use static_push instead of static_path for h2 push of assets.
ets - key value store per instance. 
pg2

Code structure
assets/ - frontend assets
config/ - settings
lib/ - Actual application source code
rel/ - distillery release configurations
priv/ - generated static files
lib/


gcloud app deploy

App engine flex -
mini benchmark

artillery quick --count 10 -n 20 https://arevel.com    
Started phase 0, duration: 1s @ 23:36:02(-0500) 2019-04-14
Report @ 23:36:04(-0500) 2019-04-14
Elapsed time: 2 seconds
  Scenarios launched:  10
  Scenarios completed: 10
  Requests completed:  200
  RPS sent: 84.03
  Request latency:
    min: 36.9
    max: 165.6
    median: 49.4
    p95: 104.6
    p99: 132.5
  Codes:
    200: 200

All virtual users finished
Summary report @ 23:36:04(-0500) 2019-04-14
  Scenarios launched:  10
  Scenarios completed: 10
  Requests completed:  200
  RPS sent: 84.03
  Request latency:
    min: 36.9
    max: 165.6
    median: 49.4
    p95: 104.6
    p99: 132.5
  Scenario counts:
    0: 10 (100%)
  Codes:
    200: 200



Setting up compute engine version
https://cloud.google.com/community/tutorials/elixir-phoenix-on-google-compute-engine

export PROJECT_ID=arevel-209217
export BUCKET_NAME="${PROJECT_ID}-releases"
mkdir builder
pushd builder

docker build -t arevel-builder .


cd ~/code/arevel
mix clean --deps
docker run --rm -it -v $(pwd):/app arevel-builder


gsutil cp _build/prod/rel/arevel/bin/arevel.run \
    gs://arevel-209217-releases/arevel-release


gcloud compute instances create arevel-instance \
    --image-family debian-9 \
    --image-project debian-cloud \
    --machine-type n1-standard-4 \
    --boot-disk-type local-ssd \
    --boot-disk-size 10 \
    --scopes "userinfo-email,cloud-platform" \
    --metadata-from-file startup-script=bin/instance-startup.sh \
    --metadata release-url=gs://arevel-209217-releases/arevel-release \
    --zone us-central1-f \
    --tags http-server

gcloud compute firewall-rules create default-allow-http-9080 \
    --allow tcp:9080 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server \
    --description "Allow port 9080 access to http-server"


gcloud compute firewall-rules create default-allow-http-9081 \
    --allow tcp:9081 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server \
    --description "Allow https 9081 access to http-server"

-
TODO: Should set this to only allow it from lb.

/app/tmp/arevel/releases/0.1.0/libexec/config.sh: line 54: /app/tmp/arevel/var/vm.args: Permission denied


sudo chown -R arevelapp app


PORT=8080 ./arevel-release foreground to debug


------
Woot. Works now. I think. Needed to ssh in and verify why it wasn't running - seemed to be just cloudsql path, which kinda sucks that its a startup error. 
I can't verify the https version yet, but let's run the same benchmark against the http version

http://35.225.79.66:9080/


Started phase 0, duration: 1s @ 00:45:35(-0500) 2019-04-15
Report @ 00:45:37(-0500) 2019-04-15
Elapsed time: 2 seconds
  Scenarios launched:  10
  Scenarios completed: 10
  Requests completed:  200
  RPS sent: 106.95
  Request latency:
    min: 34.2
    max: 95.3
    median: 37.8
    p95: 70.3
    p99: 79.8
  Codes:
    200: 200

All virtual users finished
Summary report @ 00:45:37(-0500) 2019-04-15
  Scenarios launched:  10
  Scenarios completed: 10
  Requests completed:  200
  RPS sent: 106.38
  Request latency:
    min: 34.2
    max: 95.3
    median: 37.8
    p95: 70.3
    p99: 79.8
  Scenario counts:
    0: 10 (100%)
  Codes:
    200: 200

---------
p99 is better, requests per second is better, min is slightly better (2ms). In the browser as well, this matches up with what I see - and it's about as good as you can expect with network latency. I am happy with this (vs the 50ms, which frankly is horribly slwo and unacceptable :P. Nah, I just like this config more. I have the freedom to own and manage the system any way I want). Builds and deploys are faster as well vs the flex environment setup. It's not that much more complex either after some initial work. 
