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

loop( State = {Connection, Channel, _ExchangeNameBin, _IntervalStart, _PubTimesList} ) ->
  receive
    start ->
      lager:info("START"),
      {ok, NewState} = initialize_rabbit(),
      loop(NewState);
    publish_message ->
      NewState = publish_message(State),
      loop(NewState);
    stop ->
      amqp_channel:close(Channel),
      amqp_connection:close(Connection),
      lager:info("TERMINATING"),
      %% TODO stop/exit here?
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

publish_message( {Connection, Channel, ExchangeNameBin, StatsIntervalStart, PubDurationsList} ) ->
  Before = now(),
  publish(Channel, ExchangeNameBin),
  After = now(),
  PubDurationMillis = timer:now_diff(After, Before) / 1000, % convert from microsecs to millisecs
  HowLongSinceStatsLogged = timer:now_diff(Before, StatsIntervalStart),
  NewState = case HowLongSinceStatsLogged of
               N when N > 5000000 -> %% log stats if more than 5 seconds has passed since the last time stats were logged
                 NewPubDurationsList = [PubDurationMillis | PubDurationsList],
                 AvgPubTime = calc_publish_time_avg(NewPubDurationsList),
                 MedianPubTime = calc_publish_time_median(NewPubDurationsList),
                 MinPubTime = lists:min(NewPubDurationsList),
                 MaxPubTime = lists:max(NewPubDurationsList),
                 lager:info("Publish interval stats: Min = ~p, Max = ~p, Median = ~p, Avg = ~p", 
                   [MinPubTime, MaxPubTime, MedianPubTime, AvgPubTime]),
                 {Connection, Channel, ExchangeNameBin, _StatsIntervalStart = now(), _PubDurationsList = []};
               _ ->
                 {Connection, Channel, ExchangeNameBin, StatsIntervalStart, [PubDurationMillis | PubDurationsList]}
             end,
  NewState.

publish(Channel, ExchangeName) ->
  Header = publish_proto_config:get(publish_header),
  MessageId = <<"00000d01-7b32-ab5a-71c6-d86aeffe0b40">>,
  Payload = <<"foobar">>,
%%   lager:info("MESSAGE: msg=~p; Headers=~p; Payload=~p", [MessageId, Headers, Payload]),
  Publish = #'basic.publish'{exchange = ExchangeName, mandatory=true},
  amqp_channel:call(Channel, Publish, 
    #amqp_msg{payload = Payload, props = #'P_basic'{headers = Header, correlation_id = MessageId, delivery_mode=2 }}),
  {ok, Channel}.

calc_publish_time_avg(PubDurationsList) ->
  Sum = lists:sum(PubDurationsList),
  _Avg = Sum / length(PubDurationsList).

calc_publish_time_median(PubDurationsList) ->
  SortedList = lists:sort(PubDurationsList),
  Len = length(SortedList),
  Median = case (Len rem 2) of
    0 -> 
      MedianPosition = round(Len / 2),
      {List1, List2} = lists:split(MedianPosition, SortedList),
      Num1 = lists:last(List1),
      [Num2 | _] = List2,
      (Num1 + Num2) / 2;
    _ -> 
      MedianPosition = round(Len / 2),
      lists:nth(MedianPosition, SortedList)
  end,
  Median.

initialize_rabbit() ->
  lager:info("Started"),
  RabbitHost = publish_proto_config:get(broker_address),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  process_flag(trap_exit, true),
  link(Connection),
  link(Channel),
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
  {ok, {Connection, Channel, ExchangeNameBin, _StatsIntervalStart = now(), _PubDurationsList = []}}.

