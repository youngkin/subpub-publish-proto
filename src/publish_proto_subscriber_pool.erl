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
-define(PUBLISH_STATS_DELAY, 30000). %% 30 seconds

-record(state, {subscriber_pids = [], headers = [], transit_duration_list = [], subscriber_registry}).

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
  erlang:send_after(?PUBLISH_STATS_DELAY, self(), publish_stats),
  {ok, #state{subscriber_registry = dict:new()}}.

%%
%% handle_call
%%
handle_call(start, _From, #state{subscriber_registry = SubscriberRegistry} = State) ->
  Headers = publish_proto_config:get(subscriber_headers),
  {SubscriberPids, NewSubscriberRegistry} = start_subscribers(Headers, SubscriberRegistry),
  lager:info("Started Subscribers, Pids = ~p", [SubscriberPids]),
  {reply, ok, State#state{subscriber_pids = SubscriberPids, subscriber_registry = NewSubscriberRegistry}};

handle_call(stop, _From, #state{subscriber_pids = SubscriberPids} = _State) ->
  stop_subscribers(SubscriberPids),
  lager:info("Stopped Subscribers, Pids = ~p", [SubscriberPids]),
  {reply, ok, #state{subscriber_pids = [], subscriber_registry = dict:new()}};

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
handle_info(publish_stats, #state{transit_duration_list = TransitTimeDurationList} = State) ->
  case length(TransitTimeDurationList) of
    0 ->
      AvgTransitTime = 0,
      MedianTransitTime = 0,
      MinTransitTime = 0,
      MaxTransitTime = 0;
    _ ->
      AvgTransitTime = calc_time_avg(TransitTimeDurationList),
      MedianTransitTime = calc_time_median(TransitTimeDurationList),
      MinTransitTime = lists:min(TransitTimeDurationList),
      MaxTransitTime = lists:max(TransitTimeDurationList)
  end,
  lager:info("Message transit time stats (in millis): Min = ~p, Max = ~p, Median = ~p, Avg = ~p",
    [MinTransitTime, MaxTransitTime, MedianTransitTime, AvgTransitTime]),
  erlang:send_after(?PUBLISH_STATS_DELAY, self(), publish_stats),
  {noreply, State#state{transit_duration_list = []} };

handle_info({record_stats, TransitDurationMillis}, #state{transit_duration_list = TransitTimeDurationList} = State) ->
  TransitTimeDurationList = State#state.transit_duration_list,
  NewTransitDurationList = [TransitDurationMillis | TransitTimeDurationList],
  {noreply, State#state{transit_duration_list = NewTransitDurationList} };

handle_info({'EXIT', SubscriberPid, killed},
    #state{subscriber_pids = SubscriberPids, subscriber_registry = SubscriberRegistry} = State) ->
  lager:warning("Subscriber worker (PID: ~p) killed and no longer active", [SubscriberPid]),
  {NewSubscriberPids, NewSubscriberRegistry} = remove_subscriber_data(SubscriberPid, SubscriberPids, SubscriberRegistry),
  {noreply, State#state{subscriber_pids = NewSubscriberPids, subscriber_registry = NewSubscriberRegistry}};

handle_info({'EXIT', SubscriberPid, normal},
    #state{subscriber_pids = SubscriberPids, subscriber_registry = SubscriberRegistry} = State) ->
  lager:warning("Subscriber worker (PID: ~p) exited normally and no longer active", [SubscriberPid]),
  {NewSubscriberPids, NewSubscriberRegistry} = remove_subscriber_data(SubscriberPid, SubscriberPids, SubscriberRegistry),
  {noreply, State#state{subscriber_pids = NewSubscriberPids, subscriber_registry = NewSubscriberRegistry}};

handle_info({'EXIT', SubscriberPid, Reason}, #state{subscriber_pids = SubscriberPids, subscriber_registry = SubscriberRegistry} = State) ->
  lager:warning("Subscriber worker (PID: ~p) exited unexpectedly for Reason ~p. It will be restarted", [SubscriberPid, Reason]),
  NewState = case dict:find(SubscriberPid, SubscriberRegistry) of
               error -> 
                 lager:error("No record for Subscriber worker (PID: ~p) found in subscriber registry, subscriber not restarted", 
                   [SubscriberPid]),
                 State;
               SubscriptionHeader ->
                 {NewSubscriberPids, NewSubscriberRegistry} =
                   remove_subscriber_data(SubscriberPid, SubscriberPids, SubscriberRegistry),
                 {NewestSubscriberPids, NewestSubscriberRegistry} = 
                   restart_subscription(NewSubscriberPids, NewSubscriberRegistry, SubscriptionHeader),
                 State#state{subscriber_pids = NewestSubscriberPids, subscriber_registry = NewestSubscriberRegistry}
             end,
  {noreply, NewState};

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

start_subscribers(Headers, SubscriberRegistry) ->
  start_subscribers(Headers, SubscriberRegistry, []).

start_subscribers([], SubscriberRegistry, SubscriberPids) -> {SubscriberPids, SubscriberRegistry};
start_subscribers([Header | RemainingHeaders], SubscriberRegistry, SubscriberPids) ->
  Empty = 0,
  process_flag(trap_exit, true),
  Pid = spawn_link(publish_proto_subscriber_worker, loop, [self(), Header, Empty, Empty, Empty]),
  NewSubscriberRegistry = dict:store(Pid,Header, SubscriberRegistry),
  Pid ! start,
  start_subscribers(RemainingHeaders, NewSubscriberRegistry, [Pid | SubscriberPids]).

stop_subscribers([]) -> ok;
stop_subscribers([Pid | RemainingPids]) ->
  Pid ! stop,
  stop_subscribers(RemainingPids).

calc_time_avg(PubDurationsList) ->
  Sum = lists:sum(PubDurationsList),
  case length(PubDurationsList) of
    0 -> 0;
    N -> Sum / N
  end.

calc_time_median(PubDurationsList) ->
  SortedList = lists:sort(PubDurationsList),
  Len = length(SortedList),
  case Len of
    0 -> 0;
    N -> case (N rem 2) of
           0 ->
             MedianPosition = round(N / 2),
             {List1, List2} = lists:split(MedianPosition, SortedList),
             Num1 = lists:last(List1),
             [Num2 | _] = List2,
             (Num1 + Num2) / 2;
           _ ->
             MedianPosition = round(N / 2),
             lists:nth(MedianPosition, SortedList)
         end
  end.

%% TODO: fix type error for dict(pid(), nonempty_string())
%% -spec remove_subscriber_data(SubscriberPid :: pid(), SubscriberPids :: [pid()], 
%%     SubscriberRegistry :: dict(pid(), nonempty_string())) -> tuple().
remove_subscriber_data(SubscriberPid, SubscriberPids, SubscriberRegistry) ->
  NewSubscriberPids = lists:delete(SubscriberPid, SubscriberPids),
  case dict:find(SubscriberPid, SubscriberRegistry) of
    error ->
      lager:warning("SubscriberPid (~p) not found in SubscriberRegistry", [SubscriberPid]);
    _ ->
      lager:info("SubscriberPid (~p) will be removed from SubscriberRegistry", [SubscriberPid])
  end,
  NewSubscriberRegistry = dict:erase(SubscriberPid, SubscriberRegistry),
  {NewSubscriberPids, NewSubscriberRegistry}.

restart_subscription(SubscriberPids, SubscriberRegistry, SubscriptionHeader) ->
  {NewSubscriberPids, NewSubscriberRegistry} = 
    start_subscribers([SubscriptionHeader], SubscriberRegistry, SubscriberPids),
  {NewSubscriberPids, NewSubscriberRegistry}.

