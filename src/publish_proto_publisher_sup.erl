%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc  Manages the gen_server which manages the pool of publishing
%%%       workers.
%%%
%%% @end
%%% Created : 19. Jan 2015 9:44 AM
%%%-------------------------------------------------------------------
-module(publish_proto_publisher_sup).
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

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec(init(Args :: term()) ->
  {ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
    MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
    [ChildSpec :: supervisor:child_spec()]
  }} |
  ignore |
  {error, Reason :: term()}).
init([]) ->
  RestartStrategy = rest_for_one,
  MaxRestarts = 5,
  MaxRestartSeconds = 10,
  SupervisorStrategy = {RestartStrategy, MaxRestarts, MaxRestartSeconds},
  
  PublishingPool = ?CHILD(publish_proto_publisher_pool, worker),
  {ok, {SupervisorStrategy, [PublishingPool]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
