package corsair;

import tink.http.Client;
import tink.Chunk;

class Forward {

  static public function all(base:tink.Url, ?augment):Handler 
    return function (req:IncomingRequest)
      return Forward.request(
        req, 
        base.resolve(req.header.url.pathWithQuery.substr(1)), 
        { 
          redirect: function (ctx) return base.resolve(ctx.to),
          augment: augment,
        }
      );
  
  static public function request(req:IncomingRequest, to:String, options:{ ?augment:Processors, redirect:Redirect }) {
    return Promise.lift(req.header.byName(HOST))
      .next(function (host) {
        var host:String = host;
        var url:tink.Url = to;

        if (url.host == null)
          return new Error(BadRequest, 'Missing host in URL "$to"');

        var overrides = new Map<HeaderName, String>();
        
        for (param in req.header.url.query) 
          switch (param.name:String).split('header.') {
            case ['', name]: overrides[name] = param.value;
            default: continue;
          }

        return tink.http.Fetch.fetch(to, {
          method: req.header.method,
          headers: [for (h in req.header) switch h.name {
            case HOST: new HeaderField(HOST, url.host.toString());
            case name: 
              switch overrides[name] {
                case null: h;
                case '': continue;
                case value: new HeaderField(name, value);
              }
          }],
          body: switch req.body {
            case Plain(v): 
              v.idealize(function (_) return Source.EMPTY);
            case Parsed(_): 
              trace('received parsed body oO');
              '';
          },
          augment: options.augment,
          followRedirect: false,
        }).next(function (res) {

          function respond(?body:Chunk) 
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
                  case LOCATION: new HeaderField(LOCATION, options.redirect({ self: host, original: req.header.url, from: to, to: f.value }));
                  case CONTENT_LENGTH if (body != null): new HeaderField(CONTENT_LENGTH, body.length);
                  case REFERER: continue;
                  default: f;
                }]
              ),
              if (body == null) res.body.idealize(function (_) return Source.EMPTY)
              else body
            );
                    
          return 
            switch res.header.contentType() {
              case Success({ type: 'application', subtype: _.toLowerCase() => 'x-mpegurl' | 'vnd.apple.mpegurl' }): 
                res.body.all()
                  .next(function (chunk) 
                    return respond([for (line in chunk.toString().split('\n'))
                      if (line.startsWith('#')) line
                      else options.redirect({ self: host, original: req.header.url, from: to, to: line })
                    ].join('\n'))
                  );
              default: respond();
            }
        });        
      }).recover(OutgoingResponse.reportError);//TODO: should probably generate 502s here as appropriate
  }
}