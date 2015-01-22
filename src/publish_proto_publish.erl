%% @author uyounri
%% @doc @todo Add description to publish_proto_publish.


-module(publish_proto_publish).

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

-record(state, {}).

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
  {ok, #state{}}.

handle_call(publish_message, _From, State) ->
  publish_proto_publisher_worker:publish_message(),
  {reply, ok, State};
handle_call(Request, _From, State) ->
  lager:warning("Unknown call: ~p", [Request]),
  {reply, ok, State}.

handle_cast(Request, State) ->
  lager:warning("Unknown cast: ~p", [Request]),
  {noreply, State}.

handle_info(Info, State) ->
  lager:warning("Unknown info message: ~p", [Info]),
  {noreply, State}.

terminate(_Reason, _State) ->
  init:stop().

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

