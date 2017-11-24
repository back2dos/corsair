package corsair;

class Forward {

  static public function all(base:tink.Url):Handler 
    return function (req:IncomingRequest)
      return Forward.request(req, base.resolve(req.header.url.pathWithQuery.substr(1)), function (ctx) return base.resolve(ctx.target));
  
  static public function request(req:IncomingRequest, to:String, redirect:Redirect) {
    return Promise.lift(req.header.byName(HOST))
      .next(function (host) {
        var host:String = host;
        var url:tink.Url = to;
        if (url.host == null)
          return new Error(BadRequest, 'Missing host in URL "$to"');

        return tink.http.Fetch.fetch(to, {
          method: req.header.method,
          headers: [for (h in req.header) switch h.name {
            case (_:String) => 'referer' | 'origin': continue;
            case HOST: new HeaderField(HOST, url.host.toString());
            default: h;
          }],
          body: switch req.body {
            case Plain(v): 
              v.idealize(function (_) return Source.EMPTY);
            case Parsed(_): 
              trace('received parsed body oO');
              '';
          },
          followRedirect: false,
        }).next(function (res) 
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