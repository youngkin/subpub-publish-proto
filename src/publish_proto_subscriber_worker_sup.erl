%%%-------------------------------------------------------------------
%%% @author uyounri
%%% @copyright (C) 2015, Richard Youngkin
%%% @doc
%%%
%%% @end
%%% Created : 10. Mar 2015 9:12 AM
%%%-------------------------------------------------------------------
-module(publish_proto_subscriber_worker_sup).
-author("uyounri").

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).


%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

init([]) ->
  %%
  %% Want failed subscribers to be restarted so that they can continue to 
  %% receive messages from RabbitMQ as quickly as possible. Persistent
  %% failures indicate that something is really wrong so terminate if 
  %% restarted too many times in too short an interval.
  %%
  RestartStrategy = simple_one_for_one,
  MaxRestarts = 5,
  MaxRestartSeconds = 10,
  SupervisorFlags = {RestartStrategy, MaxRestarts, MaxRestartSeconds},

  SubscriberWorker = ?CHILD(publish_proto_subscriber_worker_server, worker),

  {ok, {SupervisorFlags, [SubscriberWorker]}}.


%%%===================================================================
%%% Internal functions
%%%===================================================================
