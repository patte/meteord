set -e

if [ -d /bundle ]; then
  cd /bundle
  tar xzf *.tar.gz
  cd /bundle/bundle/programs/server/
  npm i
  cd /bundle/bundle/
elif [[ $BUNDLE_URL ]]; then
  cd /tmp
  curl -L -o bundle.tar.gz $BUNDLE_URL
  tar xzf bundle.tar.gz
  cd /tmp/bundle/programs/server/
  npm i
  cd /tmp/bundle/
elif [ -d /built_app ]; then
  cd /built_app
else
  echo "=> You don't have an meteor app to run in this image."
  exit 1
fi

if [[ $REBULD_NPM_MODULES ]]; then
  if [ -f /opt/meteord/rebuild_npm_modules.sh ]; then
    cd programs/server
    bash /opt/meteord/rebuild_npm_modules.sh
    cd ../../
  else
    echo "=> Use meteorhacks/meteord:bin-build for binary bulding."
    exit 1
  fi
fi

# Set a delay to wait to start meteor container
if [[ $DELAY ]]; then
  echo "Delaying startup for $DELAY seconds"
  sleep $DELAY
fi

# Honour already existing PORT setup
export PORT=${PORT:-80}

# map kubernetes service env vars
# get the kubernetes mongo service name from K8S_MONGO_SERVICE_ENV_NAME
# and expand it to the resulting MONGO_URL
# if K8S_MONGO_DB_NAME is set, it gets appended to MONGO_URL
# ex.
# given by k8s env:
# MYAPP_MONGO_SERVICE_HOST="host"
# MYAPP_MONGO_SERVICE_PORT=27018
# set in Dockerfile/controller.json
# K8S_MONGO_SERVICE_ENV_NAME="MYAPP_MONGO"
# K8S_MONGO_DB_NAME="myapp_prod"
# results in:
# MONGO_URL: mongodb://host:27018:/myapp_prod
if [[ $K8S_MONGO_SERVICE_ENV_NAME ]]; then
  MONGO_HOST_VAR=${K8S_MONGO_SERVICE_ENV_NAME}_SERVICE_HOST
  MONGO_PORT_VAR=${K8S_MONGO_SERVICE_ENV_NAME}_SERVICE_PORT

  MONGO_URL=mongodb://${!MONGO_HOST_VAR}:${!MONGO_PORT_VAR}
  if [[ $K8S_MONGO_DB_NAME ]]; then
    MONGO_URL=${MONGO_URL}:/${K8S_MONGO_DB_NAME}
  fi
  export MONGO_URL=${MONGO_URL}
  echo "Use MONGO_URL: $MONGO_URL"
fi

echo "=> Starting meteor app on port:$PORT"
node main.js
