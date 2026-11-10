FROM alpine:3
RUN apk add --no-cache openssh-client socat
COPY forward.sh /forward.sh
RUN sed -i 's/\r$//' /forward.sh && chmod +x /forward.sh
ENTRYPOINT ["/bin/sh", "/forward.sh"]
