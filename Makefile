.PHONY: server
server:
	hugo server

.PHONY: public
public:
	hugo --baseUrl="https://hanamichi.wiki"
