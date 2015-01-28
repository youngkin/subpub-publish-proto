%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc
%%%
%%% @end
%%% Created : 20. Jan 2015 8:04 PM
%%%-------------------------------------------------------------------
-module(publish_proto_subscriber_pool).
-author("uyounri").

-behaviour(gen_server).

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

-record(state, {subscriber_pids = [], headers = []}).

%%%===================================================================
%%% API
%%%===================================================================
-export([start/0, stop/0]).

start() ->
  gen_server:call(?MODULE, start),
  ok.

stop() ->
  gen_server:call(?MODULE, stop),
  ok.


start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
  {ok, #state{subscriber_pids = []}}.

%%
%% handle_call
%%
handle_call(start, _From, _State) ->
  Headers = publish_proto_config:get(headers),
  SubscriberPids = start_subscribers(Headers),
  lager:info("Started Subscribers, Pids = ~p", [SubscriberPids]),
  {reply, ok, #state{subscriber_pids = SubscriberPids}};
handle_call(stop, _From, #state{subscriber_pids = SubscriberPids} = _State) ->
  stop_subscribers(SubscriberPids),
  lager:info("Stopped Subscribers, Pids = ~p", [SubscriberPids]),
  {reply, ok, #state{subscriber_pids = []}};
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
handle_info({'EXIT', _Pid, killed}, State) ->
  lager:warning("Subscriber worked killed"),
  {noreply, State};
handle_info({'EXIT', _Pid, Reason}, State) ->
  lager:warning("Subscriber worker exited for Reason ~p", [Reason]),
  {noreply, State};
handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

terminate(Reason, State) ->
  lager:info("TERMINATING for reason: ~p", [Reason]),
  {ok, State}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

start_subscribers(Headers) ->
  start_subscribers(Headers, []).

start_subscribers([], SubscriberPids) -> SubscriberPids;
start_subscribers([Header | RemainingHeaders], SubscriberPids) ->
  Empty = 0,
  Pid = spawn_link(publisher_proto_subscriber_worker, loup_garou, [Header, Empty, Empty, Empty]),
  process_flag(trap_exit, true),
  Pid ! start,
  start_subscribers(RemainingHeaders, [Pid | SubscriberPids]).

stop_subscribers([]) -> ok;
stop_subscribers([Pid | RemainingPids]) ->
  Pid ! stop,
  stop_subscribers(RemainingPids).

