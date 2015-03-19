%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc This is a gen_server implementation of 
%%%      publish_proto_subscriber_worker.
%%%
%%% @end
%%% Created : 09. Mar 2015 2:25 PM
%%%-------------------------------------------------------------------
-module(publish_proto_subscriber_worker_server).
-author("uyounri").

-include("amqp_client.hrl").

-behaviour(gen_server).

%% API
-export([start_link/3]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {subscription_header, stats_process, connection, channel, queue_name_bin}).

%%%===================================================================
%%% API
%%%===================================================================

start_link(SubHeader, StatsProcess, SubId) ->
  %%
  %% Using start_link/3 to create an anonymous (i.e., unregistered) gen_server
  %%
  gen_server:start_link(?MODULE, [SubHeader, StatsProcess, SubId], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([SubHeader, StatsProcess, SubId]) ->
  %% TODO: Is this correct?
  %% To know when the parent (supervisor) shuts down. 
  %% Needed in order for terminate/2 to get called if supervisor sends a 
  %% shutdown message.
  process_flag(trap_exit, true),
  lager:info("Starting Subscriber Working for Subscription(~p)", [SubHeader]),
  {Connection, Channel, QueueNameBin} = subscribe(SubHeader, SubId),
  {ok, #state{subscription_header = SubHeader, stats_process = StatsProcess,
              connection = Connection, channel = Channel, queue_name_bin = QueueNameBin}}.

%%
%% handle_call
%%
handle_call(Request, _From, State) ->
  lager:warning("Unexpected request (~p)", [Request]),
  {reply, ok, State}.

%%
%% handle_cast
%%

%%
%% stop the gen_server and unsubscribe.
%%
handle_cast(stop, #state{connection = Connection, channel = Channel, queue_name_bin = QueueNameBin} = State) ->
  unsubscribe(Connection, Channel, QueueNameBin),
  {stop, normal, State};

%%
%% handle_cast for anything not matching the above
%%
handle_cast(Request, State) ->
  lager:warning("Unexpected request (~p)", [Request]),
  {noreply, State}.


%%
%% handle_info
%%
handle_info({ack_delivery, Channel, DeliveryTag}, State) ->
  timer:sleep(publish_proto_config:get(delayed_ack)),
  amqp_channel:cast(Channel,#'basic.ack'{delivery_tag=DeliveryTag}),
  {noreply, State};

handle_info({'basic.consume_ok', _Tag}, State) ->
  {noreply, State};

handle_info({'basic.cancel', _Tag, _NoWait}, State) ->
  {noreply, State};

handle_info({#'basic.deliver'{delivery_tag=DeliveryTag}, Content}, 
    #state{stats_process = StatsProcess, channel = Channel} = State) ->
  #amqp_msg{payload = TimeSentBin, props = Props} = Content,
  _MessageId = Props#'P_basic'.correlation_id,
  record_pub_delivery_latency(TimeSentBin, StatsProcess),
  case publish_proto_config:get(delayed_ack) of
    0 ->
      amqp_channel:call(Channel,#'basic.ack'{delivery_tag=DeliveryTag});
    N when is_integer(N), N > 0 ->
      self() ! {ack_delivery, Channel, DeliveryTag}
  end,
  {noreply, State};

%%
%% handle_info for anything not matching the above
%%
handle_info(Reason, State) ->
  lager:warning("handle_info/2 called for Reason(~p) and State(~p). This 
  subscriber is terminating", [Reason, State]),
  exit(abnormal),
  {noreply, State}.

%%
%% Called if parent (i.e., supervisor) exits, or if the supervisor directs it to stop. 
%% If this happens then everything should be cleaned up (i.e., connection, channel, and queue.
%%
terminate(Reason, #state{connection = Connection, channel = Channel, 
                        queue_name_bin = QueueNameBin} = State) ->
  lager:error("Connection or Channel exited for Reason(~p) and State(~p). This subscriber is terminating", 
    [Reason, State]),
  unsubscribe(Connection, Channel, QueueNameBin),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

subscribe(Headers, SubId) ->
  {Connection, Channel} = get_rabbit_conn_and_channel(),
  basic_qos_declare(Channel),
  ExchangeNameBin = exchange_declare(Channel),
  QueueNameBin = queue_declare(Channel, SubId),
  queue_bind(QueueNameBin, ExchangeNameBin, Channel, Headers),
  subscription_declare(QueueNameBin, Channel),
  lager:info("SUBSCRIBE: Queue=~p; Headers=~p", [QueueNameBin, Headers]),
  {Connection, Channel, QueueNameBin}.

unsubscribe(Connection, Channel, QueueNameBin) ->
  case QueueNameBin of
    <<"">> ->
      lager:warning("UNSUBSCRIBE: No subscription found"),
      ok;
    _ ->
      try
        lager:info("UNSUBSCRIBE: Queue=~p", [QueueNameBin]),
        Delete = #'queue.delete'{queue = QueueNameBin},
        lager:info("Before queue delete: Queue=~p", [QueueNameBin]),
        #'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),
        lager:info("Before channel close"),
        amqp_channel:close(Channel),
        lager:info("Before connection close"),
        amqp_connection:close(Connection),
        lager:info("UNSUBSCRIBE completed")
      catch
        %% not important that an exception occurred since this is just a best effort
        Error:Reason -> lager:warning("Unexpected exception caught
        unsubscribing 
        from a queue for Error:<<~p>> and Reason:<<~p", [Error, Reason])
      end,
      ok
  end.

get_rabbit_conn_and_channel() ->
%%   RabbitHost = publish_proto_config:get(local_broker_address),
  RabbitHost = publish_proto_config:get(broker_address),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  case publish_proto_config:get(monitor_conn_chnl) of
    true ->
      %%
      %% Don't trap_exit since with this new, supervised, implementation we want
      %% a hard-crash to trigger the supervisor restart process. We still 
      %% link so we get the exit(kill) that is needed for the hard-crash.
      %%
%%       process_flag(trap_exit, true),
      link(Connection),
      link(Channel);
    false ->
      false
  end,
  {Connection, Channel}.

%%%
%%% Defines quality-of-service parameters for the associated Channel.
%%%
basic_qos_declare(Channel) ->
  PrefetchCount = publish_proto_config:get(consumer_prefetch_count),
  BasicQos = #'basic.qos'{prefetch_size = 0, prefetch_count = PrefetchCount, global = false},
  #'basic.qos_ok'{} = amqp_channel:call(Channel, BasicQos).

%%%
%%% Registers the callback process for the provided queue and channel. This is needed
%%% in order for RabbitMQ to send messages to this process for the various callback
%%% events such as 'basic.deliver' in this process's receive loop.
%%%
subscription_declare(QueueNameBin, Channel) ->
  BasicConsume = #'basic.consume'{queue = QueueNameBin, consumer_tag = <<"">>, no_ack = false},
  #'basic.consume_ok'{consumer_tag = _SubscriptionTag} = amqp_channel:subscribe(Channel, BasicConsume, self()).

%%%
%%% Defines the queue binding parameters (i.e., the headers) for a given
%%% exchange and queue. This is used by Rabbit to associate the queue with
%%% the matching headers, if any, on a published message.
%%%
queue_bind(QueueNameBin, ExchangeNameBin, Channel, Headers) ->
  %% Get Headers from config?
  QueueBind = #'queue.bind'{queue = QueueNameBin, exchange = ExchangeNameBin, arguments = Headers},
  #'queue.bind_ok'{} = amqp_channel:call(Channel, QueueBind).

%%%
%%% Registers a name for queue that will be used later to bind headers for the queue
%%% and declare the callback process (this one) for message delivery.
%%%
queue_declare(Channel, SubId) ->
%%   QueueName = "publish_proto_queue",
  Prefix = "pub_proto_",
  QueueName = string:concat(Prefix, SubId),
  QueueNameBin = list_to_binary(QueueName),
  QueueDeclare = #'queue.declare'{queue = QueueNameBin, durable = true},
  #'queue.declare_ok'{queue = _QueueId} = amqp_channel:call(Channel, QueueDeclare),
  QueueNameBin.

%%%
%%% Declares the RabbitMQ exchange (creating it if necessary) that is associated with
%%% the queue that this that this subscriber listens to .
%%%
exchange_declare(Channel) ->
  ExchangeName = "publish_proto_exchange",
  ExchangeNameBin = list_to_binary(ExchangeName),
  ExchangeDeclare = #'exchange.declare'{exchange = ExchangeNameBin, type = <<"headers">>, durable = true},
  #'exchange.declare_ok'{} = amqp_channel:call(Channel, ExchangeDeclare),
  ExchangeNameBin.

record_pub_delivery_latency(TimeSentBin, StatsProcess) ->
  TimeSent = binary_to_term(TimeSentBin),
  TransitTimeMillis = timer:now_diff(now(), TimeSent) / 1000,
  StatsProcess ! {record_stats, TransitTimeMillis},
  ok.
