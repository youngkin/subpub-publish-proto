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
%%%                     pub_proto_pub_sup               pub_proto_sub_sup
%%%                            |                               |
%%%                     ___________________              _________________
%%%                     |                  |             |                |
%%%                  *_publish       *_pub*_worker   *sub*_pool      *sub_worker
%%%
%%%         Going from left-to-right at the lowest (supervised gen_server)
%%%         level:
%%%             -   *publish is actually publish_proto_publish. It is an
%%%                 TODO it's going to be the publishing pool supervisor
%%%             -   *_pub*_worker is publish_proto_publisher_worker. It
%%%                 TODO it's going to be one of the pool workers managed
%%%                 by publish_proto_publish.
%%%             _   *sub*_pool is actually publish_proto_subscriber_pool. 
%%%                 It manages the pool of publish_proto_subscriber_worker
%%%                 gen_servers.
%%%             -   *sub_worker is actually publish_proto_subscriber_worker.
%%%                 It does the actual work of creating/subscribing to a queue
%%%                 including all the RabbitMQ callbacks.
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


