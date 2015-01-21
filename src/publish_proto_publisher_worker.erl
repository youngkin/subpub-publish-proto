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
  lager:info("publish_proto_publisher_worker:publish_message()"),
  gen_server:call(?MODULE, start_publishing),
  ok.

%% ====================================================================
%% gen_server callbacks
%% ====================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  lager:info("Started publish_proto_publish"),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host="192.168.56.31"}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  BasicQos = #'basic.qos'{prefetch_size = 0, prefetch_count = 3, global = false},
  #'basic.qos_ok'{} = amqp_channel:call(Channel, BasicQos),

  ExchangeName = "publish_proto_exchange",
  ExchangeNameBin = list_to_binary(ExchangeName),
  ExchangeDeclare = #'exchange.declare'{exchange = ExchangeNameBin, type = <<"headers">>, durable = true},
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, ExchangeDeclare),

  %% Add a blocked handler, consider return handler too

  {ok, #state{connection = Connection, channel = Channel, exchange_name = ExchangeNameBin}}.

handle_call(start_publishing, _From, #state{channel = Channel, connection = _Connection, exchange_name = ExchangeName} = State) ->
  lager:info("Begin publishing"),
  publish(Channel, ExchangeName),
  {reply, ok, Channel};
handle_call(Request, _From, State) ->
  lager:warning("Unknown call: ~p", [Request]),
  {reply, ok, State}.

handle_cast(Request, State) ->
  lager:warning("Unknown cast: ~p", [Request]),
  {noreply, State}.

handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%% ====================================================================
%% Internal functions
%% ====================================================================

publish(Channel, ExchangeName) ->

  %% Publish a message(s)
  %% Get Headers from config?
  Headers = [{<<"str">>, binary, <<"foo">>}, {<<"int">>, binary, <<"123">>}, {<<"x-match">>, longstr, <<"all">>}],
  MessageId = list_to_binary("1234"),
  Payload = <<"foobar">>,
  lager:info("Publish msg: ~p; With Headers: ~p", [Payload, Headers]),
  Publish = #'basic.publish'{exchange = ExchangeName, mandatory=true},
  amqp_channel:call(Channel, Publish, 
    #amqp_msg{payload = Payload, props = #'P_basic'{headers = Headers, correlation_id = MessageId, delivery_mode=2 }}),

  %%
  %% Now using push model via subscription. See handle_info/2 for implementation
  %%
%%   %% Get the message back from the queue
%%   Get = #'basic.get'{queue = QueueId},
%%   {#'basic.get_ok'{delivery_tag = Tag}, Content} = amqp_channel:call(Channel, Get),
%%
%%   %% Do something with the message payload
%%   %% (some work here)
%%   lager:info("Received msg: ~p", [Content]),
%%
%%   %% Ack the message
%%   amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
%%
%%   %% Delete the queue
%% %%   Delete = #'queue.delete'{queue = Q},
%% %%   #'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),
%%
%%   %% Close the channel
%%   amqp_channel:close(Channel),
%%   %% Close the connection
%%   amqp_connection:close(Connection),

  {ok, Channel}.

