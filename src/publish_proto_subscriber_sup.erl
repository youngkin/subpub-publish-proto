%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, NCS Pearson
%%% @doc
%%%
%%% @end
%%% Created : 20. Jan 2015 7:42 PM
%%%-------------------------------------------------------------------
-module(publish_proto_subscriber_sup).
-author("uyounri").

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(Mod, Type), {Mod, {Mod, start_link, []}, permanent, 5000, Type, [Mod]}).


%%%===================================================================
%%% API functions
%%%===================================================================

start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

init([]) ->
  RestartStrategy = one_for_one,
  MaxRestarts = 5,
  MaxRestartSeconds = 10,
  SupervisorFlags = {RestartStrategy, MaxRestarts, MaxRestartSeconds},
  SubPool = ?CHILD(publish_proto_subscriber_pool, worker),
  {ok, {SupervisorFlags, [SubPool]}}.


