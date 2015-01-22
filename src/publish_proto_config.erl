%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, NCS Pearson
%%% @doc
%%%
%%% @end
%%% Created : 22. Jan 2015 7:37 AM
%%%-------------------------------------------------------------------
-module(publish_proto_config).
-author("uyounri").

%% API
-export([get/1]).

get(Key) ->
  case Key of
    local_broker_address -> "192.168.56.31"; % RabbitMQ on local VM
    remote_broker_address -> "10.199.22.69"; % subpubpf-ramq-0002 in usw2a
    _ -> erlang:error(key_not_found)
  end.
