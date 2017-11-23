package ;

import corsair.Middleware;
import tink.http.Response;
import travix.Logger.*;
using tink.CoreApi;
using tink.io.Source;


class RunTests {

  static function main() {
    new tink.http.containers.NodeContainer(12345).run(
      corsair.Middleware.create({ paramName: 'forward-to' })(
        corsair.Middleware.create()(function (req) {
          return Future.sync(OutgoingResponse.blob('hello, world', 'text/plain'));
        })
      )
    );

    function get(url:String)
      return 
        tink.http.Fetch.fetch('http://localhost:12345/$url')
          .next(function (res)
            return res.body.all()
              .next(function (c) return {
                header: res.header,
                body: c.toString()
              })
          );
    
    function loc(param:String) {
      var expected = 'http://localhost:12345/?$param=https://github.com/';
      return get('?$param=http://github.com/')
        .next(function (res) return res.header.byName(LOCATION))
        .next(function (l) return 
          if (l == expected)
            true
          else
            new Error('Expected $expected but got $l')
        );
    }

    loc('forward-to')
      .next(function (_) return loc('proxy-to'))
      .next(function (_) return get('foobar'))
      .next(
        function (hello)
          return switch hello.body {
            case 'hello, world':
              get('?proxy-to=http://example.com/');
            case unexpected:
              new Error('expected "hello, world" but got $unexpected');
          }
      )
    .handle(function (o) switch o {
      case Success({ body: unexpected }) if (unexpected.indexOf('<title>Example Domain</title>') == -1):
        println('received unexpected response:');
        println('');
        println(unexpected);
        exit(500);      
      case Success(_):
        println('It appears to have worked.');
        exit(0);
      case Failure(e):
        println('Error: ${e.message}');
        exit(e.code);
    });
  }
  
}