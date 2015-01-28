%% @author uyounri
%% @doc @todo Add description to publish_msgs.

-module(publish_proto_publisher_worker).

-include("amqp_client.hrl").

-behaviour(gen_server).

-export([
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  init/1,
  start_link/0,
  terminate/2
]).

-define(SERVER, ?MODULE).

-record(state, {connection, channel, exchange_name, interval_start, pub_times_list}).

%% ====================================================================
%% API functions
%% ====================================================================
-export([publish_message/0, calc_publish_time_median/1]).

publish_message() ->
  TimeoutMillis = 20000, %% Testing for amqp_channel:call taking a very long (20000), or very short (1000), time
  gen_server:call(?MODULE, publish_message, TimeoutMillis),
  ok.

%% ====================================================================
%% gen_server callbacks
%% ====================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  lager:info("Started"),
  RabbitHost = publish_proto_config:get(local_broker_address),
%%   {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  BasicQos = #'basic.qos'{prefetch_size = 0, prefetch_count = 3, global = false},
  #'basic.qos_ok'{} = amqp_channel:call(Channel, BasicQos),

  ExchangeName = "publish_proto_exchange",
  ExchangeNameBin = list_to_binary(ExchangeName),
  ExchangeDeclare = #'exchange.declare'{exchange = ExchangeNameBin, type = <<"headers">>, durable = true},
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, ExchangeDeclare),

  %% Add a blocked handler, consider return handler too
  amqp_channel:register_return_handler(Channel, self()),
%%   amqp_connection:register_blocked_handler(Channel, self()),
  {ok, #state{connection = Connection, channel = Channel, exchange_name = ExchangeNameBin, 
              interval_start = now(), pub_times_list = []}}.

%%
%% handle_call
%%
handle_call(publish_message, _From,
    #state{channel = Channel, connection = _Connection, exchange_name = ExchangeName,
            interval_start = IntStart, pub_times_list = PubTimesList} = _State) ->
  Before = now(),
  publish(Channel, ExchangeName),
  After = now(),
  PubTimeMillis = timer:now_diff(After, Before) / 1000, % convert from microsecs to millisecs
  HowLongSinceStatsLogged = timer:now_diff(Before, IntStart),
  NewState = case HowLongSinceStatsLogged of
               N when N > 5000000 -> %% log stats if more than 5 seconds has passed since the last time stats were logged
                 NewPubTimesList = [PubTimeMillis | PubTimesList],
                 AvgPubTime = calc_publish_time_avg(NewPubTimesList),
                 MedianPubTime = calc_publish_time_median(NewPubTimesList),
                 MinPubTime = lists:min(NewPubTimesList),
                 MaxPubTime = lists:max(NewPubTimesList),
                 lager:info("Publish interval stats: Min = ~p, Max = ~p, Median = ~p, Avg = ~p", 
                   [MinPubTime, MaxPubTime, MedianPubTime, AvgPubTime]),
                 #state{channel = Channel, connection = _Connection, exchange_name = ExchangeName,
                   interval_start = now(), pub_times_list = []};
               _ ->
                 #state{channel = Channel, connection = _Connection, exchange_name = ExchangeName,
                   interval_start = IntStart, pub_times_list = [PubTimeMillis | PubTimesList]}
             end,
  {reply, ok, NewState};
handle_call(Request, _From, State) ->
  lager:warning("Unknown call: ~p; State: ~p", [Request, State]),
  {reply, ok, State}.

%%
%% handle_cast
%%
handle_cast(Request, State) ->
  lager:warning("Unknown cast: ~p", [Request]),
  {noreply, State}.

%%
%% handle_info
%%
handle_info({#'basic.return'{reply_code=312}, #amqp_msg{props = #'P_basic'{correlation_id=MessageIdBin}}}, State) ->
  lager:info("MESSAGE-DISCARDED-NO-SUBSCRIBER: MsgId: ~p", [MessageIdBin]),
  {noreply, State};
%%
%% These callbacks aren't supported by amqp_client-2.7.1
%%
%% handle_info({#'connection.blocked'{}}, _State) ->
%%   lager:info("RabbitMQ CONNECTION BLOCKED!!!!"),
%%   {noreply, _State};
%% handle_info({#'connection.unblocked'{}}, _State) ->
%%   lager:info("RabbitMQ CONNECTION UNBLOCKED!!!!"),
%% {noreply, _State};

handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

terminate(_Reason, #state{channel = Channel, connection = Connection, exchange_name = _} = _State) ->
  amqp_channel:close(Channel),
  amqp_connection:close(Connection),
  lager:info("TERMINATING for Reason ~p", [_Reason]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ====================================================================
%% Internal functions
%% ====================================================================

publish(Channel, ExchangeName) ->
  Headers = publish_proto_config:get(header),
  MessageId = list_to_binary("00000d01-7b32-ab5a-71c6-d86aeffe0b40"),
  Payload = <<"foobar">>,
%%   lager:info("MESSAGE: msg=~p; Headers=~p; Payload=~p", [MessageId, Headers, Payload]),
  Publish = #'basic.publish'{exchange = ExchangeName, mandatory=true},
  amqp_channel:call(Channel, Publish, 
    #amqp_msg{payload = Payload, props = #'P_basic'{headers = Headers, correlation_id = MessageId, delivery_mode=2 }}),
  {ok, Channel}.

calc_publish_time_avg(PubTimesList) ->
  Sum = lists:sum(PubTimesList),
  _Avg = Sum / length(PubTimesList).

calc_publish_time_median(PubTimesList) ->
  SortedList = lists:sort(PubTimesList),
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
