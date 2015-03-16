%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc    The app consists of a pool of RabbitMQ publishers, a pool of
%%%         RabbitMQ subscribers, and a test driver that starts the
%%%         publisher and subscriber pools & then publishes messages
%%%         to the publisher pool. Various parameters of the test 
%%%         (e.g., RabbitMQ headers, RabbitMQ IP address, etc) can be 
%%%         configured via the publish_proto_config module.
%%%
%%%         The application is structured as follows:
%%%             
%%%                                  publish_proto_sup
%%%                                          |
%%%                            ________________________________
%%%                            |                               |
%%%                     pub_proto_pub_sup            pub_proto_subscriber_sup
%%%                            |                               |
%%%                publish_proto_publisher_pool    publish_proto_subscriber_pool
%%%                            |                               |
%%%                      *_pub*_worker(s)           publish_proto_subscriber_pool
%%%                                                            |
%%%                                               publish_proto_subscriber_worker_sup
%%%                                                            |
%%%                                            publish_proto_subscriber_worker_server(s)
%%%
%%%
%%%         Going from left-to-right at the lowest (supervised gen_server)
%%%         level:
%%%             -   *_pub*_worker(s) is publish_proto_publisher_worker. It
%%%                 is managed by by publish_proto_publisher_pool.
%%%             _   publish_proto_subscriber_pool (indirectly, via publish_proto_subscriber_worker_sup)
%%%                 manages the pool of publish_proto_subscriber_worker_server gen_servers.
%%%             -   publish_proto_subscriber_worker_server does the actual work of creating/subscribing 
%%%                 to a queue including all the RabbitMQ callbacks.
%%%
%%%         publish_proto_subscriber_worker_sup has a little bit more complex a role than described
%%%         above. It is used by publish_proto_subscriber_pool to create, via start_child/n, 
%%%         all the publish_proto_subscriber_worker_servers(s) specified in the configuration 
%%%         (see priv/publish_proto.config). This is done for 2 reasons:
%%%           1. So that publish_proto_subscriber_worker_server(s) can be created with arguments
%%%              (i.e, the subscription details).
%%%           2. So that publish_proto_subscriber_worker_sup can restart them automatically,
%%%              with the correct arguments, if they fail (e.g., because a RabbitMQ connection fails).
%%%
%%% @end
%%% Created : 20. Jan 2015 8:04 PM
%%%-------------------------------------------------------------------
-module(publish_proto_app).

-behaviour(application).

-export([start/2,stop/1, start_phase/3]).

-define(APP, publish_proto).
-define(INTERVAL, 5000).

start(_Type, _StartArgs) ->
    lager:info("Starting publish_proto_app"),
    publish_proto_sup:start_link().
  

stop(_State) ->
    lager:info("Stopping publish_proto_app"),
    ok.

start_phase(init, _StartType, _StartArgs) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================


