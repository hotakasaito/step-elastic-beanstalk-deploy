#!/bin/bash
set +e

cd $HOME
if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_APP_NAME" ]
then
    fail "Missing or empty option APP_NAME, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME" ]
then
    fail "Missing or empty option ENV_NAME, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY" ]
then
    fail "Missing or empty option KEY, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET" ]
then
    fail "Missing or empty option SECRET, please check wercker.yml"
fi

if [ ! -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_REGION" ]
then
    warn "Missing or empty option REGION, defaulting to us-west-2"
    WERCKER_ELASTIC_BEANSTALK_DEPLOY_REGION="us-west-2"
fi

if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_DEBUG" ]
then
    warn "Debug mode turned on, this can dump potentially dangerous information to log files."
fi

AWSEB_CREDENTIAL_FILE="$HOME/.elasticbeanstalk/aws_credential_file"
AWSEB_EB_CONFIG_FILE="$WERCKER_SOURCE_DIR/.elasticbeanstalk/config.yml"

export AWS_CREDENTIAL_FILE=$AWSEB_CREDENTIAL_FILE
export AWS_ACCESS_KEY_ID=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY
export AWS_SECRET_ACCESS_KEY=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET

echo "Printenv..."
env

echo 'Synchronizing References in apt-get...'
sudo apt-get update

echo 'Installing pip...'
sudo apt-get install -y python-pip libpython-all-dev

echo 'Installing awscli...'
sudo pip install --upgrade awsebcli

echo 'eb version show...'
eb --version

test -d "$WERCKER_SOURCE_DIR/.elasticbeanstalk/" || mkdir -p "$WERCKER_SOURCE_DIR/.elasticbeanstalk/" || fail "Unable to make directory."

debug "Change back to the source dir."
cd $WERCKER_SOURCE_DIR

debug "Setting up credentials..."
test -d $(dirname $AWSEB_CREDENTIAL_FILE) || mkdir $(dirname $AWSEB_CREDENTIAL_FILE)
cat <<EOT > $AWSEB_CREDENTIAL_FILE
AWSAccessKeyId=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_KEY
AWSSecretKey=$WERCKER_ELASTIC_BEANSTALK_DEPLOY_SECRET
EOT

debug "Setting up eb config..."
cat <<EOF > $AWSEB_EB_CONFIG_FILE
branch-defaults:
  default:
    environment: $WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
  $WERCKER_GIT_BRANCH:
    environment: $WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME
global:
  application_name: $WERCKER_ELASTIC_BEANSTALK_DEPLOY_APP_NAME
  default_platform: Ruby 2.2 (Puma)
  default_region: $WERCKER_ELASTIC_BEANSTALK_DEPLOY_REGION
  profile: null
  sc: git
EOF

if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_DEBUG" ]
then
    debug "Dumping config file."
    cat $AWSEB_CREDENTIAL_FILE
    cat $AWSEB_EB_CONFIG_FILE
fi

/usr/local/bin/eb use $WERCKER_ELASTIC_BEANSTALK_DEPLOY_ENV_NAME || fail "EB is not working or is not set up correctly."

debug "Checking if eb exists and can connect."
/usr/local/bin/eb status || fail "EB is not working or is not set up correctly."

debug "Pushing to AWS eb servers."
if [ -n "$WERCKER_ELASTIC_BEANSTALK_DEPLOY_NOHUP" ]
then
    nohup /usr/local/bin/eb deploy $WERCKER_ELASTIC_BEANSTALK_DEPLOY_OPTS &
else
    /usr/local/bin/eb deploy $WERCKER_ELASTIC_BEANSTALK_DEPLOY_OPTS
fi

success 'Successfully pushed to Amazon Elastic Beanstalk'
