#!/bin/bash
# PLACEHOLDERS
# [STAGING_FOLDER] - staging directory in your server
# [STAGING_URL] - staging url
# [STAGING_USER] - staging user in the server
# [STAGING_MYSQLUSER] - staging mysql user
# [STAGING_MYSQLPASSWORD] - staging mysql password
# [ROOTUSER] - Mysql root user
# [ROOTPASSWORD] - Mysql root password

echo "BRANCH: $GIT_BRANCH";
echo "NAME: $JOB_NAME";
echo "BUILD#: $3";
if [ $# -ne 3 ] && [ $# -ne 5 ]
  then
    printf "Invalid number of arguments provided. \$1=branchname \$2=jobname \$3=buildnumber\nUsage: /root/scripts/deploy.sh $GIT_BRANCH $JOB_NAME\n";
  exit 1;
fi
#assign params
GIT_BRANCH=$1
JOB_NAME=$2
BUILD_NUMBER=$3
DOMAIN=$4
USERNAME=$5

#initialise constants
PROJECTWORKSPACE="/var/lib/jenkins/workspace/$JOB_NAME";
PROJECTSTAGING="[STAGING_FOLDER]/$JOB_NAME";
WORDPRESS="/root/repo/WordPress";
PROJECT=`echo $JOB_NAME | sed -E -e "s/(.com|.net|.org)//"`;
echo $GIT_BRANCH;

if [ $GIT_BRANCH = "origin/staging" ];then
        echo "BUILDING STAGING";
    # First build?
    if [ $BUILD_NUMBER = 1 ];then
        echo "INIT STAGING";
        sudo mkdir -p $PROJECTSTAGING;
    fi
    # Sync Job workspace to staging
    sudo rsync -avz $PROJECTWORKSPACE/ $PROJECTSTAGING/;
    sudo rsync -avz $WORDPRESS/ $PROJECTSTAGING/;
    # First build?
    if [ $BUILD_NUMBER = 1 ] || [ ! -d "$PROJECTSTAGING" ] ;then
        # Update wp-config variables
        sudo sed -e "s/\$WP_SITEURL\|\$WP_HOME/[STAGING_URL]/$JOB_NAME/g" -e "s/\$DB_NAME/staging_${PROJECT}_db/g" -e "s/\$DB_USER/[STAGING_MYSQLUSER]/g" -e "s/\$DB_PASSWORD/[STAGING_MYSQLPASSWORD]/g" -e "s/\$DB_HOST/localhost/g" $PROJECTSTAGING/wp-config-sample.php | sudo tee $PROJECTSTAGING/wp-config.php;
        # Generate Salt Secret Key
        #SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/) && echo $SALT | sudo tee -a $PROJECTSTAGING/wp-config.php;
        # import initial sql file
        mysql -u[ROOTUSER] -p'[ROOTPASSWORD]' -e "CREATE DATABASE staging_${PROJECT}_db; GRANT ALL PRIVILEGES ON staging_${PROJECT}_db.* TO [STAGING_MYSQLUSER]@localhost";
        echo "Database created";
        mysql -u[STAGING_MYSQLUSER] -p'[STAGING_MYSQLPASSWORD]' staging_${PROJECT}_db < db.sql;

        echo "db_name: staging_${JOB_NAME}_db \n";
        echo "db_user: staging_[STAGING_MYSQLUSER] \n";
    fi
    sudo chmod -R 755 $PROJECTSTAGING;
    sudo chown -R [STAGINGUSER]:[STAGINGUSER] $PROJECTSTAGING;

    echo "SUCCESSFULLY BUILD AND DEPLOYED STAGING";

else
        echo "BUILDING LIVE";
        #DBNAME=`echo $JOB_NAME | sed -E -e "s/(.com|.net|.org)//"`;
        PROJECTWEBROOT="/home/$USERNAME/www";
        # Account directory exist?
        if [ -d "$PROJECTWEBROOT" ]; then
                echo "SYNCING PROJECT";
                # Sync Job Workspace to production.
                sudo rsync -avz $PROJECTWORKSPACE/ $PROJECTWEBROOT/;
                sudo rsync -avz $WORDPRESS/ $PROJECTWEBROOT/;
                sudo chmod -R 755 $PROJECTWEBROOT;
                sudo chown -R $USERNAME:$USERNAME $PROJECTWEBROOT/;
        else
                # Create Account
                yes | /root/scripts/createaccount.sh $DOMAIN $USERNAME;
                # Generate password
                DBPASSWORD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`;
                # First deployment, create database and user
                mysql -u[ROOTUSER] -p'[ROOTPASSWORD]' -e "CREATE DATABASE ${USERNAME}_db; GRANT ALL PRIVILEGES ON ${USERNAME}_db.* TO ${USERNAME}@localhost identified by '${DBPASSWORD}'";
                # Restore database
                mysql -u$USERNAME -p"$DBPASSWORD" ${USERNAME}_db < db.sql;
                # Sync Job Workspace to production
                sudo rsync -avz $PROJECTWORKSPACE/ $PROJECTWEBROOT/;
                sudo rsync -avz $WORDPRESS/ $PROJECTWEBROOT/;
                # Update wp-config variables
                sudo sed -e "s/\$WP_SITEURL\|\$WP_HOME/https:\/\/$DOMAIN/g" -e "s/\$DB_NAME/${USERNAME}_db/g" -e "s/\$DB_USER/${USERNAME}/g" -e "s/\$DB_PASSWORD/${DBPASSWORD}/g" -e "s/\$DB_HOST/localhost/g" $PROJECTWEBROOT/wp-config-sample.php | sudo tee $PROJECTWEBROOT/wp-config.php;
                # Generate Salt Secret Key
                #SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/) && echo $SALT | sudo tee -a $PROJECTWEBROOT/wp-config.php;
                sudo chmod -R 755 $PROJECTWEBROOT;
                sudo chown -R $USERNAME:$USERNAME $PROJECTWEBROOT/;
                echo "db_name: ${USERNAME}_db";
                echo "db_user: ${USERNAME}";
                echo "db_password: ${DBPASSWORD}";
        fi
fi

