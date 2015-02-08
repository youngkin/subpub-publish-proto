%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc  A subscriber that is a member of the subscriber pool. The
%%%       receive loop (loup_garou, bad geek joke) handles starting
%%%       and stopping subscribing (including the creation and deletion
%%%       of subscriptions). It also handles the RabbitMQ callbacks for
%%%       confirmation of a subscription creation (basic.consume_ok), 
%%%       subscription cancellation (basic.cancel), and message delivery
%%%       (basic.deliver).
%%%
%%%       The internal functions are helpers that support subscription
%%%       creation and deletion (creating connections and channels
%%%       that are used for defining the exchange and binding queues
%%%       to the exchange).
%%%
%%% @end
%%% Created : 23. Jan 2015 2:26 PM
%%%-------------------------------------------------------------------
-module(publisher_proto_subscriber_worker).
-author("uyounri").

-include("amqp_client.hrl").

%%%===================================================================
%%% API
%%%===================================================================

-export([loop/5]).

loop(ParentPid, Headers, Connection, Channel, QueueNameBin) ->
  receive
    start ->
      lager:info("start(~p)", [Headers]),
      {NewHeaders, NewConnection, NewChannel, NewQueueNameBin} = subscribe(Headers),
      loop(ParentPid, NewHeaders, NewConnection, NewChannel, NewQueueNameBin);
    stop ->
      unsubscribe(Connection, Channel, QueueNameBin),
      ok;
    #'basic.consume_ok' {} ->
      loop(ParentPid, Headers, Connection, Channel, QueueNameBin);
    #'basic.cancel' {} ->
      loop(ParentPid, Headers, Connection, Channel, QueueNameBin);
    {#'basic.deliver'{delivery_tag=DeliveryTag}, Content} ->
      #amqp_msg{payload = TimeSentBin, props = Props} = Content,
      _MessageId = Props#'P_basic'.correlation_id,
      TimeSent = binary_to_term(TimeSentBin),
      TransitTimeMillis = timer:now_diff(now(), TimeSent) / 1000,  %% convert from microsecs to millisecs
%%       lager:info("DELIVERED: msg=~p; delivery_tag=~p; TransitTime(millis)=~p", [_MessageId, DeliveryTag, TransitTimeMillis]),
      amqp_channel:call(Channel,#'basic.ack'{delivery_tag=DeliveryTag}),
      ParentPid ! {record_stats, TransitTimeMillis},
      loop(ParentPid, Headers, Connection, Channel, QueueNameBin);
    {'EXIT', What, Reason} ->
      lager:error("Connection or Channel exited (~p), this subscriber is terminating for ~p", [What, Reason]),
      self() ! stop;
    UnexpectedMsg -> 
      lager:error("Unexpected message: ~p", [UnexpectedMsg]),
      loop(ParentPid, Headers, Connection, Channel, QueueNameBin)
  after 60000 ->
    lager:warning("No message received for Queue ~p for 15 seconds", [binary_to_list(QueueNameBin)]),
    lager:warning("Process mailbox size is ~p", [process_info(self(), message_queue_len)]),
    ConnectionStatus = try amqp_connection:info_keys(Connection) of
      ConnectionInfo -> ConnectionInfo
    catch
      Error -> Error
    end,
    NextPublishSeqNo = 
      try amqp_channel:next_publish_seqno(Channel) of
        SeqNo -> SeqNo
      catch
        SeqNoError -> SeqNoError
      end,
    lager:warning("Connection status: ~p; indicates if connection is active", [ConnectionStatus]),
    lager:warning("Channel status: ~p; indicates if channel is active", [NextPublishSeqNo]),
    lager:warning("STOPPING TEST DUE TO INACTIVITY"),
    publish_proto_test_driver:stop_test()
  end.

%%%===================================================================
%%% Internal functions
%%%===================================================================

subscribe(Headers) ->
  {Connection, Channel} = get_rabbit_conn_and_channel(),
  basic_qos_declare(Channel),
  ExchangeNameBin = exchange_declare(Channel),
  QueueNameBin = queue_declare(Channel),
  queue_bind(QueueNameBin, ExchangeNameBin, Channel, Headers),
  subscription_declare(QueueNameBin, Channel),
  lager:info("SUBSCRIBE: Queue=~p; Headers=~p", [QueueNameBin, Headers]),
  {Headers, Connection, Channel, QueueNameBin}.

unsubscribe(Connection, Channel, QueueNameBin) ->
  case QueueNameBin of
    <<"">> ->
      lager:warning("UNSUBSCRIBE: No subscription found"),
      ok;
    _ -> 
      Delete = #'queue.delete'{queue = QueueNameBin},
      #'queue.delete_ok'{} = amqp_channel:call(Channel, Delete),
      lager:info("UNSUBSCRIBE: Queue=~p", [QueueNameBin]),
      amqp_channel:close(Channel),
      amqp_connection:close(Connection),
      ok
  end.

get_rabbit_conn_and_channel() ->
%%   RabbitHost = publish_proto_config:get(local_broker_address),
  RabbitHost = publish_proto_config:get(broker_address),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  process_flag(trap_exit, true),
  link(Connection),
  link(Channel),
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
queue_declare(Channel) ->
%%   QueueName = "publish_proto_queue",
  Prefix = "pub_proto_",
  QueueName = string:concat(Prefix, pid_to_list(self())),
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

