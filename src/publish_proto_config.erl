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
    headers ->  [
      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Ignore.This">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Ignore.This.2">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Ignore.This.3">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Ignore.This.4">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],

      [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
        {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
        {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
        {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}]
            ];
    header ->  [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
      {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
      {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
      {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}];
%%     header ->  [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"x-match">>, longstr, <<"all">>}];
    _ -> erlang:error(key_not_found)
  end.

