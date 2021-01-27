BUILD_VERSION   := $(shell cat version)

all: clean build

build:
    bash build.sh ${BUILD_VERSION}

release: all
    ghr -u mritd -t ${GITHUB_TOKEN} -replace -recreate --debug -name "Bump v${BUILD_VERSION}" v${BUILD_VERSION} *.run

pre-release: all
    ghr -u mritd -t ${GITHUB_TOKEN} -replace -recreate -prerelease -name "Bump v${BUILD_VERSION}" --debug v${BUILD_VERSION} *.run

clean:
    rm -rf *.run

.PHONY: all build release pre-release clean
