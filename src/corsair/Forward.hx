package corsair;

import tink.http.Request;
import tink.http.Response;
import tink.http.Header;

using tink.CoreApi;
using tink.io.Source;

class Forward {
  static var http = new tink.http.clients.NodeClient();
  static var https = new tink.http.clients.SecureNodeClient();
  static public function request(req:IncomingRequest, to:String, redirect) {
    return Promise.lift(req.header.byName(HOST))
      .next(function (host) {
        var host:String = host;
        var url:tink.Url = to;
        if (url.host == null)
          return new Error(BadRequest, 'Missing host in URL "$to"');

        var fields = [for (h in req.header) switch h.name {
          case (_:String) => 'referer' | 'origin': continue;
          case HOST: new HeaderField(HOST, url.host.toString());
          default: h;
        }];

        return (if (url.scheme == 'http')
          http
        else
          https
        ).request(
          new OutgoingRequest(
            new OutgoingRequestHeader(
              req.header.method, 
              to,
              fields
            ),
            switch req.body {
              case Plain(v): 
                v.idealize(function (_) return Source.EMPTY);
              case Parsed(_): 
                trace('received parsed body oO');
                '';
            }
          )
        ).next(function (res) 
          return new OutgoingResponse(
            new ResponseHeader(
              switch res.header.statusCode {
                case 301: 307;
                case v: v;
              }, res.header.reason, 
              [for (f in res.header) switch (f.name:String) {
                case SET_COOKIE: 
                  var builder = tink.url.Query.build();
                  for (p in tink.url.Query.parseString(f.value, ';'))
                    switch p.name {
                      case 'secure' | 'domain':
                      case n: builder.add(p.name, p.value);
                    }
                  new HeaderField(SET_COOKIE, builder.toString(';'));
                case LOCATION: new HeaderField(LOCATION, redirect({ self: host, original: req.header.url, target: f.value }));
                default: f;
              }]
            ),
            res.body.idealize(function (_) return Source.EMPTY)
          )
        );        
      }).recover(OutgoingResponse.reportError);//TODO: should probably generate 502s here as appropriate
  }
}