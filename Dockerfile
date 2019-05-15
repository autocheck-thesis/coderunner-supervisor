FROM bitwalker/alpine-elixir:1.8.1

RUN apk add docker

ADD mix.exs mix.lock ./

ENV MIX_ENV=prod

RUN mix deps.get
ADD . ./
RUN mix compile

# WORKDIR cd /coderunner-supervisor

# CMD mix test_suite