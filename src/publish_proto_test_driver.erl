%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, NCS Pearson
%%% @doc
%%%
%%% @end
%%% Created : 21. Jan 2015 2:37 PM
%%%-------------------------------------------------------------------
-module(publish_proto_test_driver).
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

-record(state, {test_pid}).

%%%===================================================================
%%% API
%%%===================================================================

-export([start_test/0, stop_test/0]).

start_test() ->
  publish_proto_subscriber_pool:start(),
  timer:sleep(100), % give subscribers a chance to register before starting publisher
  gen_server:cast(?MODULE, start_test),
  ok.

stop_test() ->
  gen_server:call(?MODULE, stop_test),
  timer:sleep(1000), % give publisher a chance to stop before stopping subs
  publish_proto_subscriber_pool:stop(),
  ok.

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
  {ok, #state{}}.

%%
%% handle_call
%%
handle_call(stop_test, _From, #state{test_pid = TestPid} = _State) ->
  exit(TestPid, kill),
  lager:info("STOPPED TEST"),
  {reply, ok, #state{test_pid = <<"">>}};
handle_call(_Request, _From, State) ->
  lager:info("Unexpected Request ~p", [_Request]),
  {reply, ok, State}.

%%
%% handle_cast
%%
handle_cast(start_test, _State) ->
  Pid = spawn_link(fun run_test/0),
  lager:info("Starting test: PID = ~p", [Pid]),
  {noreply, #state{test_pid = Pid}};
handle_cast(_Request, State) ->
  {noreply, State}.

%%
%% handle_info
%%
handle_info(_Info, State) ->
  {noreply, State}.

terminate(Reason, _State) ->
  lager:info("TERMINATING for Reason: ~p", [Reason]),
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

run_test() ->
%%   timer:sleep(1),
  publish_proto_publisher_worker:publish_message(),
  run_test().
  