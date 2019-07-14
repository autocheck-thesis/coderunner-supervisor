FROM bitwalker/alpine-elixir:1.8.1 AS builder

ARG APP_NAME=coderunner_supervisor
ARG APP_VSN=0.1.0
ARG MIX_ENV=prod

ENV APP_NAME=${APP_NAME} \
  APP_VSN=${APP_VSN} \
  MIX_ENV=${MIX_ENV}

COPY coderunner-supervisor /opt/coderunner-supervisor
COPY language /opt/language

WORKDIR /opt/coderunner-supervisor

RUN mix do deps.get, deps.compile, compile

RUN mkdir -p /opt/built && \
  mix distillery.release --verbose && \
  cp _build/${MIX_ENV}/rel/${APP_NAME}/releases/${APP_VSN}/${APP_NAME}.tar.gz /opt/built/ && \
  cd /opt/built && \
  tar -xzf ${APP_NAME}.tar.gz && \
  rm ${APP_NAME}.tar.gz

FROM alpine:3.9

ARG APP_NAME=coderunner_supervisor

RUN apk add docker bash openssl-dev

ENV REPLACE_OS_VARS=true \
  APP_NAME=${APP_NAME}

WORKDIR /opt/app

COPY --from=builder /opt/built .
COPY coderunner-supervisor/entrypoint.sh .

ENTRYPOINT ["/opt/app/entrypoint.sh"]
CMD []