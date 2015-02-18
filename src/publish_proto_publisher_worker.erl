%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc  This module is the interface to RabbitMQ used for publishing.
%%%       During initialization it sets up the connection, channel,and
%%%       exchange used for publishing.
%%%
%%% @end
%%% Created : 23. Jan 2015 2:26 PM
%%%-------------------------------------------------------------------
-module(publish_proto_publisher_worker).

-include("amqp_client.hrl").

%% ====================================================================
%% API functions
%% ====================================================================

-export([loop/1]).

loop( State = {ParentPid, Connection, Channel, _ExchangeNameBin} ) ->
  receive
    start ->
      lager:info("START"),
      {ok, {NewConnection, NewChannel, NewExchangeNameBin}} = initialize_rabbit(),
      loop({ParentPid, NewConnection, NewChannel, NewExchangeNameBin});
    publish_message ->
      NewState = publish_message(State),
      loop(NewState);
    stop ->
      unlink(Channel),
      unlink(Connection),
      amqp_channel:close(Channel),
      amqp_connection:close(Connection),
      lager:info("TERMINATING"),
      ok;
    {'EXIT', What, Reason} ->
      lager:error("Connection or Channel exited (~p), this publisher is terminating for ~p", [What, Reason]),
      self() ! stop;
    %%
    %% RabbitMQ callbacks.
    %% The next 2 RabbitMQ callbacks aren't supported by amqp_client-2.7.1,
    %% but they would be useful.
    %%
    %% {#'connection.blocked'{}} -> do_something...
    %% {#'connection.unblocked'{}} -> do_something...
    %%
    {#'basic.return'{reply_code=312}, #amqp_msg{props = #'P_basic'{correlation_id=MessageIdBin}}} ->
      lager:info("MESSAGE-DISCARDED-NO-SUBSCRIBER: MsgId: ~p", [MessageIdBin]),
      loop(State)
  end.

%% ====================================================================
%% Internal functions
%% ====================================================================

publish_message( {ParentPid, Connection, Channel, ExchangeNameBin} ) ->
  Before = now(),
  publish(Channel, ExchangeNameBin),
  After = now(),
  %% TODO: Add back millis, or keep micros?
%%   PubDurationMillis = timer:now_diff(After, Before) / 1000, % convert from microsecs to millisecs
  PubDurationMicros = timer:now_diff(After, Before),
  ParentPid ! {record_stats, PubDurationMicros},
  {ParentPid, Connection, Channel, ExchangeNameBin}.

publish(Channel, ExchangeName) ->
  Header = publish_proto_config:get(publish_header),
  MessageId = <<"00000d01-7b32-ab5a-71c6-d86aeffe0b40">>,
  Payload = term_to_binary(erlang:now()),
%%   lager:info("MESSAGE: msg=~p; Headers=~p; Payload=~p", [MessageId, Headers, Payload]),
  Publish = #'basic.publish'{exchange = ExchangeName, mandatory=true},
  amqp_channel:call(Channel, Publish, 
    #amqp_msg{payload = Payload, props = #'P_basic'{headers = Header, correlation_id = MessageId, delivery_mode=2 }}),
  {ok, Channel}.

initialize_rabbit() ->
  lager:info("Started"),
  RabbitHost = publish_proto_config:get(broker_address),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  case publish_proto_config:get(monitor_conn_chnl) of
    true ->
      process_flag(trap_exit, true),
      link(Connection),
      link(Channel);
    false ->
      false
  end,
  BasicQos = #'basic.qos'{prefetch_size = 0, prefetch_count = 3, global = false},
  #'basic.qos_ok'{} = amqp_channel:call(Channel, BasicQos),

  ExchangeName = "publish_proto_exchange",
  ExchangeNameBin = list_to_binary(ExchangeName),
  ExchangeDeclare = #'exchange.declare'{exchange = ExchangeNameBin, type = <<"headers">>, durable = true},
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, ExchangeDeclare),

  %% Add un/blocked handlers in addition to the return handler. Unfortunately
  %% the current amqp library used doesn't support blocked handlers. These
  %% handlers are included below, but commented out since they're not supported.
  %% They may be added back if an updated version of the amqp library is used.
%%   amqp_connection:register_blocked_handler(Channel, self()),

  %% Supports notification of undeliverable messages (i.e., no subscriber).
  amqp_channel:register_return_handler(Channel, self()),
  {ok, {Connection, Channel, ExchangeNameBin}}.

