VERSION 0.8
PROJECT jahands/docker

build:
	FROM docker.io/library/ruby:3.2.2-alpine3.18
	WORKDIR /work
	COPY Gemfile .
	COPY imap-backup.gemspec .
	COPY lib/imap/backup/version.rb lib/imap/backup/
	RUN \
		apk add alpine-sdk && \
		gem install bundler --version "2.4.21" && \
		BUNDLE_WITHOUT=development bundle install
	SAVE ARTIFACT /usr/local/bundle

docker:
	FROM docker.io/library/ruby:3.2.2-alpine3.18
	COPY --dir +build/bundle /usr/local/
	WORKDIR /app
	# See .earthlyignore (copied from .containerignore)
	# for details on what gets copied here.
	COPY . .
	ENV PATH=${PATH}:/app/bin
	CMD ["imap-backup", "backup", "-c", "/config/imap-backup.json"]
	ARG DOCKER_TAG='unknown'
	SAVE IMAGE --push gitea.uuid.rocks/geobox/imap-backup:$DOCKER_TAG
