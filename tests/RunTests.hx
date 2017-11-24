package ;

import corsair.Middleware;
import tink.http.Response;
import travix.Logger.*;
using tink.CoreApi;
using tink.io.Source;


class RunTests {

  static function main() {
    var handler:tink.http.Handler = function (req) {
      return Future.sync(OutgoingResponse.blob('hello, world', 'text/plain'));
    };
    new tink.http.containers.NodeContainer(12345).run(
      corsair.Middleware.create({ paramName: 'forward-to' })(
        corsair.Middleware.create()(function (req) return handler.process(req))
      )
    );

    function get(url:String)
      return 
        tink.http.Fetch.fetch('http://localhost:12345/$url', { followRedirect: false })
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

    function match(url:String, regex:EReg)
      return
        get(url)
          .next(function (res)
            return 
              switch res.body {
                case regex.match(_) => true: Noise;
                case unexpected:
                  new Error('expected "$regex" but got $unexpected');
              }
          );

    loc('forward-to')
      .next(function (_) return loc('proxy-to'))
      .next(function (_) return match('?foobar=http://example.com', ~/^hello, world$/))
      .next(function (_) return match('?proxy-to=http://example.com', ~/<title>Example Domain<\/title>/))
      .next(function (_) return match('?forward-to=http://example.com', ~/<title>Example Domain<\/title>/))
      .next(function (_) {
        handler = corsair.Forward.all('http://httpbin.org/anything/');
        return match('hohoho', ~/hohoho/);
      })
    .handle(function (o) switch o {      
      case Success(_):
        println('It appears to have worked.');
        exit(0);
      case Failure(e):
        println('Error: ${e.message}');
        exit(e.code);
    });
  }
  
}