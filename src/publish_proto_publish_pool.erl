%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc  This module is the interface to RabbitMQ used for publishing.
%%%       During initialization it sets up the connection, channel,and
%%%       exchange used for publishing.
%%%
%%%       During gen_server initialization the publisher pool is 
%%%       established and waiting for publish requests. On termination
%%%       the publisher pool is stopped.
%%%
%%% @end
%%% Created : 23. Jan 2015 2:26 PM
%%%-------------------------------------------------------------------
-module(publish_proto_publish_pool).

-behaviour(gen_server).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  init/1,
  terminate/2
]).

-export([start_link/0]).

-define(SERVER, ?MODULE).

-record(state, {publisher_pids = [], next_publish_worker = 1}).

%% ====================================================================
%% API functions
%% ====================================================================

-export([publish_message/0]).

publish_message() ->
%%   lager:info("publish_proto_publish:publish_message()"),
  gen_server:call(?MODULE, publish_message).

%% ====================================================================
%% gen_server callbacks
%% ====================================================================

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  lager:info("Started publish_proto_publish gen_server"),
%%   wpool:start_pool(publisher_pool,
%%     [{workers, 10}, {worker, {publish_proto_publisher_worker, []}}]),
  PublisherPids = start_publishers(publish_proto_config:get(publishing_pool_size)),
  {ok, #state{publisher_pids = PublisherPids}}.

%%
%% Publishes to a pool of publisher workers chosen in a round-robin fashion
%%
handle_call(publish_message, _From, #state{publisher_pids = PublisherPids, next_publish_worker = NextPublishWorker} = _State) ->
%%   wpool:call(publisher_pool, publish_message),
  PublisherPid = lists:nth(NextPublishWorker, PublisherPids),
  %% TODO
  %% TODO need a receive loop here to make this call synchronous? 
  %% TODO otherwise this doesn't mirror prospero
  %% TODO
  PublisherPid ! publish_message,
  NewNextPublishWorker =
    case NextPublishWorker >= length(PublisherPids) of
      true ->
        1;
      false ->
        NextPublishWorker + 1
    end,
  {reply, ok, #state{publisher_pids = PublisherPids, next_publish_worker = NewNextPublishWorker}};
handle_call(Request, _From, State) ->
  lager:warning("Unknown call: ~p", [Request]),
  {reply, ok, State}.

handle_cast(Request, State) ->
  lager:warning("Unknown cast: ~p", [Request]),
  {noreply, State}.

%%
%% handle_info
%%
handle_info({'EXIT', _Pid, killed}, State) ->
  lager:warning("Publisher worker killed"),
  {noreply, State};
handle_info({'EXIT', _Pid, Reason}, State) ->
  lager:warning("Publisher worker exited for Reason ~p", [Reason]),
  {noreply, State};
handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

terminate(_Reason, #state{publisher_pids = PublisherPids} = _State) ->
  lager:info("TERMINATING for Reason ~p; Stopping all publisher workers", [_Reason]),
  stop_publishers(PublisherPids),
  {ok, #state{publisher_pids = []}}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

start_publishers(NumPublishers) ->
  start_publishers(NumPublishers, []).

start_publishers(0, PublisherPids) -> PublisherPids;
start_publishers(NumPublishers, PublisherPids) ->
  Placeholder = 0,
  Pid = spawn_link(publish_proto_publisher_worker, loop,
    [{Placeholder, Placeholder, Placeholder, Placeholder, Placeholder}]),
  process_flag(trap_exit, true),
  Pid ! start,
  start_publishers(NumPublishers - 1, [Pid | PublisherPids]).

stop_publishers([]) -> ok;
stop_publishers([Pid | RemainingPids]) ->
  Pid ! stop,
  stop_publishers(RemainingPids).
