.PHONY: server
server:
	hugo server --disableFastRender

.PHONY: public
public:
	hugo --baseUrl="https://hanamichi.wiki"

.PHONY: push-public
push-public:
	git subtree push --prefix=public origin master
