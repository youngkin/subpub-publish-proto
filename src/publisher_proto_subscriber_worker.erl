%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, NCS Pearson
%%% @doc
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

%% loop => loup_garou aka werewolf, geek humor :)
-export([loup_garou/4]).

loup_garou(Headers, Connection, Channel, QueueNameBin) ->
  receive
    start ->
      lager:info("start(~p)", [Headers]),
      {NewHeaders, NewConnection, NewChannel, NewQueueNameBin} = subscribe(Headers),
      loup_garou(NewHeaders, NewConnection, NewChannel, NewQueueNameBin);
    stop ->
      unsubscribe(Connection, Channel, QueueNameBin),
      ok;
    #'basic.consume_ok' {} ->
      loup_garou(Headers, Connection, Channel, QueueNameBin);
    #'basic.cancel' {} ->
      loup_garou(Headers, Connection, Channel, QueueNameBin);
    {#'basic.deliver'{delivery_tag=DeliveryTag}, Content} ->
      #amqp_msg{payload = _Payload, props = Props} = Content,
      _MessageId = Props#'P_basic'.correlation_id,
%%   lager:info("DELIVERED: msg=~p; delivery_tag=~p; PayLoad=~p", [MessageId, DeliveryTag, Payload]),
      amqp_channel:call(Channel,#'basic.ack'{delivery_tag=DeliveryTag}),
      loup_garou(Headers, Connection, Channel, QueueNameBin);
    UnexpectedMsg -> 
      lager:error("Unexpected message: ~p", [UnexpectedMsg]),
      loup_garou(Headers, Connection, Channel, QueueNameBin)
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
  RabbitHost = publish_proto_config:get(local_broker_address),
  {ok, Connection} = amqp_connection:start(#amqp_params_network{host=RabbitHost}),
  {ok, Channel} = amqp_connection:open_channel(Connection),
  {Connection, Channel}.

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
%%   QueueName = "publish_proto_queue",
  Prefix = "pub_proto_",
  QueueName = string:concat(Prefix, pid_to_list(self())),
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

