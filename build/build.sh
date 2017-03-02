#!/bin/bash

set -e

ROOT=$(pwd)
VERSION=$1
LLVM_BASE=http://llvm.org/svn/llvm-project
if echo ${VERSION} | grep 'trunk'; then
    TAG=trunk
    VERSION=trunk-$(date +%Y%m%d)
else
    TAG=tags/RELEASE_$(echo ${VERSION} | sed 's/\.//g')/final
fi

OUTPUT=/root/clang-${VERSION}.tar.xz
S3OUTPUT=""
if echo $2 | grep s3://; then
    S3OUTPUT=$2
else
    OUTPUT=${2-/root/clang-${VERSION}.tar.xz}
fi

STAGING_DIR=$(pwd)/staging
rm -rf ${STAGING_DIR}
mkdir -p ${STAGING_DIR}

svn co ${LLVM_BASE}/llvm/${TAG} llvm
pushd llvm/tools
svn co ${LLVM_BASE}/cfe/${TAG} clang
popd
pushd llvm/projects
svn co ${LLVM_BASE}/libcxx/${TAG} libcxx
svn co ${LLVM_BASE}/libcxxabi/${TAG} libcxxabi
popd
git clone http://llvm.org/git/polly.git llvm/tools/polly

mkdir build
cd build
cmake -G "Unix Makefiles" ../llvm \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DCMAKE_INSTALL_PREFIX:PATH=/root/staging

make -j$(nproc) install

# Compress all the binaries with upx
upx -4 ${STAGING_DIR}/bin/* || true

tar Jcf ${OUTPUT} --transform "s,^./,./clang-${VERSION}/," -C ${STAGING_DIR} .

if [[ ! -z "${S3OUTPUT}" ]]; then
    s3cmd put --rr ${OUTPUT} ${S3OUTPUT}
fi
