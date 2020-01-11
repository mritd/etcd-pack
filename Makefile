BUILD_VERSION   := $(shell cat version)

all: clean
	docker run --rm -it -v `pwd`:/etcd-deb mritd/fpm bash -c "cd /etcd-deb && bash ./build.sh"

release: all
	ghr -u mritd -t ${GITHUB_RELEASE_TOKEN} -replace -recreate --debug v${BUILD_VERSION} *.deb

pre-release: all
	ghr -u mritd -t ${GITHUB_RELEASE_TOKEN} -replace -recreate -prerelease --debug v${BUILD_VERSION} *.deb

clean:
	rm -rf *.deb *.tar.gz

.PHONY : all release pre-release clean
