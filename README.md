Overview
========

subpub-publish-proto.erlang is a prototyping framework for publishing subpub-like messages to a backend storage service.
In the first iteration the backend storage service is RabbitMQ.

Getting Started
===============
TBD

1. Need a RabbitMQ installation to publish to
2. Optional statsd, graphite installation for metrics

Developing
==========
Source code
-----------
TBD, highlight significant files such as publisher worker, publisher pool, subscriber worker, subscriber pool

Building
--------
<code>EXOMETER_PACKAGES="(minimal)" make all</code>

(Retrieves only the minimal set of exometer dependencies in order to avoid library versioning issues. In particular with the amqp client library)

Running locally
---------------

Configuration - _rel/publish_proto/releases/0.0.1/sys.config

Running

* start app - <code>./_rel/publish_proto/bin/publish_proto start</code>
* remote console (to run test) <code>./_rel/publish_proto/bin/publish_proto remote_console</code>
* start test (in remote console) - <code>publish_proto_test_driver:start_test().</code>
* stop test (in remote console)- <code>publish_proto_test_driver:stop_test().</code>

Monitoring
----------
1. <code>_rel/publish_proto/log</code> contains all the log files. <code>console.log</code> contains runtime metrics
2. It does publish to a statsd backend (via exometer). Requires statsd and a statsd compliant visualization GUI (e.g., Graphite).

License
=======
NA?
