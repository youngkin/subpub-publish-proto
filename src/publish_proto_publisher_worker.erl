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

-record(state, {connection, channel, exchange_name}).

%% ====================================================================
%% API functions
%% ====================================================================
-export([publish_message/0]).

publish_message() ->
  gen_server:call(?MODULE, publish_message),
  ok.

%% ====================================================================
%% gen_server callbacks
%% ====================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  lager:info("Started publish_proto_publish gen_server"),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host="192.168.56.31"}),
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
  {ok, #state{connection = Connection, channel = Channel, exchange_name = ExchangeNameBin}}.

%%
%% handle_call
%%
handle_call(publish_message, _From,
    #state{channel = Channel, connection = _Connection, exchange_name = ExchangeName} = State) ->
  publish(Channel, ExchangeName),
  {reply, ok, State};
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
  lager:error("publish_proto_publisher_worker: TERMINATED"),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ====================================================================
%% Internal functions
%% ====================================================================

publish(Channel, ExchangeName) ->
  %% Get Headers from config?
  Headers = [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Pegasus">>}, {<<"x-match">>, longstr, <<"all">>}],
  MessageId = list_to_binary("00000d01-7b32-ab5a-71c6-d86aeffe0b40"),
  Payload = <<"foobar">>,
%%   lager:info("MESSAGE: msg=~p; Headers=~p; Payload=~p", [MessageId, Headers, Payload]),
  Publish = #'basic.publish'{exchange = ExchangeName, mandatory=true},
  amqp_channel:call(Channel, Publish, 
    #amqp_msg{payload = Payload, props = #'P_basic'{headers = Headers, correlation_id = MessageId, delivery_mode=2 }}),
  {ok, Channel}.

