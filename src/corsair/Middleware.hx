package corsair;

class Middleware {
  static public function custom(options:{ extract: tink.Url->Option<String>, redirect:Redirect, ?modifyHeaders:IncomingRequestHeader->Array<HeaderField> }):Handler->Handler 
    return function (handler) 
      return function (req:IncomingRequest) 
        return switch options.extract(req.header.url) {
          case Some(to): 
            Forward.request(switch options.modifyHeaders {
              case null: req;
              case f: 
                new IncomingRequest(
                  req.clientIp,
                  new IncomingRequestHeader(
                    req.header.method,
                    req.header.url,
                    f(req.header)
                  ),
                  req.body
                );
            }, to, options.redirect);
          case None: handler.process(req);
        } 

  static public function create(?options:{ ?paramName:String, ?modifyHeaders:IncomingRequestHeader->Array<HeaderField> }):Handler->Handler {
    if (options == null)
      options = {};
    var paramName = switch options.paramName {
      case null: 'proxy-to';
      case v: v;
    }    
    return 
      custom({
        extract: function (url) {
          var to = url.query.toMap()[paramName].toString();
          return 
            if (url.path == '/' && to != null) Some(to);
            else None;
        },
        redirect: function (ctx) {
          return 'http://${ctx.self}/?' + tink.url.Query.build().add(paramName, (ctx.from:tink.Url).resolve(ctx.to).toString()).toString(); //TODO: treat relative URLs
        },
        modifyHeaders: options.modifyHeaders,
      });
  }
}