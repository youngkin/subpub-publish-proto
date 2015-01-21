% SubPub -  Copyright (c) 2013 Pearson.  All rights reserved.  
%
%   Licensed under the Apache License, Version 2.0 (the "License");
%
%   you may not use this file except in compliance with the License.



-module(publish_proto_app).

-behaviour(application).

-export([start/2,stop/1, start_phase/3]).

-define(APP, publish_proto).

start(_Type, _StartArgs) ->
    lager:info("Starting publish_proto_app"),
    publish_proto_sup:start_link().
  

stop(_State) ->
    lager:info("Stopping publish_proto_app"),
    ok.

start_phase(init, _StartType, _StartArgs) ->
    ok.

