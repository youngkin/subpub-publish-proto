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
    %% Local RabbitMQ address
%%     broker_address -> "192.168.56.31"; % RabbitMQ on local VM
    %% Remote RabbitMQ address
%%     broker_address -> "10.199.28.206"; % subpubpf-ramq-0002 in usw2a
    broker_address ->
      {ok, Amqp} = application:get_env(publish_proto, amqp),
      {broker_address, BrokerAddress} = lists:keyfind(broker_address, 1, Amqp),
      BrokerAddress;
    consumer_prefetch_count ->
      {ok, Amqp} = application:get_env(publish_proto, amqp),
      {consumer_prefetch_count, PrefetchCount} = lists:keyfind(consumer_prefetch_count, 1, Amqp),
      PrefetchCount;
    publishing_pool_size ->
      {ok, PoolSize} = application:get_env(publish_proto, publishing_pool_size),
      PoolSize;
    inter_publish_pause -> 
      {ok, PauseInMillis} = application:get_env(publish_proto, inter_publish_pause),
      PauseInMillis;
    subscriber_headers ->
      {ok, Headers} = application:get_env(publish_proto, subscriber_headers),
      Headers;
%%     headers ->  [
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Ignore.This">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Ignore.This.2">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Ignore.This.3">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Ignore.This.4">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}],
%% 
%%       [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%         {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%         {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%         {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}]
%%             ];
    
    %% Large header
    publish_header ->
      {ok, Header} = application:get_env(publish_proto, publish_header),
      Header;
%%     header ->  [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Dragnet">>},
%%       {<<"System">>, binary, <<"Cronica">>}, {<<"ClientString">>, binary, <<"kaplan">>},
%%       {<<"Client">>, binary, <<"404310">>}, {<<"UserId">>, binary, <<"31674242">>},
%%       {<<"CourseId">>, binary, <<"11008988">>}, {<<"x-match">>, longstr, <<"all">>}];

    _ -> erlang:error(key_not_found)
  end.

