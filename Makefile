BUILD_VERSION   := $(shell cat version)

all: clean etcd cfssl

cfssl:
	docker run --rm -it -v `pwd`/dist:/dist mritd/cfssl-build ./build.sh

etcd:
	docker run --rm -it -v `pwd`:/etcd-deb mritd/fpm bash -c "cd /etcd-deb && bash ./build.sh"

release: all
	ghr -u mritd -t ${GITHUB_TOKEN} -replace -recreate --debug v${BUILD_VERSION} dist 

pre-release: all
	ghr -u mritd -t ${GITHUB_TOKEN} -replace -recreate -prerelease --debug v${BUILD_VERSION} dist

clean:
	rm -rf dist etcd*.tar.gz

.PHONY: all release pre-release clean
