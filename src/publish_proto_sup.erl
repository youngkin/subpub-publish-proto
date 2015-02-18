%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc  This is the top level application supervisor. It manages
%%        the supervisors that manage publishing and subscribing.
%%%
%%% @end
%%% Created : 19. Jan 2015 9:44 AM
%%%-------------------------------------------------------------------
-module(publish_proto_sup).
-author("uyounri").

-behaviour(supervisor).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% API functions
%%%===================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%% ===================================================================
%%% Supervisor callbacks
%%% ===================================================================

init([]) ->
  RestartStrategy = rest_for_one,
  MaxRestarts = 5,
  MaxRestartSeconds = 10,
  SupervisorStrategy = {RestartStrategy, MaxRestarts, MaxRestartSeconds},

  PublisherSupervisor = ?CHILD(publish_proto_publisher_sup, supervisor),
  SubscriberSupervisor = ?CHILD(publish_proto_subscriber_sup, supervisor),
  TestDriver = ?CHILD(publish_proto_test_driver, worker),
  {ok, {SupervisorStrategy, [PublisherSupervisor, SubscriberSupervisor, TestDriver]}}.
