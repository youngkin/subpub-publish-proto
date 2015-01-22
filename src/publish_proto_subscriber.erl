%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, NCS Pearson
%%% @doc
%%%
%%% @end
%%% Created : 20. Jan 2015 8:04 PM
%%%-------------------------------------------------------------------
-module(publish_proto_subscriber).
-author("uyounri").

-behaviour(gen_server).

-include("amqp_client.hrl").

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {connection, channel, queue_name}).

%%%===================================================================
%%% API
%%%===================================================================
-export([subscribe/0, unsubscribe/0]).

subscribe() ->
  gen_server:call(?MODULE, subscribe),
  ok.

unsubscribe() ->
  gen_server:call(?MODULE, unsubscribe),
  ok.


start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
  %% Start a network connection and  open channel
  RabbitHost = publish_proto_config:get(local_broker_address),
%%   {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  {ok, #state{connection = Connection, channel = Channel, queue_name = <<"">>}}.

%%
%% handle_call
%%
handle_call(subscribe, _From, #state{channel = Channel, connection = _Connection} = State) ->
  basic_qos_declare(Channel),
  ExchangeNameBin = exchange_declare(Channel),
  QueueNameBin = queue_declare(Channel),
  Headers = [{<<"MessageType">>, binary, <<"Some.Msg.Type">>}, {<<"SubSystem">>, binary, <<"Pegasus">>}, {<<"x-match">>, longstr, <<"all">>}],
  queue_bind(QueueNameBin, ExchangeNameBin, Channel, Headers),
  subscription_declare(QueueNameBin, Channel),
  lager:info("SUBSCRIBE: Queue=~p; Headers=~p", [QueueNameBin, Headers]),
  {reply, ok, State#state{queue_name = QueueNameBin}};

handle_call(unsubscribe, _From, #state{queue_name = <<"">>} = State) ->
  lager:warning("UNSUBSCRIBE: No subscription found"),
  {reply, ok, State#state{queue_name = <<"">>}};
handle_call(unsubscribe, _From, #state{channel = Channel, connection = _Connection, queue_name = QueueNameBin} = State) ->
  Delete = #'queue.delete'{queue = QueueNameBin},
  #'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),
  lager:info("UNSUBSCRIBE: Queue=~p", [QueueNameBin]),
  {reply, ok, State#state{queue_name = <<"">>}};
handle_call(_Request, _From, State) ->
  lager:warning("Unknown call: ~p", [_Request]),
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
handle_info({'basic.consume_ok', _Tag}, State) ->
  {noreply, State};
handle_info({'basic.cancel', _Tag, _NoWait}, State) ->
  {noreply, State};
handle_info({#'basic.deliver'{delivery_tag=DeliveryTag}, Content},
    #state{channel = Channel, connection = _Connection, queue_name = _} = State) ->
  #amqp_msg{payload = _Payload, props = Props} = Content,
  _MessageId = Props#'P_basic'.correlation_id,
%%   lager:info("DELIVERED: msg=~p; delivery_tag=~p; PayLoad=~p", [MessageId, DeliveryTag, Payload]),
  amqp_channel:call(Channel,#'basic.ack'{delivery_tag=DeliveryTag}),
  {noreply, State};
handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

terminate(_Reason, #state{connection = Connection, channel = Channel, queue_name = _} = _State) ->
  amqp_channel:close(Channel),
  amqp_connection:close(Connection),
  lager:error("publish_proto_subscriber: TERMINATED"),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

basic_qos_declare(Channel) ->
  BasicQos = #'basic.qos'{prefetch_size = 0, prefetch_count = 3, global = false},
  #'basic.qos_ok'{} = amqp_channel:call(Channel, BasicQos).

subscription_declare(QueueNameBin, Channel) ->
  BasicConsume = #'basic.consume'{queue = QueueNameBin, consumer_tag = <<"">>, no_ack = false},
  #'basic.consume_ok'{consumer_tag = _SubscriptionTag} = amqp_channel:subscribe(Channel, BasicConsume, self()).

queue_bind(QueueNameBin, ExchangeNameBin, Channel, Headers) ->
  %% Get Headers from config?
  QueueBind = #'queue.bind'{queue = QueueNameBin, exchange = ExchangeNameBin, arguments = Headers},
  #'queue.bind_ok'{} = amqp_channel:call(Channel, QueueBind).

queue_declare(Channel) ->
  QueueName = "publish_proto_queue",
  QueueNameBin = list_to_binary(QueueName),
  QueueDeclare = #'queue.declare'{queue = QueueNameBin, durable = true},
  #'queue.declare_ok'{queue = _QueueId} = amqp_channel:call(Channel, QueueDeclare),
  QueueNameBin.

exchange_declare(Channel) ->
  ExchangeName = "publish_proto_exchange",
  ExchangeNameBin = list_to_binary(ExchangeName),
  ExchangeDeclare = #'exchange.declare'{exchange = ExchangeNameBin, type = <<"headers">>, durable = true},
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, ExchangeDeclare),
  ExchangeNameBin.

