%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc  Supervises the subscriber pool.
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
  %% No restarts, but if there were, all would be restarted together
  RestartStrategy = one_for_all,
  MaxRestarts = 0,
  MaxRestartSeconds = 1,
  SupervisorFlags = {RestartStrategy, MaxRestarts, MaxRestartSeconds},
  SubSupervisor = ?CHILD(publish_proto_subscriber_worker_sup, supervisor),
  SubPool = ?CHILD(publish_proto_subscriber_pool, worker),
  {ok, {SupervisorFlags, [SubSupervisor, SubPool]}}.


