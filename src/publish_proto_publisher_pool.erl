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
-module(publish_proto_publisher_pool).

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
-define(PUBLISH_STATS_DELAY, 30000). %% 30 seconds

-record(state, {publisher_pids = [], next_publish_worker = 1, pub_duration_list = [], last_sample_time}).

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
  configure_stats(),
  
  erlang:send_after(?PUBLISH_STATS_DELAY, self(), log_stats),
  PublisherPids = start_publishers(publish_proto_config:get(publishing_pool_size)),
  LastSampleTime = get_now_in_gregorian_seconds(),
  {ok, #state{publisher_pids = PublisherPids, last_sample_time = LastSampleTime}}.

%%
%% Publishes to a pool of publisher workers chosen in a round-robin fashion
%%
handle_call(publish_message, _From, #state{publisher_pids = PublisherPids, next_publish_worker = NextPublishWorker,
  pub_duration_list = PublishDurationList, last_sample_time = LastSampleTime} = _State) ->
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
  {reply, ok, #state{publisher_pids = PublisherPids, next_publish_worker = NewNextPublishWorker,
    pub_duration_list = PublishDurationList, last_sample_time = LastSampleTime}};
handle_call(Request, _From, State) ->
  lager:warning("Unknown call: ~p", [Request]),
  {reply, ok, State}.

handle_cast(Request, State) ->
  lager:warning("Unknown cast: ~p", [Request]),
  {noreply, State}.

%%
%% handle_info
%%
%%
%% TODO this function can probably go away when the transition to exometer is complete
%%
handle_info(log_stats, State) ->
  %% TODO had to remove the #state{...} = State pattern matching in the argument list because it
  %% TODO wasn't working. Come back and figure out why.
  PublisherPids = State#state.publisher_pids,
  NextPublishWorker = State#state.next_publish_worker,
  PublishDurationList = State#state.pub_duration_list,
  LastSampleTime = State#state.last_sample_time,

  case length(PublishDurationList) of
    0 ->
      AvgPubTime = 0,
      MedianPubTime = 0,
      MinPubTime = 0,
      MaxPubTime = 0;
    _ ->
      AvgPubTime = calc_publish_time_avg(PublishDurationList),
      MedianPubTime = calc_publish_time_median(PublishDurationList),
      MinPubTime = lists:min(PublishDurationList),
      MaxPubTime = lists:max(PublishDurationList)
  end,
  lager:info("Publish interval stats (in microseconds): Min = ~p, Max = ~p, Median = ~p, Avg = ~p",
    [MinPubTime, MaxPubTime, MedianPubTime, AvgPubTime]),
  NewState = #state{publisher_pids = PublisherPids, next_publish_worker = NextPublishWorker,
    pub_duration_list = [], last_sample_time = LastSampleTime},
  erlang:send_after(?PUBLISH_STATS_DELAY, self(), log_stats),
  {noreply, NewState };

handle_info({record_stats, PubDurationMicros}, State) ->
  %% TODO had to remove the #state{...} = State pattern matching in the argument list because it
  %% TODO wasn't working. Come back and figure out why.
  PublisherPids = State#state.publisher_pids,
  NextPublishWorker = State#state.next_publish_worker,
  PublishDurationList = State#state.pub_duration_list,
  LastSampleTime = State#state.last_sample_time,
  NewPubDurationList = [PubDurationMicros | PublishDurationList],
  
  %%%
  %%% Publishes stats to exometer. Long term this will replace the rest of this
  %%% function and handle_info/log_stats, and most of the state currently managed
  %%% in support of capturing stats (e.g., pub_duration_list)
  %%%
  NewLastSampleTime = publish_stats(PubDurationMicros, LastSampleTime),
  {noreply, #state{publisher_pids = PublisherPids, next_publish_worker = NextPublishWorker,
    pub_duration_list = NewPubDurationList, last_sample_time = NewLastSampleTime} };

handle_info({'EXIT', _Pid, killed}, State) ->
  lager:warning("Publisher worker killed"),
  {noreply, State};
handle_info({'EXIT', _Pid, Reason}, State) ->
  lager:warning("Publisher worker exited for Reason ~p", [Reason]),
  {noreply, State};
handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

%%
%% terminate & code_change
%%
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
    [{self(), Placeholder, Placeholder, Placeholder}]),
  process_flag(trap_exit, true),
  Pid ! start,
  start_publishers(NumPublishers - 1, [Pid | PublisherPids]).

stop_publishers([]) -> ok;
stop_publishers([Pid | RemainingPids]) ->
  Pid ! stop,
  stop_publishers(RemainingPids).

calc_publish_time_avg(PubDurationsList) ->
  Sum = lists:sum(PubDurationsList),
  case length(PubDurationsList) of
    0 -> 0;
    N -> Sum / N
  end.

calc_publish_time_median(PubDurationsList) ->
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

get_now_in_gregorian_seconds() ->
  calendar:datetime_to_gregorian_seconds(calendar:now_to_datetime(now())).

publish_stats(PubDurationMicros, LastSampleTime) ->
  SecsSinceLastPublished = get_now_in_gregorian_seconds() - LastSampleTime,
  case SecsSinceLastPublished of
    N when N >= 1 -> %% publish stats 1/sec
      exometer:update([publish_proto,publish,latency], PubDurationMicros),
      %% TODO DEBUG only, remove
      exometer:update([erlang,random,integer], random:uniform(100)),

      get_now_in_gregorian_seconds();
    _ -> 
      LastSampleTime
  end.

configure_stats() ->
  ok = exometer:new([publish_proto, erlang, memory],
    {function, erlang, memory, ['$dp'], value,
      [total, processes, system, atom, binary, ets]}),

  % Memory actively used by the VM, allocated (should ~match OS allocation),
  % unused (i.e. allocated - used), and usage (used / allocated).
  ok = exometer:new([publish_proto, recon, alloc],
    {function, recon_alloc, memory, ['$dp'], value,
      [used, allocated, unused, usage]}),

  % TODO Debug metric, does it work?
  exometer:new([erlang,random,integer], histogram, [{time_span, 30000}]),

  % time_span is one of the histogram options. It's only shown to highlight that there are
  % options. See the exometer_core project in github, exometer_histogram.erl, for details.
  ok = exometer:new([publish_proto,publish,latency], histogram, [{time_span, 30000}, {slot_period, 1000}]).

