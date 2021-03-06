#!/bin/bash
set -o pipefail

export REPO_USER=nablarch

export DEVELOP_REPO_URL=http://ec2-52-199-35-248.ap-northeast-1.compute.amazonaws.com
export DEVELOP_REPO_NAME=repo


#/--- ****今だけ***** 
#  gradleプラグインのインストール
git clone -b feature-travis https://github.com/travis-nab/nablarch-gradle-plugin.git
pushd nablarch-gradle-plugin
chmod +x gradlew
./gradlew install
popd
#****今だけ***** ---/


# if it creates pull request, execute `gradlew build` only.
# if it merges pull request to develop branch or dilectly commit on develop branch, execute `gradlew uploadArchives`.
# Waning, TRAVIS_PULL_REQUEST variable is 'false' or pull request number, 1,2,3 and so on.
if [ "${TRAVIS_PULL_REQUEST}" == "false" -a "${TRAVIS_BRANCH}" == "develop"  ]; then
  ./gradlew clean test uploadArchives -PnablarchRepoUsername=${REPO_USER} -PnablarchRepoPassword=${DEPLOY_PASSWORD} \
                           -PnablarchRepoReferenceUrl=${DEVELOP_REPO_URL} -PnablarchRepoReferenceName=${DEVELOP_REPO_NAME} \
                           -PnablarchRepoDeployUrl=dav:${DEVELOP_REPO_URL} -PnablarchRepoName=${DEVELOP_REPO_NAME} \
                           --no-daemon
else
  ./gradlew clean test -PnablarchRepoUsername=${REPO_USER} -PnablarchRepoPassword=${DEPLOY_PASSWORD} \
                  -PnablarchRepoReferenceUrl=${DEVELOP_REPO_URL} -PnablarchRepoReferenceName=${DEVELOP_REPO_NAME} \
                  -PnablarchRepoDeployUrl=dav:${DEVELOP_REPO_URL} -PnablarchRepoName=${DEVELOP_REPO_NAME} \
                  --no-daemon
fi


# Upload Unit test report.
function uploadDir() {

  local readonly _local_upload_dir=$1
  local readonly _remote_base_dir=$2

  ### Firstly, create base directory.
    # ex. create /test-report/nablarch/nablarch-core/12/
  (
   IFS='/'
   local tmp_dir=""
   for it in ${_remote_base_dir}; do
     tmp_dir="${tmp_dir}/${it}"
     curl -sS --digest --user ${REPO_USER}:${DEPLOY_PASSWORD} -X MKCOL \
      "${DEVELOP_REPO_URL}/test-report${tmp_dir}" > /dev/null
   done
  )

  ### Create all directory recursive. 
    # ex. create /test-report/nablarch/nablarch-core/12/subdir1, subdir2,...
  for vd in $(find ${_local_upload_dir} -type d -printf "%d %p\n" | \
              sort -k1n | awk '{print $2}' | \
              sed "s#${_local_upload_dir}##"); do
  
    if [ -z "${vd}" ]; then
         continue
    fi
  
    curl -sS --digest --user ${REPO_USER}:${DEPLOY_PASSWORD} -X MKCOL \
      ${DEVELOP_REPO_URL}/test-report/${_remote_base_dir}/${vd} > /dev/null
  done
  
  ### Finally, upload all files.
  pushd ${_local_upload_dir}
  for vf in $(find . -type f -printf "%p\n" | \
              sed "s#\./##"); do
  
    if [ -z "${vf}" ]; then
         continue
    fi
  
    curl -sS --digest --user ${REPO_USER}:${DEPLOY_PASSWORD} --upload-file ${vf} \
      ${DEVELOP_REPO_URL}/test-report/${_remote_base_dir}/${vf} > /dev/null
  done
  popd
}

remote_base_dir="${TRAVIS_REPO_SLUG}/${TRAVIS_BUILD_NUMBER}_`date +%Y%m%d_%H%M%S`"
uploadDir "${TRAVIS_BUILD_DIR}/build/reports/tests/" ${remote_base_dir}

echo
echo
echo "Save unit test report."
echo "  ${DEVELOP_REPO_URL}/test-report/${remote_base_dir}"
