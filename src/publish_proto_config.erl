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

%%
%% TODO: Change to a proplists implementation?
%%

get(Key) ->
  case Key of
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
    delayed_ack ->
      {ok, DelayedAck} = application:get_env(publish_proto, delayed_ack),
      DelayedAck;
    monitor_conn_chnl ->
      {ok, MonitorConnChannel} = application:get_env(publish_proto, monitor_conn_chnl),
      MonitorConnChannel;
    inter_publish_pause_millis ->
      {ok, PauseInMillis} = application:get_env(publish_proto, inter_publish_pause_millis),
      PauseInMillis;
    subscriber_timeout_millis ->
      {ok, SubscriberTimeoutMillis} = application:get_env(publish_proto, subscriber_timeout_millis),
      SubscriberTimeoutMillis;
    stats_collection_interval_millis ->
      {ok, StatsCollectionIntervalMillis} = application:get_env(publish_proto, stats_collection_interval_millis),
      StatsCollectionIntervalMillis;
    subscriber_headers ->
      {ok, Headers} = application:get_env(publish_proto, subscriber_headers),
      Headers;
    publish_header ->
      {ok, Header} = application:get_env(publish_proto, publish_header),
      Header;
    _ -> erlang:error(key_not_found)
  end.

