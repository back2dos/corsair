package ;

import corsair.Middleware;
import tink.http.Response;
using tink.CoreApi;
using tink.io.Source;

import travix.Logger.*;

class RunTests {

  static function main() {
    new tink.http.containers.NodeContainer(12345).run(
      corsair.Middleware.create()(function (req) {
        return Future.sync(OutgoingResponse.blob('hello, world', 'text/plain'));
      })
    );

    function get(url:String)
      return 
        tink.http.Fetch.fetch('http://localhost:12345/$url')
          .next(function (res)
            return res.body.all()
          )
          .next(function (c) return c.toString());

    get('')
      .next(
        function (hello)
          return 
            if (hello != 'hello, world') 
              new Error('expected "hello, world" but got $hello')
            else
              get('?proxy-to=http://example.com/')
      )
    .handle(function (o) switch o {
      case Success(unexpected) if (unexpected.indexOf('<title>Example Domain</title>') == -1):
        println('received unexpected response:');
        println('');
        println(unexpected);
        exit(500);      
      case Success(v):
        println('It appears to have worked.');
        exit(0);
      case Failure(e):
        println('Error: ${e.message}');
        exit(e.code);
    });
  }
  
}